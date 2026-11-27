BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='30s';
CREATE SCHEMA private;
REVOKE ALL ON SCHEMA private FROM PUBLIC,anon,authenticated;
CREATE TABLE public.company_profile_public_access (
 company_id uuid PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
 state text NOT NULL DEFAULT 'inactive' CHECK(state IN ('active','inactive','suspended')),
 review_intake_enabled boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.company_profile_public_access ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.company_profile_public_access FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.company_profile_public_access TO service_role;
CREATE FUNCTION private.is_company_publicly_readable_v1(p_company_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
SELECT EXISTS(SELECT 1 FROM public.companies c JOIN public.company_profile_public_access a ON a.company_id=c.id WHERE c.id=p_company_id AND c.status='active' AND c.profile_status='ready' AND a.state='active');
$$;
CREATE FUNCTION private.resolve_public_company_id_v1(p_slug text) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
WITH matches AS (SELECT c.id FROM public.companies c WHERE length(trim(p_slug)) BETWEEN 1 AND 80 AND trim(p_slug) ~ '^[A-Za-z0-9-]+$' AND lower(trim(c.slug))=lower(trim(p_slug)))
SELECT id FROM matches WHERE (SELECT count(*) FROM matches)=1 AND private.is_company_publicly_readable_v1(id);
$$;
REVOKE ALL ON FUNCTION private.is_company_publicly_readable_v1(uuid),private.resolve_public_company_id_v1(text) FROM PUBLIC,anon,authenticated;
COMMIT;
