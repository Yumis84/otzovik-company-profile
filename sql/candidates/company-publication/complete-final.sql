BEGIN;
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
COMMIT;
