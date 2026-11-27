"""Compose PR56's reviewed queue with the canonical publication status table."""
import pathlib,re
repo=pathlib.Path(__file__).resolve().parents[1];src=repo/'sql/candidates/company-publication';dst=repo/'sql/candidates/staging-company-integration'
def body(name):
 s=(src/name).read_text();return re.sub(r'^COMMIT;\s*$','',re.sub(r'^BEGIN;\s*','',s,flags=re.M),flags=re.M).strip()
read=(src/'readability.sql').read_text();read=read[read.index('CREATE FUNCTION private.is_company_publicly_readable_v1'):read.rindex('COMMIT;')]
parts=['-- REVIEW ONLY; apply after 10 on an isolated existing-staging clone.','BEGIN;',"SET LOCAL lock_timeout='3s'; SET LOCAL statement_timeout='60s';",read]
parts += [body(x) for x in ['dto.sql','sources-gate.sql','content-dto.sql','publisher-candidate.sql','completeness.sql','complete-final.sql','artifact-reader.sql']]
parts.append('''
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
''')
(dst/'20-publisher-integration.sql').write_text('\n\n'.join(parts))
print('composed canonical status integration, no replacement of baseline existing functions or grants')
