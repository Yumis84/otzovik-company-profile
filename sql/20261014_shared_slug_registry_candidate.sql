-- REVIEW ONLY. Companion candidate to 20261014_specialist_drafts_candidate.sql.
-- Requires specialist_profiles table; do not apply in production without acceptance.
-- Shared namespace for company and specialist slugs, enforced atomically.
BEGIN;

CREATE TABLE IF NOT EXISTS public.public_profile_slug_reservations (
  slug text PRIMARY KEY,
  profile_kind text NOT NULL CHECK (profile_kind IN ('company','specialist')),
  profile_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (profile_kind, profile_id)
);
ALTER TABLE public.public_profile_slug_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.public_profile_slug_reservations FROM PUBLIC, anon, authenticated;

-- Backfill existing company names first. Any unexpected duplicate must fail the transaction.
INSERT INTO public.public_profile_slug_reservations(slug,profile_kind,profile_id)
SELECT c.slug,'company',c.id FROM public.companies c
ON CONFLICT (slug) DO NOTHING;

-- Fail closed if a preexisting reservation disagrees with company ownership.
DO $$
BEGIN
 IF EXISTS (
   SELECT 1 FROM public.companies c
   LEFT JOIN public.public_profile_slug_reservations r
     ON r.slug=c.slug AND r.profile_kind='company' AND r.profile_id=c.id
   WHERE r.slug IS NULL
 ) THEN
   RAISE EXCEPTION 'company slug reservation conflict';
 END IF;
END $$;

-- Backfill specialist drafts (if any), and reject collisions.
INSERT INTO public.public_profile_slug_reservations(slug,profile_kind,profile_id)
SELECT s.slug,'specialist',s.id FROM public.specialist_profiles s
ON CONFLICT (slug) DO NOTHING;

DO $$
BEGIN
 IF EXISTS (
   SELECT 1 FROM public.specialist_profiles s
   LEFT JOIN public.public_profile_slug_reservations r
     ON r.slug=s.slug AND r.profile_kind='specialist' AND r.profile_id=s.id
   WHERE r.slug IS NULL
 ) THEN
   RAISE EXCEPTION 'specialist slug reservation conflict';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.reserve_public_profile_slug()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_kind text := TG_ARGV[0];
BEGIN
  IF TG_OP='UPDATE' AND NEW.slug IS NOT DISTINCT FROM OLD.slug THEN
    RETURN NEW;
  END IF;
  -- Unique primary key serializes concurrent claims of the same slug.
  INSERT INTO public.public_profile_slug_reservations(slug,profile_kind,profile_id)
  VALUES (NEW.slug,v_kind,NEW.id);
  IF TG_OP='UPDATE' THEN
    DELETE FROM public.public_profile_slug_reservations
    WHERE slug=OLD.slug AND profile_kind=v_kind AND profile_id=OLD.id;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.release_public_profile_slug()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.public_profile_slug_reservations
  WHERE slug=OLD.slug AND profile_kind=TG_ARGV[0] AND profile_id=OLD.id;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS companies_reserve_public_slug ON public.companies;
CREATE TRIGGER companies_reserve_public_slug
BEFORE INSERT OR UPDATE OF slug ON public.companies
FOR EACH ROW EXECUTE FUNCTION public.reserve_public_profile_slug('company');

DROP TRIGGER IF EXISTS specialists_reserve_public_slug ON public.specialist_profiles;
CREATE TRIGGER specialists_reserve_public_slug
BEFORE INSERT OR UPDATE OF slug ON public.specialist_profiles
FOR EACH ROW EXECUTE FUNCTION public.reserve_public_profile_slug('specialist');

DROP TRIGGER IF EXISTS companies_release_public_slug ON public.companies;
CREATE TRIGGER companies_release_public_slug
AFTER DELETE ON public.companies
FOR EACH ROW EXECUTE FUNCTION public.release_public_profile_slug('company');

DROP TRIGGER IF EXISTS specialists_release_public_slug ON public.specialist_profiles;
CREATE TRIGGER specialists_release_public_slug
AFTER DELETE ON public.specialist_profiles
FOR EACH ROW EXECUTE FUNCTION public.release_public_profile_slug('specialist');

REVOKE ALL ON FUNCTION public.reserve_public_profile_slug() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_public_profile_slug() FROM PUBLIC, anon, authenticated;

-- Important: no public reads/writes on registry; company RPC slug suffix retry
-- must be regression-tested against unique_violation from this trigger.
COMMIT;
