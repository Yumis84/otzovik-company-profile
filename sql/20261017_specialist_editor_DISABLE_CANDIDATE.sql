-- REVIEW ONLY: non-destructive emergency disable after editor rollout.
-- Keep drafts, services, contacts, objects, quota and shared slug registry.
BEGIN;
SET LOCAL lock_timeout='5s';
-- Remove specialist policies BEFORE revoking policy helpers, so company Storage
-- queries cannot encounter an EXECUTE failure from a remaining policy expression.
DROP POLICY IF EXISTS specialist_object_read ON storage.objects;
DROP POLICY IF EXISTS specialist_object_insert ON storage.objects;
DROP POLICY IF EXISTS specialist_object_delete ON storage.objects;
REVOKE EXECUTE ON FUNCTION
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
 FROM authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
