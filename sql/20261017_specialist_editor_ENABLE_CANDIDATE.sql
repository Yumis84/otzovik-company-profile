-- REVIEW ONLY: restore reviewed editor access after DISABLE; never rerun apply DDL.
-- Retains all records and objects. Existing policy names cause atomic refusal.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $prerequisites$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION 'Trusted BYPASSRLS deployment role required'; END IF;
 IF NOT EXISTS(SELECT FROM storage.buckets WHERE id='specialist-media' AND public=false AND file_size_limit=5242880 AND allowed_mime_types @> ARRAY['image/jpeg','image/png','image/webp'] AND allowed_mime_types <@ ARRAY['image/jpeg','image/png','image/webp']) THEN RAISE EXCEPTION 'Reviewed private specialist bucket configuration required'; END IF;
 IF EXISTS(SELECT FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname IN ('specialist_object_read','specialist_object_insert','specialist_object_delete')) THEN RAISE EXCEPTION 'Editor policies already exist; review instead of overwriting'; END IF;
END $prerequisites$;
-- Restore only reviewed RPC/helper privileges, never direct table access or anon.
REVOKE ALL ON FUNCTION
 public.get_my_specialist_services(uuid),
 public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer),
 public.delete_my_specialist_service(uuid,uuid,integer),
 public.get_my_specialist_settings(uuid),
 public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer),
 public.get_my_specialist_media(uuid),
 public.register_my_specialist_media(uuid,text,text,text),
 public.delete_my_specialist_media(uuid,uuid),
 public.delete_my_specialist_draft(uuid),
 public.can_manage_specialist_object(text),
 public.can_upload_specialist_object(text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION
 public.get_my_specialist_services(uuid),
 public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer),
 public.delete_my_specialist_service(uuid,uuid,integer),
 public.get_my_specialist_settings(uuid),
 public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer),
 public.get_my_specialist_media(uuid),
 public.register_my_specialist_media(uuid,text,text,text),
 public.delete_my_specialist_media(uuid,uuid),
 public.delete_my_specialist_draft(uuid),
 public.can_manage_specialist_object(text),
 public.can_upload_specialist_object(text)
 TO authenticated;
CREATE POLICY specialist_object_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='specialist-media' AND public.can_manage_specialist_object(name));
CREATE POLICY specialist_object_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='specialist-media' AND public.can_upload_specialist_object(name));
CREATE POLICY specialist_object_delete ON storage.objects FOR DELETE TO authenticated USING(bucket_id='specialist-media' AND public.can_manage_specialist_object(name));
NOTIFY pgrst,'reload schema';
COMMIT;
