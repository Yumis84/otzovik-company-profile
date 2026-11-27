-- Isolated clone only. SQL claim simulation is NOT hosted JWT acceptance.
BEGIN;
SELECT set_config('test.company','4616c65b-5ebb-4c13-b2ef-24e2bc40d623',true);
SELECT set_config('test.owner',(SELECT user_id::text FROM public.company_memberships WHERE company_id=current_setting('test.company')::uuid AND role='owner'),true);
INSERT INTO public.company_memberships(company_id,user_id,role,verification_status)
VALUES(current_setting('test.company')::uuid,'00b9d765-6a99-4a57-9091-3e31ff0886bd','analyst','verified');
SELECT set_config('request.jwt.claim.sub','00b9d765-6a99-4a57-9091-3e31ff0886bd',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE denied boolean:=false; BEGIN
 BEGIN PERFORM public.owner_remove_company_member(current_setting('test.company')::uuid,current_setting('test.owner')::uuid); EXCEPTION WHEN OTHERS THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'analyst remove allowed'; END IF;
 denied:=false;
 BEGIN PERFORM public.owner_update_company_member_role(current_setting('test.company')::uuid,'00b9d765-6a99-4a57-9091-3e31ff0886bd','admin'); EXCEPTION WHEN OTHERS THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'analyst escalation allowed'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE denied boolean:=false; BEGIN
 IF NOT public.owner_update_company_member_role(current_setting('test.company')::uuid,'00b9d765-6a99-4a57-9091-3e31ff0886bd','manager') THEN RAISE EXCEPTION 'owner update failed'; END IF;
 BEGIN PERFORM public.owner_remove_company_member(current_setting('test.company')::uuid,current_setting('test.owner')::uuid); EXCEPTION WHEN OTHERS THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'owner self remove allowed'; END IF;
 denied:=false;
 BEGIN PERFORM public.owner_update_company_member_role(current_setting('test.company')::uuid,'00b9d765-6a99-4a57-9091-3e31ff0886bd','owner'); EXCEPTION WHEN OTHERS THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'owner promotion allowed'; END IF;

 IF NOT public.owner_remove_company_member(current_setting('test.company')::uuid,'00b9d765-6a99-4a57-9091-3e31ff0886bd') THEN RAISE EXCEPTION 'owner remove failed'; END IF;
 IF public.owner_remove_company_member(current_setting('test.company')::uuid,'00b9d765-6a99-4a57-9091-3e31ff0886bd') THEN RAISE EXCEPTION 'remove retry not idempotent'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','00b9d765-6a99-4a57-9091-3e31ff0886bd',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE denied boolean:=false; BEGIN
 BEGIN PERFORM public.get_my_company_client_content(current_setting('test.company')::uuid); EXCEPTION WHEN insufficient_privilege THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'revoked member readable'; END IF;
END $$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS canonical membership update/remove: owner/analyst/self/promotion/idempotency/revoked read; isolated SQL only';
