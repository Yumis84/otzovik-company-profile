-- REVIEW ONLY; apply after 10 on an isolated existing-staging clone.

BEGIN;

SET LOCAL lock_timeout='3s'; SET LOCAL statement_timeout='60s';

CREATE FUNCTION private.is_company_publicly_readable_v1(p_company_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
SELECT EXISTS(SELECT 1 FROM public.companies c JOIN public.company_profile_public_access a ON a.company_id=c.id WHERE c.id=p_company_id AND c.status='active' AND c.profile_status='ready' AND a.state='active');
$$;
CREATE FUNCTION private.resolve_public_company_id_v1(p_slug text) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
WITH matches AS (SELECT c.id FROM public.companies c WHERE length(trim(p_slug)) BETWEEN 1 AND 80 AND trim(p_slug) ~ '^[A-Za-z0-9-]+$' AND lower(trim(c.slug))=lower(trim(p_slug)))
SELECT id FROM matches WHERE (SELECT count(*) FROM matches)=1 AND private.is_company_publicly_readable_v1(id);
$$;
REVOKE ALL ON FUNCTION private.is_company_publicly_readable_v1(uuid),private.resolve_public_company_id_v1(text) FROM PUBLIC,anon,authenticated;


CREATE FUNCTION private.get_company_base_candidate_v1(p_slug text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
SELECT jsonb_build_object('id',c.id,'slug',c.slug,'name',c.name,'description',c.description,'legal_name',c.legal_name,'website',c.website,'phone',c.phone,'city',c.city,'profile_status',c.profile_status,'updated_at',c.updated_at,
'locations',coalesce((SELECT jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'relationship_type',l.relationship_type,'address',l.canonical_address,'city',l.city,'phone',l.phone,'hours',l.hours,'official_url',l.official_url,'source_url',l.source_url,'verified_at',l.verified_at) ORDER BY l.id) FROM public.company_locations l WHERE l.company_id=c.id AND l.status='published'),'[]'::jsonb),
'services',coalesce((SELECT jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'category',s.category,'description',s.description,'official_url',s.official_url,'source_url',s.source_url,'verified_at',s.verified_at) ORDER BY s.id) FROM public.company_services s WHERE s.company_id=c.id AND s.status='published'),'[]'::jsonb),
'media',coalesce((SELECT jsonb_agg(jsonb_build_object('id',m.id,'type',m.media_type,'object_name',m.storage_object_name,'sort_order',m.sort_order,'alt',m.alt_text,'caption',m.caption,'updated_at',m.updated_at) ORDER BY m.sort_order,m.id) FROM public.company_media m WHERE m.company_id=c.id AND m.status='published'),'[]'::jsonb))
FROM public.companies c WHERE c.id=private.resolve_public_company_id_v1(p_slug);
$$;
REVOKE ALL ON FUNCTION private.get_company_base_candidate_v1(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.get_company_sources_candidate(c uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'url',s.profile_url,'rating',r.rating,'rating_scale',r.rating_scale,'rating_count',r.rating_count,'review_count',r.review_count,'checked_at',r.checked_at) ORDER BY s.id),'[]'::jsonb)
FROM public.review_sources s LEFT JOIN LATERAL (SELECT rating,rating_scale,rating_count,review_count,checked_at FROM public.source_ratings WHERE source_id=s.id AND status='published' ORDER BY checked_at DESC,id DESC LIMIT 1) r ON true
WHERE s.company_id=c AND s.status='published' AND (s.location_id IS NULL OR EXISTS(SELECT 1 FROM public.company_locations l WHERE l.id=s.location_id AND l.company_id=c AND l.status='published')) AND private.is_company_publicly_readable_v1(c)
$$;
REVOKE ALL ON FUNCTION private.get_company_sources_candidate(uuid) FROM PUBLIC,anon,authenticated;

-- Existing canonical native-content readers are required; absent readers fail installation.
DO $$ BEGIN
 IF to_regprocedure('private.get_public_reviews_v1(uuid)') IS NULL OR to_regprocedure('private.get_public_official_qna_v1(uuid)') IS NULL THEN
  RAISE EXCEPTION 'canonical native content readers required';
 END IF;
END $$;
CREATE FUNCTION private.get_company_complete_candidate_v1(p_slug text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
WITH base AS (SELECT private.get_company_base_candidate_v1(p_slug) d),
visible AS (SELECT d,(d->>'id')::uuid id FROM base WHERE d IS NOT NULL),
native AS (
 SELECT v.id,coalesce(jsonb_agg(x.item ORDER BY x.item->>'published_at' DESC,x.item->>'id') FILTER(WHERE x.item IS NOT NULL),'[]'::jsonb) items
 FROM visible v LEFT JOIN LATERAL (
  SELECT j.item FROM jsonb_array_elements(private.get_public_reviews_v1(v.id)) j(item)
  JOIN public.reviews r ON r.id=(j.item->>'id')::uuid AND r.company_id=v.id AND r.status='published'
  JOIN public.review_sources s ON s.id=r.source_id AND s.company_id=v.id AND s.status='published' AND s.source_type='first_party_reviews'
  WHERE (r.location_id IS NULL OR EXISTS(SELECT 1 FROM public.company_locations l WHERE l.id=r.location_id AND l.company_id=v.id AND l.status='published'))
   AND NOT EXISTS(SELECT 1 FROM private.review_revisions_v1 rr WHERE rr.company_id=v.id AND rr.review_id=r.id AND (rr.erased_at IS NOT NULL OR rr.redaction_status='erased'))
 ) x ON true GROUP BY v.id
)
SELECT v.d || jsonb_build_object('sources',private.get_company_sources_candidate(v.id),
 'reviews',n.items,'questions_answers',private.get_public_official_qna_v1(v.id),
 'native_rating',jsonb_build_object('rating',(SELECT round(avg((j->>'rating')::numeric),2) FROM jsonb_array_elements(n.items) j WHERE j->>'rating' IS NOT NULL AND (j->>'rating_scale')::numeric=5),'rating_scale',5,'review_count',jsonb_array_length(n.items)))
FROM visible v JOIN native n ON n.id=v.id;
$$;
REVOKE ALL ON FUNCTION private.get_company_complete_candidate_v1(text) FROM PUBLIC,anon,authenticated;

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

CREATE FUNCTION private.publish_snapshot_complete_candidate(d jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
SELECT coalesce(jsonb_typeof(d->'sources')='array' AND jsonb_typeof(d->'reviews')='array' AND jsonb_typeof(d->'questions_answers')='array' AND jsonb_typeof(d->'native_rating')='object' AND (d->'native_rating') ? 'rating' AND jsonb_typeof(d->'native_rating'->'review_count')='number' AND (d->'native_rating'->>'review_count') ~ '^[0-9]+$' AND jsonb_typeof(d->'locations')='array' AND jsonb_typeof(d->'services')='array' AND jsonb_typeof(d->'media')='array',false)
$$;
REVOKE ALL ON FUNCTION private.publish_snapshot_complete_candidate(jsonb) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION private.guard_publish_artifact_candidate() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM jsonb_each_text(NEW.manifest) m WHERE m.key !~ '^(index\.html|profile\.(css|json|md)|llms\.txt|media/[A-Za-z0-9_-]+\.(png|jpg|jpeg|webp))$' OR m.value !~ '^[0-9a-f]{64}$')
 OR NEW.digest IS DISTINCT FROM (SELECT encode(sha256(convert_to(string_agg(m.key||':'||m.value,E'\n' ORDER BY m.key COLLATE "C"),'UTF8')),'hex') FROM jsonb_each_text(NEW.manifest) m)
 THEN RAISE EXCEPTION 'invalid artifact manifest'; END IF;
 IF NOT EXISTS(SELECT 1 FROM private.company_publish_attempt_candidate a WHERE a.id=NEW.attempt_id AND a.run_id=NEW.run_id AND a.state='building' AND a.lease_until>clock_timestamp() AND private.publish_snapshot_complete_candidate(a.snapshot)) THEN RAISE EXCEPTION 'invalid or incomplete candidate'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.guard_publish_artifact_candidate() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_publish_artifact_candidate BEFORE INSERT OR UPDATE ON private.company_publish_artifact_candidate FOR EACH ROW EXECUTE FUNCTION private.guard_publish_artifact_candidate();

CREATE OR REPLACE FUNCTION private.transition_publish_candidate(p_id uuid,p_run uuid,p_state text,p_revision text DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 PERFORM 1 FROM public.companies c JOIN private.company_publish_attempt_candidate a ON a.company_id=c.id WHERE a.id=p_id FOR UPDATE OF c;
 IF p_state='published' THEN
  PERFORM 1 FROM public.company_memberships m JOIN private.company_publish_attempt_candidate a ON a.company_id=m.company_id AND a.requested_by=m.user_id
  WHERE a.id=p_id AND m.role='owner' AND m.verification_status='verified' FOR SHARE OF m;
  IF NOT FOUND THEN RETURN false; END IF;
 END IF;
 UPDATE private.company_publish_attempt_candidate a SET state=p_state,artifact_revision=p_revision,lease_until=NULL
 WHERE a.id=p_id AND a.state='building' AND a.run_id=p_run AND a.lease_until>clock_timestamp() AND ((p_state='published' AND private.publish_snapshot_complete_candidate(a.snapshot) AND private.get_company_complete_candidate_v1(a.slug)=a.snapshot AND private.resolve_public_company_id_v1(a.slug)=a.company_id AND EXISTS(SELECT 1 FROM public.companies c WHERE c.id=a.company_id AND c.slug=a.slug) AND EXISTS(SELECT 1 FROM private.company_publish_artifact_candidate f WHERE f.attempt_id=a.id AND f.run_id=p_run AND f.digest=p_revision)) OR (p_state='failed' AND p_revision IS NULL));
 RETURN FOUND;
END $$;

CREATE FUNCTION private.resolve_company_artifact_candidate(p_slug text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('company_id',a.company_id,'slug',a.slug,'revision',a.artifact_revision,'manifest',f.manifest)
 FROM private.company_publish_attempt_candidate a
 JOIN private.company_publish_artifact_candidate f ON f.attempt_id=a.id AND f.run_id=a.run_id AND f.digest=a.artifact_revision
 WHERE a.state='published' AND a.company_id=private.resolve_public_company_id_v1(p_slug) AND a.slug=p_slug
 AND a.snapshot=private.get_company_complete_candidate_v1(a.slug)
 AND EXISTS(SELECT 1 FROM public.company_memberships m WHERE m.company_id=a.company_id AND m.user_id=a.requested_by AND m.role='owner' AND m.verification_status='verified')
 ORDER BY a.created_at DESC,a.id DESC LIMIT 1
$$;
REVOKE ALL ON FUNCTION private.resolve_company_artifact_candidate(text) FROM PUBLIC,anon,authenticated;


ALTER TABLE public.company_profile_publications ADD COLUMN attempt_id uuid REFERENCES private.company_publish_attempt_candidate(id);
CREATE FUNCTION private.sync_company_publication_status_candidate() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $sync$
BEGIN
 INSERT INTO public.company_profile_publications(company_id,slug,status,requested_at,started_at,completed_at,artifact_revision,attempt_id,updated_at)
 VALUES(NEW.company_id,NEW.slug,NEW.state,NEW.created_at,CASE WHEN NEW.state='building' THEN clock_timestamp() END,CASE WHEN NEW.state IN('published','failed') THEN clock_timestamp() END,NEW.artifact_revision,NEW.id,clock_timestamp())
 ON CONFLICT(company_id) DO UPDATE SET slug=excluded.slug,status=excluded.status,requested_at=excluded.requested_at,started_at=coalesce(excluded.started_at,CASE WHEN public.company_profile_publications.attempt_id=NEW.id THEN public.company_profile_publications.started_at END),completed_at=excluded.completed_at,artifact_revision=excluded.artifact_revision,attempt_id=excluded.attempt_id,updated_at=excluded.updated_at
 WHERE public.company_profile_publications.attempt_id=NEW.id OR public.company_profile_publications.requested_at<=NEW.created_at;
 RETURN NEW;
END $sync$;
REVOKE ALL ON FUNCTION private.sync_company_publication_status_candidate() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER company_publication_canonical_status AFTER INSERT OR UPDATE ON private.company_publish_attempt_candidate FOR EACH ROW EXECUTE FUNCTION private.sync_company_publication_status_candidate();
CREATE FUNCTION public.request_my_company_publication(p_company_id uuid,p_request_id uuid) RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $request$
 SELECT private.enqueue_company_publish_candidate(p_company_id,p_request_id)
$request$;
REVOKE ALL ON FUNCTION public.request_my_company_publication(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_my_company_publication(uuid,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.get_my_company_publication_status(p_company_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $status$
DECLARE result jsonb; item jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.company_memberships m WHERE m.company_id=p_company_id AND m.user_id=auth.uid() AND m.verification_status='verified') THEN RAISE EXCEPTION 'verified member required' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('company_id',p.company_id,'slug',p.slug,'status',CASE WHEN p.status='published' AND a.snapshot IS DISTINCT FROM private.get_company_complete_candidate_v1(p.slug) THEN 'unknown' ELSE p.status END,'requested_at',p.requested_at,'started_at',p.started_at,'completed_at',p.completed_at,'artifact_revision',p.artifact_revision,'attempt_id',p.attempt_id,'public_url',NULL)
 INTO result FROM public.company_profile_publications p JOIN private.company_publish_attempt_candidate a ON a.id=p.attempt_id AND a.company_id=p.company_id WHERE p.company_id=p_company_id;
 -- A URL is never fabricated from a slug. Delivery stays disabled until the approved route passes hosted acceptance.
 RETURN coalesce(result,jsonb_build_object('company_id',p_company_id,'status','unknown','public_url',NULL));
END $status$;
-- Preserve the canonical named read API; tighten the NEW module's getter to the common visibility/erasure gate.
CREATE OR REPLACE FUNCTION public.get_public_company_profile_v2(p_slug text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $public$
 SELECT d || jsonb_build_object('media',coalesce((SELECT jsonb_agg(m-'object_name') FROM jsonb_array_elements(d->'media') m),'[]'::jsonb)) FROM (SELECT private.get_company_complete_candidate_v1(p_slug) d) v WHERE d IS NOT NULL
$public$;
CREATE OR REPLACE FUNCTION public.get_public_company_profile_v3_candidate(p_slug text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $public$
 SELECT public.get_public_company_profile_v2(p_slug)
$public$;
CREATE OR REPLACE FUNCTION public.get_public_company_content_v1(p_slug text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $public$
 SELECT jsonb_build_object('reviews',d->'reviews','official_qna',d->'questions_answers','knowledge',private.get_public_knowledge_v1((d->>'id')::uuid)) FROM (SELECT private.get_company_complete_candidate_v1(p_slug) d) v WHERE d IS NOT NULL
$public$;
COMMIT;
