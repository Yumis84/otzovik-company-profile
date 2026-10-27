-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN IF EXISTS(SELECT FROM pg_trigger WHERE tgname='specialist_object_integrity') OR (SELECT count(*) FROM pg_policy WHERE polrelid='storage.objects'::regclass AND polname IN ('specialist_gateway_insert_only','specialist_gateway_update_only','specialist_gateway_delete_only') AND NOT polpermissive)<>3 THEN RAISE EXCEPTION 'Storage gateway barrier not proven'; END IF; IF has_function_privilege('authenticated','public.specialist_gateway_reserve(uuid,uuid,uuid,text,text,text,integer,text)','EXECUTE') OR has_function_privilege('anon','public.specialist_gateway_reserve(uuid,uuid,uuid,text,text,text,integer,text)','EXECUTE') THEN RAISE EXCEPTION 'Gateway ACL open'; END IF; END $$;
UPDATE public.specialist_upload_control SET enabled=true WHERE singleton;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_media(uuid),public.get_my_specialist_upload_capability(uuid),public.delete_my_specialist_draft(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
