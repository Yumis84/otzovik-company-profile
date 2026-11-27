BEGIN;
DO $test$ BEGIN
 IF has_schema_privilege('anon','private','USAGE') OR has_schema_privilege('authenticated','private','USAGE') THEN RAISE EXCEPTION 'private schema client exposure'; END IF;
 IF has_function_privilege('anon','public.request_my_company_publication(uuid,uuid)','EXECUTE') OR has_function_privilege('anon','public.get_my_company_publication_status(uuid)','EXECUTE') THEN RAISE EXCEPTION 'anonymous owner API exposure'; END IF;
 IF has_function_privilege('authenticated','public.record_review_source_rating_snapshot(uuid,numeric,numeric,integer,integer,timestamptz)','EXECUTE') THEN RAISE EXCEPTION 'untrusted rating ingest'; END IF;
 IF has_table_privilege('authenticated','public.review_sources','INSERT,UPDATE,DELETE') OR has_table_privilege('anon','public.reviews','SELECT,INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'direct write or private review exposure'; END IF;
END $test$;
SELECT set_config('request.jwt.claim.sub',(SELECT user_id::text FROM company_memberships WHERE company_id='4616c65b-5ebb-4c13-b2ef-24e2bc40d623' AND role='owner'),true);
SET LOCAL ROLE authenticated;
DO $test$ DECLARE denied boolean:=false; BEGIN
 BEGIN EXECUTE 'SELECT * FROM private.review_revisions_v1'; EXCEPTION WHEN insufficient_privilege THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'private table readable'; END IF;
 denied:=false;
 BEGIN INSERT INTO public.review_sources(company_id,name,source_type,profile_url,collection_method) VALUES('4616c65b-5ebb-4c13-b2ef-24e2bc40d623','Blocked','other','https://blocked.invalid','manual'); EXCEPTION WHEN insufficient_privilege THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'direct source write allowed'; END IF;
END $test$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','00b9d765-6a99-4a57-9091-3e31ff0886bd',true);
SET LOCAL ROLE authenticated;
DO $test$ DECLARE denied boolean:=false; BEGIN
 BEGIN PERFORM public.get_my_company_client_content('4616c65b-5ebb-4c13-b2ef-24e2bc40d623'); EXCEPTION WHEN insufficient_privilege THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'foreign content access allowed'; END IF;
 denied:=false;
 BEGIN PERFORM public.upsert_my_company_question_answer('4616c65b-5ebb-4c13-b2ef-24e2bc40d623',NULL,'Foreign question','Forbidden answer',NULL,NULL,true); EXCEPTION WHEN insufficient_privilege THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'foreign Q&A write allowed'; END IF;
END $test$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $test$ BEGIN
 IF public.get_public_company_profile_v2('work1-company-invites-2711') IS NOT NULL THEN RAISE EXCEPTION 'unapproved profile readable'; END IF;
 IF public.get_public_company_content_v1('work1-company-invites-2711') IS NOT NULL THEN RAISE EXCEPTION 'inactive content readable'; END IF;
END $test$;
RESET ROLE;
SELECT 'PASS schema/RPC/direct-table/RLS/foreign owner checks; inactive anonymous public read blocked';
ROLLBACK;
