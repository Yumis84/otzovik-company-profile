-- Candidate migration: REVIEW BEFORE APPLYING TO PRODUCTION
-- V1 reuses existing company editor and membership model, tagging the kind explicitly.
-- Specialist publication MUST be excluded by all public exporters until reviewed.
begin;
alter table public.companies
  add column if not exists profile_kind text not null default 'company';
alter table public.companies
  add constraint companies_profile_kind_check
  check (profile_kind in ('company','specialist'));
-- Existing check excludes draft: extend it explicitly for specialist drafts.
alter table public.companies drop constraint companies_profile_status_check;
alter table public.companies add constraint companies_profile_status_check
 check (profile_status in ('processing','ready','needs_review','suspended','draft'));
comment on column public.companies.profile_kind is
  'V1: company or specialist; specialist reuses editor, not verified professional credentials';

create or replace function public.create_my_profile(
 p_kind text, p_name text, p_slug text,
 p_website text default null, p_phone text default null,
 p_city text default null, p_email text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
 v_result jsonb;
 v_id uuid;
begin
 if p_kind not in ('company','specialist') or p_kind is null then
   raise exception using errcode='22023',message='Invalid profile kind';
 end if;
 if auth.uid() is null then raise exception using errcode='42501',message='Authentication required'; end if;
 -- Reuse existing validation, slug reservation, authenticated ownership and audit.
 v_result := public.create_my_company(p_name,p_slug,p_website,p_phone,p_city,p_email);
 v_id := (v_result #>> '{company,id}')::uuid;
 if p_kind='specialist' then
   -- No automatic public publication or claims of verified qualifications.
   if not exists(select 1 from public.company_memberships where company_id=v_id and user_id=auth.uid() and role='owner' and verification_status <> 'revoked') then
     raise exception using errcode='42501',message='Not profile owner';
   end if;
   update public.companies
     set profile_kind='specialist', profile_status='draft', status='inactive'
     where id=v_id;

 end if;
 v_result := jsonb_set(v_result,'{company,profile_kind}',to_jsonb(p_kind),true);
 if p_kind='specialist' then
   v_result := jsonb_set(v_result,'{company,profile_status}','"draft"'::jsonb,true);
   v_result := jsonb_set(v_result,'{company,status}','"inactive"'::jsonb,true);
 end if;
 return v_result;
end;
$$;
revoke all on function public.create_my_profile(text,text,text,text,text,text,text) from public,anon;
grant execute on function public.create_my_profile(text,text,text,text,text,text,text) to authenticated;

-- Preserve existing get_my_companies contract while adding profile_kind and
-- preventing revoked/suspended memberships from reading private profile data.
create or replace function public.get_my_companies() returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_user_id uuid := auth.uid();
begin
 if v_user_id is null then
   raise exception using errcode='42501',message='Authentication required';
 end if;
 return coalesce((
  select jsonb_agg(jsonb_build_object(
    'company',jsonb_build_object(
      'id',c.id,'slug',c.slug,
      'public_url','https://' || c.slug || '.xn--b1ajuq0c.com/',
      'name',c.name,'description',c.description,'city',c.city,
      'website',c.website,'phone',c.phone,'email',c.email,
      'status',c.status,'profile_status',c.profile_status,
      'profile_kind',c.profile_kind
    ),
    'membership',jsonb_build_object(
      'id',m.id,'role',m.role,'verification_status',m.verification_status
    )
  ) order by c.created_at desc)
  from public.company_memberships m
  join public.companies c on c.id=m.company_id
  where m.user_id=v_user_id and m.verification_status='verified'
 ),'[]'::jsonb);
end;
$$;
commit;
