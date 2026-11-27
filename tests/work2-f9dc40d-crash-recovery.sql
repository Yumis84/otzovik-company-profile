BEGIN;
INSERT INTO public.company_profile_public_access(company_id,state) VALUES('4616c65b-5ebb-4c13-b2ef-24e2bc40d623','active');
SELECT set_config('request.jwt.claim.sub',(SELECT user_id::text FROM public.company_memberships WHERE company_id='4616c65b-5ebb-4c13-b2ef-24e2bc40d623' AND role='owner' LIMIT 1),true);
SET LOCAL ROLE authenticated;
SELECT public.request_my_company_publication('4616c65b-5ebb-4c13-b2ef-24e2bc40d623',gen_random_uuid());
RESET ROLE;
DO $test$ DECLARE r jsonb; attempt uuid; claim2 jsonb; BEGIN
 r:=private.claim_publish_candidate(gen_random_uuid());attempt:=(r->>'id')::uuid;
 IF attempt IS NULL THEN RAISE EXCEPTION 'fixture did not claim'; END IF;
 UPDATE private.company_publish_attempt_candidate SET lease_until=clock_timestamp()-interval '1 minute' WHERE id=attempt;
 claim2:=private.claim_publish_candidate(gen_random_uuid());
 IF claim2 IS NOT NULL THEN RAISE EXCEPTION 'unexpected recovery; investigate changed source'; END IF;
 IF (SELECT state FROM private.company_publish_attempt_candidate WHERE id=attempt)<>'building' THEN RAISE EXCEPTION 'unexpected state'; END IF;
 IF private.enqueue_company_publish_candidate('4616c65b-5ebb-4c13-b2ef-24e2bc40d623',gen_random_uuid()) IS DISTINCT FROM attempt THEN RAISE EXCEPTION 'unexpected new attempt'; END IF;
 RAISE NOTICE 'CONFIRMED BLOCKER: expired building lease not recovered by claim; new request coalesces stuck attempt';
 IF private.expire_publish_candidates()<>1 THEN RAISE EXCEPTION 'explicit expire failed'; END IF;
 IF (SELECT state FROM private.company_publish_attempt_candidate WHERE id=attempt)<>'failed' THEN RAISE EXCEPTION 'expiry did not release'; END IF;
END $test$;
ROLLBACK;
