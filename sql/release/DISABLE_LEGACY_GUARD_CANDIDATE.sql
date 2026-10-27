-- REVIEW ONLY for a site that explicitly approved the old guard. NOT part of gateway rollout.
-- Removes quota protection if direct writes remain open; disable UI/uploads and close direct policies FIRST.
BEGIN;
SET LOCAL lock_timeout='5s';
DROP TRIGGER IF EXISTS specialist_object_integrity ON storage.objects;
-- Keep the function and all user data; no CASCADE. Never automatically restore the rejected trigger.
COMMIT;
