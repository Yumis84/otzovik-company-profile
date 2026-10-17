-- Editor-only metadata preflight; does not authorize any production changes.
-- Base specialist schema must already exist. No user rows are returned.
SELECT jsonb_build_object(
 'checked_at',now(),'deployment_role',current_user,
 'trusted_bypassrls',EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)),
 'can_create_storage_policy',EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND rolsuper)
   OR EXISTS(SELECT FROM pg_class c WHERE c.oid='storage.objects'::regclass AND pg_has_role(current_user,c.relowner,'USAGE')),
 'can_insert_bucket',has_table_privilege(current_user,'storage.buckets','INSERT'),
 'storage_objects_owner',(SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='storage.objects'::regclass),
 'authenticated_config',(SELECT rolconfig FROM pg_roles WHERE rolname='authenticated'),
 'base_exists',to_regclass('public.specialist_profiles') IS NOT NULL,
 'editor_absent',to_regclass('public.specialist_services') IS NULL AND to_regclass('public.specialist_settings') IS NULL AND to_regclass('public.specialist_media') IS NULL,
 'bucket_absent',NOT EXISTS(SELECT FROM storage.buckets WHERE id='specialist-media'),
 'note','All prerequisites plus hosted acceptance and owner GO are required. BYPASSRLS alone cannot CREATE POLICY. Never change managed Storage ownership or grant privileged roles to bypass this gate.'
) AS editor_preflight;
