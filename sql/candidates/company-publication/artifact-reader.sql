BEGIN;
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
COMMIT;
