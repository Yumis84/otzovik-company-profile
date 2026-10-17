-- OTZOVIK Specialist V1, candidate migration. REVIEW ONLY: DO NOT APPLY TO PRODUCTION.
-- Independent private drafts + shared address uniqueness. Apply atomically with edit candidate.
-- Existing company creation contract retained; targeted validation/read fixes below.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
DO $owner$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'Migration requires a trusted BYPASSRLS owner for the narrow SECURITY DEFINER RPCs';
  END IF;
END
$owner$;

CREATE TABLE public.specialist_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  slug text NOT NULL UNIQUE,
  display_name text NOT NULL,
  profession text NOT NULL CHECK (char_length(btrim(profession)) BETWEEN 1 AND 120),
  specialization text CHECK (char_length(specialization) <= 160),
  city text CHECK (char_length(city) <= 120),
  description text CHECK (char_length(description) <= 2000),
  profile_status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT specialist_profiles_slug_format CHECK (
    slug ~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$'
    AND slug !~ '^xn--'
    AND slug NOT IN ('www','api','admin','test','test2','account','login','profiles','specialists')
  ),
  CONSTRAINT specialist_profiles_name_length CHECK (char_length(btrim(display_name)) BETWEEN 2 AND 150),
  CONSTRAINT specialist_profiles_status_check CHECK (profile_status = 'draft')
);

CREATE INDEX specialist_profiles_owner_idx ON public.specialist_profiles(owner_user_id);
ALTER TABLE public.specialist_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_profiles FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_profiles FROM PUBLIC, anon, authenticated;


-- The unique index, not a SELECT-before-INSERT check, arbitrates concurrent writes.
-- AFTER triggers also work with INSERT ... ON CONFLICT DO NOTHING: no orphan claim.
-- Lock both source tables during backfill + trigger installation (short transaction).
LOCK TABLE public.companies, public.specialist_profiles IN SHARE ROW EXCLUSIVE MODE;
CREATE TABLE public.profile_slug_registry (
  slug text PRIMARY KEY CHECK (slug = lower(btrim(slug))),
  profile_kind text NOT NULL CHECK (profile_kind IN ('company','specialist')),
  profile_id uuid NOT NULL
);
ALTER TABLE public.profile_slug_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_slug_registry FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_slug_registry FROM PUBLIC, anon, authenticated;
-- Fails closed on existing case-insensitive collisions; never silently drops a claim.
INSERT INTO public.profile_slug_registry(slug,profile_kind,profile_id)
SELECT lower(btrim(slug)), 'company', id FROM public.companies;

CREATE FUNCTION public.sync_profile_slug_registry() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $registry$
DECLARE v_kind text := TG_ARGV[0];
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.slug IS NOT DISTINCT FROM OLD.slug THEN
    RETURN NEW;
  END IF;
  IF TG_OP <> 'DELETE' THEN
    IF NEW.slug <> lower(btrim(NEW.slug))
       OR NEW.slug !~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$'
       OR NEW.slug IN ('www','api','admin','test','test2','account','login','profiles','specialists') THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid or reserved slug';
    END IF;
    INSERT INTO public.profile_slug_registry(slug,profile_kind,profile_id)
    VALUES (NEW.slug,v_kind,NEW.id);
  END IF;
  IF TG_OP <> 'INSERT' THEN
    DELETE FROM public.profile_slug_registry
    WHERE slug=lower(btrim(OLD.slug)) AND profile_kind=v_kind AND profile_id=OLD.id;
  END IF;
  RETURN NULL; -- AFTER trigger return value is ignored
END
$registry$;
REVOKE ALL ON FUNCTION public.sync_profile_slug_registry() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER profile_slug_registry_company
AFTER INSERT OR UPDATE OF slug OR DELETE ON public.companies
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_slug_registry('company');
CREATE TRIGGER profile_slug_registry_specialist
AFTER INSERT OR UPDATE OF slug OR DELETE ON public.specialist_profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_slug_registry('specialist');

-- No direct table writes by clients. All draft creation goes through this narrow RPC.
CREATE OR REPLACE FUNCTION public.create_my_specialist_draft(
  p_display_name text,
  p_slug text,
  p_profession text DEFAULT NULL,
  p_specialization text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_description text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_name text := btrim(coalesce(p_display_name,''));
  v_slug text := lower(btrim(coalesce(p_slug,'')));
  v_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Authentication required';
  END IF;
  IF char_length(v_name) NOT BETWEEN 2 AND 150 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid specialist name';
  END IF;
  IF char_length(btrim(coalesce(p_profession,''))) NOT BETWEEN 1 AND 120 OR char_length(coalesce(p_specialization,'')) > 160 OR char_length(coalesce(p_city,'')) > 120 OR char_length(coalesce(p_description,'')) > 2000 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Specialist field too long';
  END IF;
  IF v_slug !~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$'
     OR v_slug ~ '^xn--'
     OR v_slug IN ('www','api','admin','test','test2','account','login','profiles','specialists')
  THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid or reserved slug';
  END IF;
  INSERT INTO public.specialist_profiles(owner_user_id,slug,display_name,profession,specialization,city,description)
  VALUES (v_user_id,v_slug,v_name,
          nullif(btrim(coalesce(p_profession,'')),''),
          nullif(btrim(coalesce(p_specialization,'')),''),
          nullif(btrim(coalesce(p_city,'')),''),nullif(btrim(coalesce(p_description,'')),''))
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('id',v_id,'slug',v_slug,'profile_status','draft');
END
$function$;

CREATE OR REPLACE FUNCTION public.get_my_specialists()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Authentication required';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'id',s.id,'slug',s.slug,'display_name',s.display_name,
      'profession',s.profession,'specialization',s.specialization,
      'city',s.city,'description',s.description,'profile_status',s.profile_status
    ) ORDER BY s.created_at DESC)
    FROM public.specialist_profiles s WHERE s.owner_user_id = v_user_id
  ),'[]'::jsonb);
END
$function$;

REVOKE ALL ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_specialists() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_specialists() TO authenticated;

-- Deliberately no public SELECT, publish RPC, specialist reviews or credentials yet.
-- Publication and consent require separately reviewed migration and acceptance tests.

-- Preserve existing company deduplication, membership and audit behavior.
CREATE OR REPLACE FUNCTION public.get_my_companies()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'company', jsonb_build_object(
        'id', c.id, 'slug', c.slug,
        'public_url', 'https://' || c.slug || '.xn--b1ajuq0c.com/',
        'name', c.name, 'description', c.description, 'city', c.city,
        'website', c.website, 'phone', c.phone, 'email', c.email,
        'status', c.status, 'profile_status', c.profile_status
      ),
      'membership', jsonb_build_object(
        'id', m.id, 'role', m.role, 'verification_status', m.verification_status
      )
    ) order by c.created_at desc)
    from public.company_memberships m
    join public.companies c on c.id = m.company_id
    where m.user_id = v_user_id
      and m.verification_status = 'verified'
  ), '[]'::jsonb);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_my_company(p_name text, p_slug text, p_website text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_email text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_membership_id uuid;
  v_existing_id uuid;
  v_existing_slug text;
  v_name text := btrim(coalesce(p_name,''));
  v_base_slug text := lower(btrim(coalesce(p_slug,'')));
  v_slug text;
  v_suffix integer := 0;
  v_website text := nullif(btrim(coalesce(p_website,'')),'');
  v_website_host text;
  v_default_website boolean;
  v_constraint text;
  v_phone text := nullif(btrim(coalesce(p_phone,'')),'');
  v_city text := nullif(btrim(coalesce(p_city,'')),'');
  v_email text := nullif(lower(btrim(coalesce(p_email,''))),'');
begin
  if v_user_id is null then
    raise exception using errcode='42501', message='Authentication required';
  end if;
  if v_name='' or char_length(v_name)>200 then
    raise exception using errcode='22023', message='Company name must contain 1-200 characters';
  end if;
  if v_base_slug !~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$' then
    raise exception using errcode='22023', message='Invalid company slug';
  end if;
  if v_base_slug in ('www','api','admin','test','test2','account','login','profiles','specialists') then
    raise exception using errcode='22023', message='Reserved company slug';
  end if;

  v_default_website := v_website IS NULL OR v_website IN (
    'https://' || v_base_slug || '.xn--b1ajuq0c.com/',
    'https://' || v_base_slug || '.отзыв.com/');
  if NOT v_default_website then
    v_website_host := lower(regexp_replace(regexp_replace(v_website,'^https?://','','i'),'/.*$',''));
    v_website_host := regexp_replace(v_website_host,'^www\.','','i');
  end if;

  select c.id,c.slug into v_existing_id,v_existing_slug
  from public.companies c
  where c.status <> 'archived'
    and (
      (v_website_host is not null and
       regexp_replace(lower(regexp_replace(regexp_replace(coalesce(c.website,''),'^https?://','','i'),'/.*$','')),'^www\.','','i') = v_website_host)
      or
      (lower(btrim(c.name))=lower(v_name)
       and lower(btrim(coalesce(c.city,'')))=lower(btrim(coalesce(v_city,'')))
       and coalesce(v_city,'')<>'')
    )
  order by c.created_at
  limit 1;

  if v_existing_id is not null then
    if exists(select 1 from public.company_memberships m where m.company_id=v_existing_id and m.user_id=v_user_id and m.verification_status<>'revoked') then
      raise exception using errcode='23505', message='Company already exists in your account';
    end if;
    raise exception using errcode='23505', message='Company already exists';
  end if;

  loop
    v_slug := case when v_suffix=0 then v_base_slug else rtrim(left(v_base_slug, 63 - 1 - char_length((v_suffix+1)::text)), '-')||'-'||(v_suffix+1)::text end;
    if char_length(v_slug)>63 OR v_suffix > 100 then
      raise exception using errcode='22023', message='No available company slug';
    end if;
    IF v_default_website THEN
      v_website := 'https://' || v_slug || '.xn--b1ajuq0c.com/';
    END IF;
    begin
      insert into public.companies(slug,name,website,phone,city,email,status,profile_status)
      values(v_slug,v_name,v_website,v_phone,v_city,v_email,'active','ready')
      returning id into v_company_id;
      exit;
    exception when unique_violation then
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      IF v_constraint NOT IN ('companies_slug_key','profile_slug_registry_pkey') THEN RAISE; END IF;
      v_suffix:=v_suffix+1;
    end;
  end loop;

  insert into public.company_memberships(company_id,user_id,role,verification_status,verification_method,verified_at)
  values(v_company_id,v_user_id,'owner','verified','creator',now())
  returning id into v_membership_id;

  insert into public.audit_log(company_id,user_id,action,target_type,target_id,metadata)
  values(v_company_id,v_user_id,'company_created','company',v_company_id::text,
    jsonb_build_object('slug',v_slug,'role','owner','verification_method','creator'));

  return jsonb_build_object(
    'company',jsonb_build_object('id',v_company_id,'slug',v_slug,'public_url','https://'||v_slug||'.xn--b1ajuq0c.com/','name',v_name,'website',v_website,'phone',v_phone,'city',v_city,'email',v_email,'status','active','profile_status','ready'),
    'membership',jsonb_build_object('id',v_membership_id,'role','owner','verification_status','verified')
  );
end;
$function$
;

REVOKE ALL ON FUNCTION public.create_my_company(text,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_my_company(text,text,text,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_companies() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_companies() TO authenticated;
COMMIT;
