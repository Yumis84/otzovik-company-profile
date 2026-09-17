-- MIGRATION DRAFT ONLY: do not apply automatically.
-- Review and execute through the approved Supabase migration gate.
-- Uses the existing public.companies_slug_key UNIQUE constraint/index.

begin;

create or replace function public.create_my_company(
  p_name text,
  p_slug text,
  p_website text default null,
  p_phone text default null,
  p_city text default null,
  p_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_membership_id uuid;
  v_name text := btrim(coalesce(p_name, ''));
  v_base_slug text := lower(btrim(coalesce(p_slug, '')));
  v_slug text;
  v_suffix integer := 0;
  v_website text := nullif(btrim(coalesce(p_website, '')), '');
  v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
  v_city text := nullif(btrim(coalesce(p_city, '')), '');
  v_email text := nullif(lower(btrim(coalesce(p_email, ''))), '');
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if v_name = '' or char_length(v_name) > 200 then
    raise exception using errcode = '22023', message = 'Company name must contain 1-200 characters';
  end if;
  if v_base_slug !~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$' then
    raise exception using errcode = '22023', message = 'Invalid company slug';
  end if;
  if v_base_slug in ('www', 'api', 'admin', 'test', 'test2') then
    raise exception using errcode = '22023', message = 'Reserved company slug';
  end if;

  -- The insert and UNIQUE violation retry are inside one database function call.
  loop
    v_slug := case when v_suffix = 0 then v_base_slug else v_base_slug || '-' || (v_suffix + 1)::text end;
    if char_length(v_slug) > 63 then
      raise exception using errcode = '22023', message = 'No available company slug';
    end if;
    begin
      insert into public.companies(slug, name, website, phone, city, email, status, profile_status)
      values (v_slug, v_name, v_website, v_phone, v_city, v_email, 'active', 'ready')
      returning id into v_company_id;
      exit;
    exception when unique_violation then
      v_suffix := v_suffix + 1;
    end;
  end loop;

  insert into public.company_memberships(company_id, user_id, role, verification_status, verification_method, verified_at)
  values (v_company_id, v_user_id, 'owner', 'verified', 'creator', now())
  returning id into v_membership_id;

  insert into public.audit_log(company_id, user_id, action, target_type, target_id, metadata)
  values (v_company_id, v_user_id, 'company_created', 'company', v_company_id::text,
          jsonb_build_object('slug', v_slug, 'role', 'owner', 'verification_method', 'creator'));

  return jsonb_build_object(
    'company', jsonb_build_object(
      'id', v_company_id,
      'slug', v_slug,
      'public_url', 'https://' || v_slug || '.xn--b1ajuq0c.com/',
      'name', v_name,
      'website', v_website,
      'phone', v_phone,
      'city', v_city,
      'email', v_email,
      'status', 'active',
      'profile_status', 'ready'
    ),
    'membership', jsonb_build_object(
      'id', v_membership_id,
      'role', 'owner',
      'verification_status', 'verified'
    )
  );
end;
$$;

create or replace function public.get_my_companies()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
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
  ), '[]'::jsonb);
end;
$$;

-- Keep these SECURITY DEFINER RPCs behind the authenticated API boundary.
revoke all on function public.create_my_company(text, text, text, text, text, text)
  from public, anon;
grant execute on function public.create_my_company(text, text, text, text, text, text)
  to authenticated;

revoke all on function public.get_my_companies() from public, anon;
grant execute on function public.get_my_companies() to authenticated;

commit;
