-- ISOLATED REVIEW CANDIDATE ONLY. Never apply to hosted or production.
-- Specialist slug tombstones contain no user/profile identifier. The advisory
-- lock covers both deletion and claims by either profile type.
BEGIN;
CREATE TABLE public.specialist_slug_tombstones_v1 (
  slug text PRIMARY KEY,
  hold_until timestamptz NOT NULL
);
CREATE INDEX specialist_slug_tombstones_expiry_v1 ON public.specialist_slug_tombstones_v1(hold_until);
ALTER TABLE public.specialist_slug_tombstones_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_slug_tombstones_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_slug_tombstones_v1 FROM PUBLIC, anon, authenticated, service_role;
CREATE POLICY specialist_slug_tombstone_owner_v1 ON public.specialist_slug_tombstones_v1
  USING (current_user = pg_catalog.pg_get_userbyid((SELECT relowner FROM pg_catalog.pg_class WHERE oid = 'public.specialist_slug_tombstones_v1'::regclass)))
  WITH CHECK (current_user = pg_catalog.pg_get_userbyid((SELECT relowner FROM pg_catalog.pg_class WHERE oid = 'public.specialist_slug_tombstones_v1'::regclass)));

CREATE FUNCTION public.specialist_slug_quarantine_v1() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE old_slug text; new_slug text;
BEGIN
 IF TG_OP <> 'INSERT' THEN old_slug := OLD.slug; END IF;
 IF TG_OP <> 'DELETE' THEN new_slug := NEW.slug; END IF;
 -- Lock both names in lexical order on a rename to avoid opposite-order deadlocks.
 IF old_slug IS NOT NULL AND new_slug IS NOT NULL AND old_slug <> new_slug THEN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('otzovik-slug:' || least(old_slug,new_slug),0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('otzovik-slug:' || greatest(old_slug,new_slug),0));
 ELSE
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('otzovik-slug:' || coalesce(old_slug,new_slug),0));
 END IF;
 IF new_slug IS NOT NULL AND (TG_OP = 'INSERT' OR new_slug IS DISTINCT FROM old_slug) THEN
  DELETE FROM public.specialist_slug_tombstones_v1 WHERE slug=new_slug AND hold_until<=pg_catalog.clock_timestamp();
  IF EXISTS(SELECT 1 FROM public.specialist_slug_tombstones_v1 WHERE slug=new_slug) THEN
   RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='Slug unavailable';
  END IF;
 END IF;
 IF TG_ARGV[0]='specialist' AND old_slug IS NOT NULL AND (TG_OP='DELETE' OR old_slug IS DISTINCT FROM new_slug) THEN
  INSERT INTO public.specialist_slug_tombstones_v1(slug,hold_until)
  VALUES(old_slug,pg_catalog.clock_timestamp()+interval '90 days')
  ON CONFLICT(slug) DO UPDATE SET hold_until=greatest(public.specialist_slug_tombstones_v1.hold_until,EXCLUDED.hold_until);
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END
$fn$;
REVOKE ALL ON FUNCTION public.specialist_slug_quarantine_v1() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER specialist_quarantine_claim_v1 BEFORE INSERT OR UPDATE OF slug OR DELETE ON public.specialist_profiles
 FOR EACH ROW EXECUTE FUNCTION public.specialist_slug_quarantine_v1('specialist');
CREATE TRIGGER company_quarantine_claim_v1 BEFORE INSERT OR UPDATE OF slug ON public.companies
 FOR EACH ROW EXECUTE FUNCTION public.specialist_slug_quarantine_v1('company');
-- No schedule or execution grant is installed by this candidate. Scheduling
-- requires an independently reviewed operator identity and deployment plan.
CREATE FUNCTION public.specialist_slug_quarantine_purge_v1() RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE removed bigint;
BEGIN
 DELETE FROM public.specialist_slug_tombstones_v1 WHERE hold_until<=pg_catalog.clock_timestamp();
 GET DIAGNOSTICS removed = ROW_COUNT;
 RETURN removed;
END
$fn$;
REVOKE ALL ON FUNCTION public.specialist_slug_quarantine_purge_v1() FROM PUBLIC, anon, authenticated, service_role;
COMMIT;
