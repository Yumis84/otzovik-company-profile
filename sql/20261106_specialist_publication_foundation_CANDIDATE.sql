-- C1/C2 only. ISOLATED REVIEW CANDIDATE: never apply to hosted or production.
-- No public getter, publish operation, erasure barrier or activation is included.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

ALTER TABLE public.specialist_profiles ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK (version > 0);
CREATE FUNCTION public.specialist_public_fields_version_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $fn$
BEGIN
  IF ROW(NEW.display_name, NEW.profession, NEW.specialization, NEW.city, NEW.description)
     IS DISTINCT FROM ROW(OLD.display_name, OLD.profession, OLD.specialization, OLD.city, OLD.description) THEN
    NEW.version := OLD.version + 1;
  ELSE
    NEW.version := OLD.version;
  END IF;
  RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public.specialist_public_fields_version_v1() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER specialist_public_fields_version_v1 BEFORE UPDATE ON public.specialist_profiles
FOR EACH ROW EXECUTE FUNCTION public.specialist_public_fields_version_v1();

CREATE TABLE public.specialist_reserved_slugs_v1 (
  slug text PRIMARY KEY CHECK (slug ~ '^[a-z0-9][a-z0-9-]*[a-z0-9]$'),
  policy_version integer NOT NULL CHECK (policy_version > 0)
);
ALTER TABLE public.specialist_reserved_slugs_v1 ENABLE ROW LEVEL SECURITY;
-- The SECURITY DEFINER trigger must still see this table when its owner is
-- subject to FORCE RLS. Table privileges remain revoked from application roles.
CREATE POLICY specialist_reserved_slugs_owner_read ON public.specialist_reserved_slugs_v1
  FOR SELECT USING (current_user = pg_catalog.pg_get_userbyid(
    (SELECT relowner FROM pg_catalog.pg_class WHERE oid = 'public.specialist_reserved_slugs_v1'::regclass)));
REVOKE ALL ON public.specialist_reserved_slugs_v1 FROM PUBLIC, anon, authenticated, service_role;
INSERT INTO public.specialist_reserved_slugs_v1(slug, policy_version)
SELECT slug, 1 FROM unnest(ARRAY['www','api','admin','test','test2','account','login','profiles','specialists',
 'mail','smtp','imap','pop','ftp','ns1','ns2','mx','autodiscover','autoconfig','webmail','cpanel',
 'static','cdn','assets','status','support','help','blog','app','dev','staging','vpn','n8n',
 'supabase','auth','oauth','sso','pay','payments','billing','dashboard','cabinet','kabinet','moy',
 'root','administrator','security','abuse','postmaster','hostmaster','dmarc','otzovik','otzyv']) AS slug;
ALTER TABLE public.specialist_reserved_slugs_v1 FORCE ROW LEVEL SECURITY;

CREATE FUNCTION public.specialist_slug_policy_v1() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
BEGIN
  IF position('--' IN NEW.slug) > 0 OR EXISTS
    (SELECT 1 FROM public.specialist_reserved_slugs_v1 r WHERE r.slug = NEW.slug) THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid or reserved specialist slug';
  END IF;
  RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public.specialist_slug_policy_v1() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER specialist_slug_policy_v1 BEFORE INSERT OR UPDATE OF slug ON public.specialist_profiles
FOR EACH ROW EXECUTE FUNCTION public.specialist_slug_policy_v1();

CREATE TABLE public.specialist_public_revisions (
  specialist_id uuid NOT NULL REFERENCES public.specialist_profiles(id) ON DELETE CASCADE,
  revision_id uuid NOT NULL DEFAULT gen_random_uuid(),
  client_request_id uuid NOT NULL,
  source_version integer NOT NULL CHECK (source_version > 0),
  slug text NOT NULL,
  display_name text NOT NULL,
  profession text NOT NULL,
  specialization text,
  city text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (specialist_id, revision_id),
  UNIQUE (specialist_id, client_request_id)
);
CREATE TABLE public.specialist_publication_state (
  specialist_id uuid PRIMARY KEY REFERENCES public.specialist_profiles(id) ON DELETE CASCADE,
  state text NOT NULL DEFAULT 'unpublished' CHECK (state IN ('unpublished','published','suspended','erasing')),
  published_revision_id uuid,
  CHECK ((state = 'published') = (published_revision_id IS NOT NULL)),
  FOREIGN KEY (specialist_id, published_revision_id)
    REFERENCES public.specialist_public_revisions(specialist_id, revision_id) DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE public.specialist_public_control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  enabled boolean NOT NULL DEFAULT false
);
INSERT INTO public.specialist_public_control(singleton,enabled) VALUES (true,false);
ALTER TABLE public.specialist_public_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_public_revisions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_publication_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_publication_state FORCE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_public_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_public_control FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_public_revisions, public.specialist_publication_state,
  public.specialist_public_control FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.specialist_revision_immutable_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $fn$
BEGIN
  RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Published revision cannot be updated';
END
$fn$;
REVOKE ALL ON FUNCTION public.specialist_revision_immutable_v1() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER specialist_revision_immutable_v1 BEFORE UPDATE ON public.specialist_public_revisions
FOR EACH ROW EXECUTE FUNCTION public.specialist_revision_immutable_v1();
COMMIT;
