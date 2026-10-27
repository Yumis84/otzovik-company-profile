-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
REVOKE EXECUTE ON FUNCTION public.get_my_specialist_settings(uuid),public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer) FROM authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
