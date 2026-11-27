-- Actual cloned staging identities and data. All content writes roll back.
BEGIN;
SELECT set_config('test.company','4616c65b-5ebb-4c13-b2ef-24e2bc40d623',true);
SELECT set_config('request.jwt.claim.sub',(SELECT user_id::text FROM public.company_memberships WHERE company_id=current_setting('test.company')::uuid AND role='owner' LIMIT 1),true);
INSERT INTO public.company_profile_public_access(company_id,state) VALUES(current_setting('test.company')::uuid,'active');
SET LOCAL ROLE authenticated;
DO $test$
DECLARE c uuid:=current_setting('test.company')::uuid; s jsonb; qa jsonb; answer jsonb;
BEGIN
 s:=public.add_my_company_review_source(c,'Staging canonical source','https://2gis.ru/kaliningrad/firm/999999991',NULL);
 PERFORM set_config('test.source',s->>'id',true);
 IF s->>'status'<>'draft' THEN RAISE EXCEPTION 'unchecked source must remain draft'; END IF;
 IF jsonb_array_length(public.get_my_company_review_sources(c))<>1 THEN RAISE EXCEPTION 'source read contract'; END IF;
 qa:=public.upsert_my_company_question_answer(c,NULL,'Synthetic canonical question?','Synthetic canonical answer','Test','Test program',true);
 IF qa->>'status'<>'published' THEN RAISE EXCEPTION 'native Q&A not published'; END IF;
 IF jsonb_array_length(public.get_my_company_client_content(c)->'questions_answers')<>1 THEN RAISE EXCEPTION 'native Q&A read missing'; END IF;
END $test$;
RESET ROLE;
SELECT public.record_review_source_rating_snapshot(current_setting('test.source')::uuid,8,10,NULL,0,now());
INSERT INTO public.review_sources(id,company_id,name,source_type,profile_url,collection_method,status)
VALUES('ce834071-8302-4a2b-8c23-000000000071',current_setting('test.company')::uuid,'Synthetic native reviews','first_party_reviews','https://reviews.invalid/clone','manual','published');
INSERT INTO public.reviews(id,company_id,source_id,source_url,collected_at,rating,rating_scale,content_hash,status,body)
VALUES('ce834072-8302-4a2b-8c23-000000000072',current_setting('test.company')::uuid,'ce834071-8302-4a2b-8c23-000000000071','https://reviews.invalid/clone',now(),4,5,'staging-integration-synthetic','published','Synthetic canonical review');
SET LOCAL ROLE authenticated;
SELECT public.respond_to_my_company_review(current_setting('test.company')::uuid,'ce834072-8302-4a2b-8c23-000000000072','Synthetic canonical official response');
DO $test$
DECLARE d jsonb; a uuid; b uuid; k uuid:=gen_random_uuid();
BEGIN
 d:=public.get_public_company_profile_v2('work1-company-invites-2711');
 IF jsonb_array_length(d->'reviews')<>1 OR jsonb_array_length(d->'questions_answers')<>1 THEN RAISE EXCEPTION 'canonical public DTO incomplete'; END IF;
 IF d->'native_rating'->>'rating'<>'4.00' THEN RAISE EXCEPTION 'native rating mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'media') x WHERE x?'object_name') THEN RAISE EXCEPTION 'private media path exposed'; END IF;
 a:=public.request_my_company_publication(current_setting('test.company')::uuid,k);
 b:=public.request_my_company_publication(current_setting('test.company')::uuid,k);
 IF a IS DISTINCT FROM b OR public.get_my_company_publication_status(current_setting('test.company')::uuid)->>'status'<>'queued' THEN RAISE EXCEPTION 'canonical queue/status/replay mismatch'; END IF;
END $test$;
RESET ROLE;
DO $test$
DECLARE r jsonb; a uuid; rejected boolean:=false;
BEGIN
 IF (SELECT count(*) FROM public.company_profile_publications)<>1 THEN RAISE EXCEPTION 'canonical status row absent'; END IF;
 r:=private.claim_publish_candidate(gen_random_uuid());a:=(r->>'id')::uuid;
 IF (SELECT status FROM public.company_profile_publications)<>'building' THEN RAISE EXCEPTION 'canonical building status not atomic'; END IF;
 IF private.transition_publish_candidate(a,(r->>'run_id')::uuid,'published',repeat('0',64)) THEN RAISE EXCEPTION 'proof bypass'; END IF;
 PERFORM private.transition_publish_candidate(a,(r->>'run_id')::uuid,'failed',NULL);
 IF (SELECT status FROM public.company_profile_publications)<>'failed' THEN RAISE EXCEPTION 'failed status not atomic'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00b9d765-6a99-4a57-9091-3e31ff0886bd',true);
 SET LOCAL ROLE authenticated;
 BEGIN PERFORM public.request_my_company_publication(current_setting('test.company')::uuid,gen_random_uuid()); EXCEPTION WHEN insufficient_privilege THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'foreign enqueue accepted'; END IF;
END $test$;
RESET ROLE;
SELECT 'PASS actual cloned owner: source/rating/native Q&A/review/response/DTO, canonical queue+status, proof denial, foreign denial';
ROLLBACK;
