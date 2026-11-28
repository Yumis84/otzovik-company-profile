BEGIN;

CREATE TABLE private.company_publish_attempt_candidate (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 company_id uuid NOT NULL REFERENCES public.companies(id),
 request_key uuid NOT NULL,
 requested_by uuid NOT NULL,
 slug text NOT NULL,
 snapshot jsonb NOT NULL,
 state text NOT NULL DEFAULT 'queued' CHECK(state IN ('queued','building','published','failed')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(company_id,request_key)
);
CREATE UNIQUE INDEX company_publish_one_active_candidate ON private.company_publish_attempt_candidate(company_id) WHERE state IN ('queued','building');
ALTER TABLE private.company_publish_attempt_candidate ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.company_publish_attempt_candidate FROM PUBLIC,anon,authenticated;
CREATE FUNCTION private.enqueue_company_publish_candidate(p_company uuid,p_key uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_slug text; v_snapshot jsonb; v_id uuid;
BEGIN
 IF p_key IS NULL OR auth.uid() IS NULL THEN RAISE EXCEPTION 'not authorized' USING ERRCODE='42501'; END IF;
 SELECT c.slug INTO v_slug FROM public.companies c WHERE c.id=p_company FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.company_memberships m WHERE m.company_id=p_company AND m.user_id=auth.uid() AND m.verification_status='verified' AND m.role='owner') THEN RAISE EXCEPTION 'not authorized' USING ERRCODE='42501'; END IF;
 v_snapshot:=private.get_company_complete_candidate_v1(v_slug);
 IF v_snapshot IS NULL OR v_snapshot->>'id' IS DISTINCT FROM p_company::text THEN RAISE EXCEPTION 'not publishable'; END IF;
 SELECT id INTO v_id FROM private.company_publish_attempt_candidate WHERE company_id=p_company AND (request_key=p_key OR state IN ('queued','building')) ORDER BY (request_key=p_key) DESC LIMIT 1;
 IF FOUND THEN RETURN v_id; END IF;
 INSERT INTO private.company_publish_attempt_candidate(company_id,request_key,slug,snapshot,requested_by) VALUES(p_company,p_key,v_slug,v_snapshot,auth.uid()) RETURNING id INTO v_id;
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION private.enqueue_company_publish_candidate(uuid,uuid) FROM PUBLIC,anon,authenticated;


ALTER TABLE private.company_publish_attempt_candidate ADD COLUMN run_id uuid, ADD COLUMN artifact_revision text;
CREATE FUNCTION private.transition_publish_candidate(p_id uuid,p_run uuid,p_state text,p_revision text DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF p_run IS NULL THEN RETURN false; END IF;
 UPDATE private.company_publish_attempt_candidate SET state=p_state,run_id=p_run,artifact_revision=p_revision
 WHERE id=p_id AND ((state='queued' AND p_state='building' AND p_revision IS NULL) OR (state='building' AND run_id=p_run AND ((p_state='published' AND nullif(btrim(p_revision),'') IS NOT NULL) OR (p_state='failed' AND p_revision IS NULL))));
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION private.transition_publish_candidate(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;


CREATE TABLE private.company_publish_request_keys_candidate (
 company_id uuid NOT NULL,
 request_key uuid NOT NULL,
 attempt_id uuid NOT NULL REFERENCES private.company_publish_attempt_candidate(id),
 PRIMARY KEY(company_id,request_key)
);
ALTER TABLE private.company_publish_request_keys_candidate ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.company_publish_request_keys_candidate FROM PUBLIC,anon,authenticated;
INSERT INTO private.company_publish_request_keys_candidate SELECT company_id,request_key,id FROM private.company_publish_attempt_candidate;
CREATE OR REPLACE FUNCTION private.enqueue_company_publish_candidate(p_company uuid,p_key uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_slug text; v_snapshot jsonb; v_id uuid;
BEGIN
 IF p_key IS NULL OR auth.uid() IS NULL THEN RAISE EXCEPTION 'not authorized' USING ERRCODE='42501'; END IF;
 SELECT c.slug INTO v_slug FROM public.companies c WHERE c.id=p_company FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.company_memberships m WHERE m.company_id=p_company AND m.user_id=auth.uid() AND m.verification_status='verified' AND m.role='owner') THEN RAISE EXCEPTION 'not authorized' USING ERRCODE='42501'; END IF;
 SELECT attempt_id INTO v_id FROM private.company_publish_request_keys_candidate WHERE company_id=p_company AND request_key=p_key;
 IF FOUND THEN RETURN v_id; END IF;
 v_snapshot:=private.get_company_complete_candidate_v1(v_slug);
 IF v_snapshot IS NULL OR v_snapshot->>'id' IS DISTINCT FROM p_company::text THEN RAISE EXCEPTION 'not publishable'; END IF;
 SELECT id INTO v_id FROM private.company_publish_attempt_candidate WHERE company_id=p_company AND state IN ('queued','building');
 IF NOT FOUND THEN
 INSERT INTO private.company_publish_attempt_candidate(company_id,request_key,slug,snapshot,requested_by) VALUES(p_company,p_key,v_slug,v_snapshot,auth.uid()) RETURNING id INTO v_id;
 END IF;
 INSERT INTO private.company_publish_request_keys_candidate VALUES(p_company,p_key,v_id);
 RETURN v_id;
END $$;


ALTER TABLE private.company_publish_attempt_candidate ADD UNIQUE(company_id,id);
ALTER TABLE private.company_publish_request_keys_candidate ADD FOREIGN KEY(company_id,attempt_id) REFERENCES private.company_publish_attempt_candidate(company_id,id);


CREATE FUNCTION private.claim_publish_candidate(p_run uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_result jsonb;
BEGIN
 IF p_run IS NULL THEN RETURN NULL; END IF;
 SELECT id INTO v_id FROM private.company_publish_attempt_candidate WHERE state='queued' ORDER BY created_at,id LIMIT 1 FOR UPDATE SKIP LOCKED;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE private.company_publish_attempt_candidate SET state='building',run_id=p_run WHERE id=v_id RETURNING jsonb_build_object('id',id,'company_id',company_id,'slug',slug,'snapshot',snapshot,'run_id',run_id) INTO v_result;
 RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION private.claim_publish_candidate(uuid) FROM PUBLIC,anon,authenticated;


ALTER TABLE private.company_publish_attempt_candidate ADD COLUMN lease_until timestamptz;
CREATE FUNCTION private.expire_publish_candidates() RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE n bigint;
BEGIN
 UPDATE private.company_publish_attempt_candidate SET state='failed' WHERE state='building' AND lease_until IS NOT NULL AND lease_until<=clock_timestamp();
 GET DIAGNOSTICS n=ROW_COUNT;
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION private.expire_publish_candidates() FROM PUBLIC,anon,authenticated;


CREATE OR REPLACE FUNCTION private.claim_publish_candidate(p_run uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_result jsonb;
BEGIN
 IF p_run IS NULL THEN RETURN NULL; END IF;
 SELECT id INTO v_id FROM private.company_publish_attempt_candidate WHERE state='queued' ORDER BY created_at,id LIMIT 1 FOR UPDATE SKIP LOCKED;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE private.company_publish_attempt_candidate SET state='building',run_id=p_run,lease_until=clock_timestamp()+interval '5 minutes' WHERE id=v_id RETURNING jsonb_build_object('id',id,'company_id',company_id,'slug',slug,'snapshot',snapshot,'run_id',run_id) INTO v_result;
 RETURN v_result;
END $$;
CREATE FUNCTION private.heartbeat_publish_candidate(p_id uuid,p_run uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 UPDATE private.company_publish_attempt_candidate SET lease_until=clock_timestamp()+interval '5 minutes' WHERE id=p_id AND state='building' AND run_id=p_run AND lease_until>clock_timestamp();
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION private.heartbeat_publish_candidate(uuid,uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION private.transition_publish_candidate(p_id uuid,p_run uuid,p_state text,p_revision text DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF p_run IS NULL THEN RETURN false; END IF;
 UPDATE private.company_publish_attempt_candidate SET state=p_state,artifact_revision=p_revision,lease_until=NULL
 WHERE id=p_id AND state='building' AND run_id=p_run AND lease_until>clock_timestamp() AND ((p_state='published' AND nullif(btrim(p_revision),'') IS NOT NULL) OR (p_state='failed' AND p_revision IS NULL));
 RETURN FOUND;
END $$;


CREATE OR REPLACE FUNCTION private.transition_publish_candidate(p_id uuid,p_run uuid,p_state text,p_revision text DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF p_run IS NULL THEN RETURN false; END IF;
 UPDATE private.company_publish_attempt_candidate a SET state=p_state,artifact_revision=p_revision,lease_until=NULL
 WHERE a.id=p_id AND a.state='building' AND a.run_id=p_run AND a.lease_until>clock_timestamp() AND ((p_state='published' AND nullif(btrim(p_revision),'') IS NOT NULL AND private.resolve_public_company_id_v1(a.slug)=a.company_id AND EXISTS(SELECT 1 FROM public.companies c WHERE c.id=a.company_id AND c.slug=a.slug)) OR (p_state='failed' AND p_revision IS NULL));
 RETURN FOUND;
END $$;


CREATE TABLE private.company_publish_artifact_candidate (
 attempt_id uuid PRIMARY KEY REFERENCES private.company_publish_attempt_candidate(id),
 run_id uuid NOT NULL,
 digest text NOT NULL CHECK(digest ~ '^[0-9a-f]{64}$'),
 manifest jsonb NOT NULL CHECK(jsonb_typeof(manifest)='object' AND manifest ?& ARRAY['index.html','profile.css','profile.json','profile.md','llms.txt'])
);
ALTER TABLE private.company_publish_artifact_candidate ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.company_publish_artifact_candidate FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION private.transition_publish_candidate(p_id uuid,p_run uuid,p_state text,p_revision text DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 UPDATE private.company_publish_attempt_candidate a SET state=p_state,artifact_revision=p_revision,lease_until=NULL
 WHERE a.id=p_id AND a.state='building' AND a.run_id=p_run AND a.lease_until>clock_timestamp() AND ((p_state='published' AND private.resolve_public_company_id_v1(a.slug)=a.company_id AND EXISTS(SELECT 1 FROM public.companies c WHERE c.id=a.company_id AND c.slug=a.slug) AND EXISTS(SELECT 1 FROM private.company_publish_artifact_candidate f WHERE f.attempt_id=a.id AND f.run_id=p_run AND f.digest=p_revision)) OR (p_state='failed' AND p_revision IS NULL));
 RETURN FOUND;
END $$;

COMMIT;
