-- REVIEW ONLY. New private output bucket; no changes to existing bucket policies or grants.
BEGIN;
SET LOCAL lock_timeout='3s';
DO $pre$ BEGIN
 IF EXISTS(SELECT 1 FROM storage.buckets WHERE id='company-publication-artifacts-staging') THEN RAISE EXCEPTION 'artifact bucket already exists'; END IF;
END $pre$;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('company-publication-artifacts-staging','company-publication-artifacts-staging',false,5242880,ARRAY['text/html','text/css','application/json','text/plain','image/png','image/jpeg','image/webp']);
CREATE FUNCTION public.company_publish_worker_claim(p_run uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT private.claim_publish_candidate(p_run) $$;
CREATE FUNCTION public.company_publish_worker_heartbeat(p_attempt uuid,p_run uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT private.heartbeat_publish_candidate(p_attempt,p_run) $$;
CREATE FUNCTION public.company_publish_worker_fail(p_attempt uuid,p_run uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF private.transition_publish_candidate(p_attempt,p_run,'failed',NULL) THEN RETURN true; END IF;
 -- Trusted worker's post-publication route verification may invalidate only its own attempt.
 UPDATE private.company_publish_attempt_candidate SET state='failed',artifact_revision=NULL WHERE id=p_attempt AND run_id=p_run AND state='published';
 RETURN FOUND;
END $$;
CREATE FUNCTION public.company_publish_worker_register(p_attempt uuid,p_run uuid,p_manifest jsonb,p_digest text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $register$
DECLARE c uuid;
BEGIN
 IF NOT coalesce((SELECT enabled FROM private.compatibility_flags_v1 WHERE key='staging_company_profile_delivery_ready'),false) THEN RAISE EXCEPTION 'staging delivery not enabled'; END IF;
 SELECT company_id INTO c FROM private.company_publish_attempt_candidate WHERE id=p_attempt AND run_id=p_run AND state='building' FOR UPDATE;
 IF c IS NULL THEN RAISE EXCEPTION 'unknown worker attempt'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each_text(p_manifest) m WHERE NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='company-publication-artifacts-staging' AND o.name=c::text||'/'||p_digest||'/'||m.key)) THEN RAISE EXCEPTION 'artifact objects missing'; END IF;
 INSERT INTO private.company_publish_artifact_candidate(attempt_id,run_id,digest,manifest) VALUES(p_attempt,p_run,p_digest,p_manifest);
 IF NOT private.transition_publish_candidate(p_attempt,p_run,'published',p_digest) THEN RAISE EXCEPTION 'artifact finalization denied'; END IF;
 RETURN true;
END $register$;
CREATE FUNCTION public.resolve_company_public_asset(p_slug text,p_asset text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $asset$
DECLARE d jsonb; object_name text; mime text;
BEGIN
 IF NOT coalesce((SELECT enabled FROM private.compatibility_flags_v1 WHERE key='staging_company_profile_delivery_ready'),false) THEN RETURN NULL; END IF;
 IF p_asset IS NULL OR p_asset!~'^(index\.html|profile\.(css|json|md)|llms\.txt|media/[A-Za-z0-9_-]+\.(png|jpg|jpeg|webp))$' THEN RETURN NULL; END IF;
 d:=private.resolve_company_artifact_candidate(p_slug);
 IF d IS NULL OR d->'manifest'->>p_asset IS NULL THEN RETURN NULL; END IF;
 object_name:=(d->>'company_id')||'/'||(d->>'revision')||'/'||p_asset;
 IF NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='company-publication-artifacts-staging' AND o.name=object_name) THEN RETURN NULL; END IF;
 mime:=CASE WHEN p_asset LIKE '%.html' THEN 'text/html; charset=utf-8' WHEN p_asset LIKE '%.css' THEN 'text/css; charset=utf-8' WHEN p_asset LIKE '%.json' THEN 'application/json; charset=utf-8' WHEN p_asset LIKE '%.png' THEN 'image/png' WHEN p_asset LIKE '%.jpg' OR p_asset LIKE '%.jpeg' THEN 'image/jpeg' WHEN p_asset LIKE '%.webp' THEN 'image/webp' ELSE 'text/plain; charset=utf-8' END;
 RETURN jsonb_build_object('bucket','company-publication-artifacts-staging','object_name',object_name,'sha256',d->'manifest'->>p_asset,'content_type',mime,'company_id',d->>'company_id','revision',d->>'revision');
END $asset$;
REVOKE ALL ON FUNCTION public.company_publish_worker_claim(uuid),public.company_publish_worker_heartbeat(uuid,uuid),public.company_publish_worker_fail(uuid,uuid),public.company_publish_worker_register(uuid,uuid,jsonb,text),public.resolve_company_public_asset(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.company_publish_worker_claim(uuid),public.company_publish_worker_heartbeat(uuid,uuid),public.company_publish_worker_fail(uuid,uuid),public.company_publish_worker_register(uuid,uuid,jsonb,text),public.resolve_company_public_asset(text,text) TO service_role;
CREATE OR REPLACE FUNCTION public.get_my_company_publication_status(p_company_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $status$
DECLARE result jsonb; visible jsonb; ready boolean:=coalesce((SELECT enabled FROM private.compatibility_flags_v1 WHERE key='staging_company_profile_delivery_ready'),false);
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.company_memberships m WHERE m.company_id=p_company_id AND m.user_id=auth.uid() AND m.verification_status='verified') THEN RAISE EXCEPTION 'verified member required' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('company_id',p.company_id,'slug',p.slug,'status',CASE WHEN p.status='published' AND (a.snapshot IS DISTINCT FROM private.get_company_complete_candidate_v1(p.slug) OR NOT coalesce(ready,false)) THEN 'unknown' ELSE p.status END,'requested_at',p.requested_at,'started_at',p.started_at,'completed_at',p.completed_at,'attempt_id',p.attempt_id,'artifact_revision',p.artifact_revision,'public_url',CASE WHEN ready AND p.status='published' AND private.resolve_company_artifact_candidate(p.slug) IS NOT NULL THEN 'https://salmcnhexlftrgtiryyo.supabase.co/functions/v1/company-public-profile/'||p.slug||'/' END)
 INTO result FROM public.company_profile_publications p JOIN private.company_publish_attempt_candidate a ON a.id=p.attempt_id AND a.company_id=p.company_id WHERE p.company_id=p_company_id;
 RETURN coalesce(result,jsonb_build_object('company_id',p_company_id,'status','unknown','public_url',NULL));
END $status$;
COMMIT;
