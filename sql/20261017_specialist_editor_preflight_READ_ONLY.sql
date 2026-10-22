-- Editor-only metadata preflight; does not authorize any production changes.
-- Base specialist schema must already exist. No user rows are returned.
SELECT jsonb_build_object(
 'checked_at',now(),'deployment_role',current_user,
 'trusted_bypassrls',EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)),
 'can_create_storage_policy',EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND rolsuper)
   OR EXISTS(SELECT FROM pg_class c WHERE c.oid='storage.objects'::regclass AND pg_has_role(current_user,c.relowner,'USAGE'))
   OR (coalesce((nullif(current_setting('supautils.policy_grants',true),'')::jsonb -> current_user) ? 'storage.objects',false)
 AND 'supautils'=ANY(string_to_array(replace(coalesce(current_setting('shared_preload_libraries',true),'')||','||coalesce(current_setting('session_preload_libraries',true),''),' ',''),','))),
 'supautils_policy_grant',coalesce((nullif(current_setting('supautils.policy_grants',true),'')::jsonb -> current_user) ? 'storage.objects',false)
 AND 'supautils'=ANY(string_to_array(replace(coalesce(current_setting('shared_preload_libraries',true),'')||','||coalesce(current_setting('session_preload_libraries',true),''),' ',''),',')),
 'can_insert_bucket',has_table_privilege(current_user,'storage.buckets','INSERT'),
 'storage_objects_owner',(SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='storage.objects'::regclass),
 'authenticated_config',(SELECT rolconfig FROM pg_roles WHERE rolname='authenticated'),
 'base_exists',to_regclass('public.specialist_profiles') IS NOT NULL,
 'editor_absent',to_regclass('public.specialist_services') IS NULL AND to_regclass('public.specialist_settings') IS NULL AND to_regclass('public.specialist_media') IS NULL,
 'bucket_absent',NOT EXISTS(SELECT FROM storage.buckets WHERE id='specialist-media'),
 'note','All prerequisites plus hosted acceptance and owner GO are required. BYPASSRLS alone cannot CREATE POLICY. Never change managed Storage ownership or grant privileged roles to bypass this gate.'
) AS editor_preflight;
