CREATE OR REPLACE FUNCTION public.get_my_companies()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
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
  ), '[]'::jsonb);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_my_company(p_name text, p_slug text, p_website text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_email text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
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
  if v_base_slug !~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$' then
    raise exception using errcode='22023', message='Invalid company slug';
  end if;
  if v_base_slug in ('www','api','admin','test','test2') then
    raise exception using errcode='22023', message='Reserved company slug';
  end if;

  if v_website is not null then
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
    v_slug := case when v_suffix=0 then v_base_slug else v_base_slug||'-'||(v_suffix+1)::text end;
    if char_length(v_slug)>64 then
      raise exception using errcode='22023', message='No available company slug';
    end if;
    begin
      insert into public.companies(slug,name,website,phone,city,email,status,profile_status)
      values(v_slug,v_name,v_website,v_phone,v_city,v_email,'active','ready')
      returning id into v_company_id;
      exit;
    exception when unique_violation then
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
