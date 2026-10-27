-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
REVOKE EXECUTE ON FUNCTION public.list_my_specialist_channels(uuid),public.save_my_specialist_channels(uuid,integer,jsonb) FROM authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
