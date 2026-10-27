-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
GRANT EXECUTE ON FUNCTION public.get_my_specialist_services(uuid),public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer),public.delete_my_specialist_service(uuid,uuid,integer) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
