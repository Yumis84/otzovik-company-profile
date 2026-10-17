-- Candidate only. Independent of PR23. No production execution authorized.
BEGIN;
CREATE SCHEMA ai_private;
REVOKE ALL ON SCHEMA ai_private FROM PUBLIC,anon,authenticated;
CREATE TABLE ai_private.configs (
 kind text NOT NULL CHECK(kind IN ('company','specialist')), profile_id uuid NOT NULL,
 version integer NOT NULL DEFAULT 1, enabled boolean NOT NULL DEFAULT false,
 greeting text NOT NULL DEFAULT 'Здравствуйте! Чем помочь?', instructions text NOT NULL DEFAULT '',
 extra_information text NOT NULL DEFAULT '', position text NOT NULL DEFAULT 'bottom-right' CHECK(position IN ('bottom-right','bottom-left','inline')),
 CHECK(length(greeting)<=300 AND length(instructions)<=2000 AND length(extra_information)<=4000),
 PRIMARY KEY(kind,profile_id)
);
-- Published export adapter only; never populated from private profile rows.
CREATE TABLE ai_private.snapshots (
 kind text NOT NULL CHECK(kind IN ('company','specialist')), profile_id uuid NOT NULL,
 revision text NOT NULL, payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object' AND octet_length(payload::text)<=24000),
 PRIMARY KEY(kind,profile_id)
);
CREATE TABLE ai_private.platform (singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), disabled boolean NOT NULL DEFAULT true);
INSERT INTO ai_private.platform VALUES(true,true);
CREATE TABLE ai_private.sessions (
 token_hash text PRIMARY KEY, kind text NOT NULL, profile_id uuid NOT NULL, owner_id uuid NOT NULL,
 expires_at timestamptz NOT NULL, revision text NOT NULL,
 history jsonb NOT NULL DEFAULT '[]', summary jsonb NOT NULL DEFAULT '{}',
 CHECK(jsonb_typeof(history)='array' AND octet_length(history::text)<=24000),
 CHECK(jsonb_typeof(summary)='object' AND octet_length(summary::text)<=1000),
 FOREIGN KEY(kind,profile_id) REFERENCES ai_private.configs ON DELETE CASCADE
);
CREATE INDEX ON ai_private.sessions(expires_at);
ALTER TABLE ai_private.configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_private.configs FORCE ROW LEVEL SECURITY;
ALTER TABLE ai_private.snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_private.snapshots FORCE ROW LEVEL SECURITY;
ALTER TABLE ai_private.platform ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_private.platform FORCE ROW LEVEL SECURITY;
ALTER TABLE ai_private.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_private.sessions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA ai_private FROM PUBLIC,anon,authenticated;
CREATE FUNCTION ai_private.can_manage(k text,p uuid) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE ok boolean := false;
BEGIN
 IF auth.uid() IS NULL THEN RETURN false; END IF;
 IF k='company' THEN
 SELECT EXISTS(SELECT 1 FROM public.company_memberships WHERE company_id=p AND user_id=auth.uid() AND verification_status='verified' AND role='owner') INTO ok;
 ELSIF k='specialist' AND to_regclass('public.specialist_profiles') IS NOT NULL THEN
 EXECUTE 'SELECT EXISTS(SELECT 1 FROM public.specialist_profiles WHERE id=$1 AND owner_user_id=$2)' INTO ok USING p,auth.uid();
 END IF;
 RETURN ok;
END $$;
CREATE FUNCTION public.get_my_ai_config(profile_kind text,profile_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT ai_private.can_manage(profile_kind,profile_id) THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 SELECT to_jsonb(c) INTO result FROM ai_private.configs c WHERE c.kind=profile_kind AND c.profile_id=get_my_ai_config.profile_id;
 RETURN coalesce(result,jsonb_build_object('version',0,'enabled',false,'greeting','Здравствуйте! Чем помочь?','instructions','','extra_information','','position','bottom-right'));
END $$;
CREATE FUNCTION public.save_my_ai_config(profile_kind text,profile_id uuid,expected_version integer,settings jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE current_version integer; result jsonb;
BEGIN
 IF NOT ai_private.can_manage(profile_kind,profile_id) THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 IF settings IS NULL OR jsonb_typeof(settings)<>'object' OR settings - ARRAY['enabled','greeting','instructions','extra_information','position'] <> '{}'::jsonb THEN RAISE EXCEPTION 'Invalid settings' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(profile_kind||profile_id::text,0));
 SELECT version INTO current_version FROM ai_private.configs c WHERE c.kind=profile_kind AND c.profile_id=save_my_ai_config.profile_id FOR UPDATE;
 IF coalesce(current_version,0)<>expected_version THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='PT409'; END IF;
 INSERT INTO ai_private.configs AS c(kind,profile_id,version,enabled,greeting,instructions,extra_information,position)
 VALUES(profile_kind,profile_id,expected_version+1,coalesce((settings->>'enabled')::boolean,false),coalesce(settings->>'greeting',''),coalesce(settings->>'instructions',''),coalesce(settings->>'extra_information',''),coalesce(settings->>'position','bottom-right'))
 ON CONFLICT ON CONSTRAINT configs_pkey DO UPDATE SET version=excluded.version,enabled=excluded.enabled,greeting=excluded.greeting,instructions=excluded.instructions,extra_information=excluded.extra_information,position=excluded.position
 RETURNING to_jsonb(c) INTO result;
 RETURN result;
END $$;
CREATE FUNCTION public.get_my_ai_snapshot(profile_kind text,profile_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT ai_private.can_manage(profile_kind,profile_id) THEN RAISE EXCEPTION 'Access denied' USING ERRCODE='42501'; END IF;
 -- Specialist publication contract does not yet exist; never accept its draft as a snapshot.
 IF profile_kind='specialist' THEN RETURN NULL; END IF;
 IF (SELECT disabled FROM ai_private.platform WHERE singleton) THEN RAISE EXCEPTION 'AI disabled' USING ERRCODE='PT503'; END IF;
 SELECT jsonb_build_object('kind',s.kind,'profile_id',s.profile_id,'revision',s.revision,'payload',s.payload) INTO result FROM ai_private.snapshots s WHERE s.kind=profile_kind AND s.profile_id=get_my_ai_snapshot.profile_id;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.get_my_ai_snapshot(text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_ai_snapshot(text,uuid) TO authenticated;
REVOKE ALL ON FUNCTION ai_private.can_manage(text,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.get_my_ai_config(text,uuid),public.save_my_ai_config(text,uuid,integer,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_ai_config(text,uuid),public.save_my_ai_config(text,uuid,integer,jsonb) TO authenticated;
COMMIT;
