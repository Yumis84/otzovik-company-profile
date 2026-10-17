-- Schema-only read-only snapshot, 2026-10-16. No production rows or secrets.
CREATE SCHEMA auth;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
GRANT USAGE ON SCHEMA auth,public TO anon,authenticated,service_role;
CREATE TABLE public.companies (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  slug text NOT NULL,
  name text NOT NULL,
  legal_name text,
  website text,
  phone text,
  email text,
  status text DEFAULT 'active'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  city text,
  profile_status text DEFAULT 'ready'::text NOT NULL,
  description text
);
ALTER TABLE public.companies ADD CONSTRAINT companies_pkey PRIMARY KEY (id);
ALTER TABLE public.companies ADD CONSTRAINT companies_profile_status_check CHECK ((profile_status = ANY (ARRAY['processing'::text, 'ready'::text, 'needs_review'::text, 'suspended'::text])));
ALTER TABLE public.companies ADD CONSTRAINT companies_slug_key UNIQUE (slug);
ALTER TABLE public.companies ADD CONSTRAINT companies_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'archived'::text])));
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
CREATE TABLE public.company_memberships (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  company_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL,
  verification_status text DEFAULT 'pending'::text NOT NULL,
  verification_method text,
  verified_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.company_memberships ADD CONSTRAINT company_memberships_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE public.company_memberships ADD CONSTRAINT company_memberships_company_id_user_id_key UNIQUE (company_id, user_id);
ALTER TABLE public.company_memberships ADD CONSTRAINT company_memberships_pkey PRIMARY KEY (id);
ALTER TABLE public.company_memberships ADD CONSTRAINT company_memberships_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text, 'analyst'::text])));
ALTER TABLE public.company_memberships ADD CONSTRAINT company_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.company_memberships ADD CONSTRAINT company_memberships_verification_status_check CHECK ((verification_status = ANY (ARRAY['pending'::text, 'verified'::text, 'suspended'::text, 'revoked'::text])));
ALTER TABLE public.company_memberships ENABLE ROW LEVEL SECURITY;
CREATE TABLE public.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  company_id uuid,
  user_id uuid,
  action text NOT NULL,
  target_type text,
  target_id text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.companies,public.company_memberships TO authenticated;
-- Publication sentinel stands in for external publishing; no real network calls.
CREATE TABLE public.test_publish_events(company_id uuid);
CREATE FUNCTION public.request_company_profile_publish() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN INSERT INTO public.test_publish_events VALUES(NEW.id); RETURN NEW; END $$;
CREATE TRIGGER profile_publish_companies AFTER UPDATE OF name, description, website, phone, city, status, profile_status ON public.companies FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION request_company_profile_publish();

