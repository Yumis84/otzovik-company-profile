-- Read-only release preflight. No user rows or secrets are returned.
-- Run immediately before the reviewed atomic migration. This does not authorize it.
WITH expected(signature, expected_md5) AS (
 VALUES
 ('public.create_my_company(text,text,text,text,text,text)', '98d71841e7941b405231e6ed98949331'),
 ('public.get_my_companies()', '0d7f2edb1535c0f50bde7a0cf65be389'),
 ('public.update_my_company_profile(uuid,text,text,text,text,text,text)', 'e380e23d4deb6b4ea7894e3bfa2e386a')
), functions AS (
 SELECT e.signature, e.expected_md5, md5(pg_get_functiondef(p.oid)) actual_md5,
 coalesce(p.prosecdef,false) security_definer,
 coalesce(r.rolsuper OR r.rolbypassrls,false) trusted_owner,
 coalesce(has_function_privilege('anon',p.oid,'EXECUTE'),false) anon_execute,
 coalesce(has_function_privilege('authenticated',p.oid,'EXECUTE'),false) authenticated_execute
 FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature)
 LEFT JOIN pg_roles r ON r.oid=p.proowner
), collisions AS (
 SELECT lower(btrim(slug)) FROM public.companies GROUP BY lower(btrim(slug)) HAVING count(*)>1
), checks AS (
 SELECT 'company_rpc_baseline' name, bool_and(coalesce(actual_md5=expected_md5,false)) passed FROM functions
 UNION ALL SELECT 'company_rpc_privileges', bool_and(security_definer AND trusted_owner AND NOT anon_execute AND authenticated_execute) FROM functions
 UNION ALL SELECT 'specialist_table_absent', to_regclass('public.specialist_profiles') IS NULL
 UNION ALL SELECT 'registry_table_absent', to_regclass('public.profile_slug_registry') IS NULL
 UNION ALL SELECT 'normalized_company_slugs_unique', NOT EXISTS(SELECT FROM collisions)
 UNION ALL SELECT 'company_slugs_nonnull', NOT EXISTS(SELECT FROM public.companies WHERE slug IS NULL)
 UNION ALL SELECT 'verified_filter_no_membership_loss', NOT EXISTS(SELECT FROM public.company_memberships WHERE verification_status IS DISTINCT FROM 'verified')
)
SELECT jsonb_build_object(
 'checked_at',now(),
 'preflight_pass', (SELECT bool_and(passed) FROM checks),
 'checks',(SELECT jsonb_object_agg(name,passed) FROM checks),
 'function_baselines',(SELECT jsonb_agg(to_jsonb(f)) FROM functions f),
 'company_count',(SELECT count(*) FROM public.companies),
 'membership_count',(SELECT count(*) FROM public.company_memberships),
 'note','PASS is read-only preflight only, not staging acceptance or deployment authorization. Any drift requires review; do not overwrite newer RPCs.'
) AS preflight;
