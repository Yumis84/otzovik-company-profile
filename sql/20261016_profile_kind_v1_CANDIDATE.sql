-- Candidate migration: REVIEW BEFORE APPLYING TO PRODUCTION
-- V1 reuses existing company editor and membership model, tagging the kind explicitly.
-- Specialist publication MUST be excluded by all public exporters until reviewed.
begin;
alter table public.companies
  add column if not exists profile_kind text not null default 'company';
alter table public.companies
  add constraint companies_profile_kind_check
  check (profile_kind in ('company','specialist'));
comment on column public.companies.profile_kind is
  'V1: company or specialist; specialist reuses editor, not verified professional credentials';

create or replace function public.create_my_profile(
 p_kind text, p_name text, p_slug text,
 p_website text default null, p_phone text default null,
 p_city text default null, p_email text default null
) returns jsonb
language plpgsql security invoker set search_path = ''
as $$
declare
 v_result jsonb;
 v_id uuid;
begin
 if p_kind not in ('company','specialist') or p_kind is null then
   raise exception using errcode='22023',message='Invalid profile kind';
 end if;
 -- Reuse existing validation, slug reservation, authenticated ownership and audit.
 v_result := public.create_my_company(p_name,p_slug,p_website,p_phone,p_city,p_email);
 v_id := (v_result #>> '{company,id}')::uuid;
 if p_kind='specialist' then
   -- No automatic public publication or claims of verified qualifications.
   update public.companies
     set profile_kind='specialist', profile_status='draft'
     where id=v_id;
   update public.audit_log
     set metadata=coalesce(metadata,'{}'::jsonb) || '{"profile_kind":"specialist"}'::jsonb
     where company_id=v_id and action='company_created' and target_id=v_id::text;
 end if;
 return jsonb_set(v_result,'{company,profile_kind}',to_jsonb(p_kind),true);
end;
$$;
revoke all on function public.create_my_profile(text,text,text,text,text,text,text) from public,anon;
grant execute on function public.create_my_profile(text,text,text,text,text,text,text) to authenticated;
commit;
