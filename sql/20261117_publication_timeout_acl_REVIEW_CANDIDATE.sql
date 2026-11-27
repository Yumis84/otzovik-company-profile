-- REVIEW ONLY; never apply to a working or hosted database. No grants changed.
-- Caller must verify the exact reviewed baseline definitions before this transaction.
BEGIN;
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '30s';
DO $preflight$
DECLARE signature text; fn oid; owner_oid oid;
BEGIN
 FOREACH signature IN ARRAY ARRAY['public.publish_my_specialist_v1(uuid,integer,uuid)',
  'public.specialist_disable_public_v1(text)', 'public.get_public_specialist_v1(text)',
  'public.specialist_public_fields_version_v1()'] LOOP
  fn:=pg_catalog.to_regprocedure(signature);
  IF fn IS NULL THEN RAISE EXCEPTION 'Required baseline missing: %',signature; END IF;
  SELECT proowner INTO owner_oid FROM pg_catalog.pg_proc WHERE oid=fn;
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE oid=owner_oid AND (rolsuper OR rolbypassrls)) THEN
   RAISE EXCEPTION 'Function owner is not trusted: %',signature;
  END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='anon') OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='authenticated') OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='service_role') THEN
  RAISE EXCEPTION 'Expected roles are absent';
 END IF;
 IF pg_catalog.has_function_privilege('anon','public.publish_my_specialist_v1(uuid,integer,uuid)','EXECUTE') OR pg_catalog.has_function_privilege('anon','public.specialist_disable_public_v1(text)','EXECUTE') THEN
  RAISE EXCEPTION 'Unexpected anonymous execute on privileged functions';
 END IF;
 IF NOT pg_catalog.has_function_privilege('authenticated','public.publish_my_specialist_v1(uuid,integer,uuid)','EXECUTE') OR pg_catalog.has_function_privilege('authenticated','public.specialist_disable_public_v1(text)','EXECUTE') OR pg_catalog.has_function_privilege('service_role','public.specialist_disable_public_v1(text)','EXECUTE') THEN
  RAISE EXCEPTION 'Unexpected effective privileged-function access';
 END IF;
END $preflight$;
CREATE TEMP TABLE _otz_acl_before ON COMMIT DROP AS
 SELECT p.oid,p.proowner,p.proacl,p.proconfig,
 pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE') AS service_execute
 FROM pg_catalog.pg_proc p WHERE p.oid IN (
  'public.publish_my_specialist_v1(uuid,integer,uuid)'::regprocedure,
  'public.specialist_disable_public_v1(text)'::regprocedure,
  'public.get_public_specialist_v1(text)'::regprocedure,
  'public.specialist_public_fields_version_v1()'::regprocedure);
-- 2s is a test candidate, not an approved production SLO.
ALTER FUNCTION public.publish_my_specialist_v1(uuid,integer,uuid) SET lock_timeout='2s';
ALTER FUNCTION public.specialist_disable_public_v1(text) SET lock_timeout='2s';
DO $postcheck$
BEGIN
 IF (SELECT count(*) FROM _otz_acl_before)<>4 OR EXISTS (
  SELECT 1 FROM _otz_acl_before b LEFT JOIN pg_catalog.pg_proc p ON p.oid=b.oid
  WHERE p.oid IS NULL OR p.proowner<>b.proowner OR p.proacl IS DISTINCT FROM b.proacl
   OR pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') IS DISTINCT FROM b.anon_execute
   OR pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') IS DISTINCT FROM b.authenticated_execute
   OR pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE') IS DISTINCT FROM b.service_execute
   OR (p.oid NOT IN ('public.publish_my_specialist_v1(uuid,integer,uuid)'::regprocedure,
                     'public.specialist_disable_public_v1(text)'::regprocedure) AND p.proconfig IS DISTINCT FROM b.proconfig)
   OR (p.oid IN ('public.publish_my_specialist_v1(uuid,integer,uuid)'::regprocedure,
                'public.specialist_disable_public_v1(text)'::regprocedure) AND (
       NOT COALESCE('lock_timeout=2s'=ANY(p.proconfig),false) OR
       ARRAY(SELECT x FROM unnest(COALESCE(p.proconfig,ARRAY[]::text[])) x WHERE x NOT LIKE 'lock_timeout=%' ORDER BY x)
       IS DISTINCT FROM ARRAY(SELECT x FROM unnest(COALESCE(b.proconfig,ARRAY[]::text[])) x WHERE x NOT LIKE 'lock_timeout=%' ORDER BY x)))
 ) THEN RAISE EXCEPTION 'Function security drift'; END IF;
END $postcheck$;
COMMIT;
