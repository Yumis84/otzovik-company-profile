-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE POLICY specialist_gateway_insert_only ON storage.objects AS RESTRICTIVE FOR INSERT TO anon,authenticated WITH CHECK(bucket_id IS DISTINCT FROM 'specialist-media');
CREATE POLICY specialist_gateway_update_only ON storage.objects AS RESTRICTIVE FOR UPDATE TO anon,authenticated USING(bucket_id IS DISTINCT FROM 'specialist-media') WITH CHECK(bucket_id IS DISTINCT FROM 'specialist-media');
CREATE POLICY specialist_gateway_delete_only ON storage.objects AS RESTRICTIVE FOR DELETE TO anon,authenticated USING(bucket_id IS DISTINCT FROM 'specialist-media');

NOTIFY pgrst,'reload schema';
COMMIT;
