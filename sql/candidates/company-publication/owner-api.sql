BEGIN;
SET LOCAL lock_timeout='3s';
-- Deliberately CREATE (not OR REPLACE): never overwrite an existing publisher contract.
CREATE FUNCTION public.request_my_company_publication(p_company_id uuid,p_request_id uuid) RETURNS uuid
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT private.enqueue_company_publish_candidate(p_company_id,p_request_id)
$$;
CREATE FUNCTION public.get_my_company_publication_status(p_company_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.company_memberships m WHERE m.company_id=p_company_id AND m.user_id=auth.uid() AND m.verification_status='verified')
 THEN RAISE EXCEPTION 'verified member required' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('company_id',a.company_id,'slug',a.slug,'status',CASE WHEN a.state='published' AND a.snapshot IS DISTINCT FROM private.get_company_complete_candidate_v1(a.slug) THEN 'unknown' ELSE a.state END,'requested_at',a.created_at,'artifact_revision',a.artifact_revision)
 INTO result FROM private.company_publish_attempt_candidate a WHERE a.company_id=p_company_id ORDER BY a.created_at DESC,a.id DESC LIMIT 1;
 RETURN coalesce(result,jsonb_build_object('company_id',p_company_id,'status','unknown'));
END $$;
REVOKE ALL ON FUNCTION public.request_my_company_publication(uuid,uuid),public.get_my_company_publication_status(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_my_company_publication(uuid,uuid),public.get_my_company_publication_status(uuid) TO authenticated;
COMMIT;
