-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
UPDATE public.specialist_upload_control SET enabled=false WHERE singleton;
-- Keep owner read/signed downloads and all restrictive policies. In-flight operations remain reserved. Never restore direct writes.
NOTIFY pgrst,'reload schema';
COMMIT;
