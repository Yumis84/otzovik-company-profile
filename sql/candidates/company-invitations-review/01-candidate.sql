-- REVIEW CANDIDATE ONLY. Restores the existing company invitation module on staging.
-- Caller must verify project salmcnhexlftrgtiryyo. This candidate is not installed.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
CREATE TABLE public.company_access_invitations (
 id uuid DEFAULT gen_random_uuid() NOT NULL,
 company_id uuid NOT NULL,
 email text NOT NULL,
 role text NOT NULL,
 invited_by uuid NOT NULL,
 token_hash text NOT NULL,
 status text DEFAULT 'pending'::text NOT NULL,
 expires_at timestamp with time zone DEFAULT (now() + '7 days'::interval) NOT NULL,
 accepted_by uuid,
 accepted_at timestamp with time zone,
 created_at timestamp with time zone DEFAULT now() NOT NULL,
 updated_at timestamp with time zone DEFAULT now() NOT NULL,
 CONSTRAINT company_access_invitations_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES auth.users(id) ON DELETE SET NULL,
 CONSTRAINT company_access_invitations_company_id_fkey FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
 CONSTRAINT company_access_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id) ON DELETE CASCADE,
 CONSTRAINT company_access_invitations_pkey PRIMARY KEY (id),
 CONSTRAINT company_access_invitations_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'manager'::text, 'analyst'::text]))),
 CONSTRAINT company_access_invitations_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'expired'::text, 'revoked'::text]))),
 CONSTRAINT company_access_invitations_token_hash_key UNIQUE (token_hash)
);
ALTER TABLE public.company_access_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.company_access_invitations FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.company_access_invitations TO service_role;
CREATE UNIQUE INDEX company_access_invitations_pending_email_idx ON public.company_access_invitations(company_id,lower(email)) WHERE status='pending';

CREATE OR REPLACE FUNCTION public.accept_company_access_invitation(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_hash text;
  v_inv public.company_access_invitations%rowtype;
  v_existing_role text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_token is null or char_length(p_token) < 32 then raise exception 'Invalid invitation token'; end if;

  select lower(email) into v_email from auth.users where id=v_uid;
  if v_email is null then raise exception 'Authenticated email required'; end if;

  v_hash := encode(extensions.digest(p_token, 'sha256'), 'hex');
  select * into v_inv from public.company_access_invitations
   where token_hash=v_hash and status='pending'
   for update;
  if not found then raise exception 'Invitation not found or no longer pending'; end if;

  if v_inv.expires_at <= now() then
    update public.company_access_invitations
       set status='expired', updated_at=now()
     where id=v_inv.id;
    return jsonb_build_object('status','expired');
  end if;

  if lower(v_inv.email) <> v_email then raise exception 'Invitation email does not match authenticated user'; end if;

  select role into v_existing_role
    from public.company_memberships
   where company_id=v_inv.company_id and user_id=v_uid;

  if v_existing_role is not null then
    if v_existing_role='owner' then raise exception 'Company owner cannot accept delegated invitation'; end if;
    raise exception 'User already has access to this company';
  end if;

  insert into public.company_memberships(company_id,user_id,role,verification_status,verification_method,verified_at)
  values(v_inv.company_id,v_uid,v_inv.role,'verified','email_invitation',now());

  update public.company_access_invitations
     set status='accepted', accepted_by=v_uid, accepted_at=now(), updated_at=now()
   where id=v_inv.id;

  return jsonb_build_object('company_id',v_inv.company_id,'role',v_inv.role,'status','accepted');
end $function$;
REVOKE ALL ON FUNCTION public.accept_company_access_invitation(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.accept_company_access_invitation(text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.accept_my_company_invitation(p_invitation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_email text; v_inv public.company_access_invitations%rowtype;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select lower(email) into v_email from auth.users where id=v_uid;
 if v_email is null or btrim(v_email)='' then raise exception using errcode='42501',message='Authenticated email required'; end if;
 select * into v_inv from public.company_access_invitations where id=p_invitation_id and status='pending' for update;
 if not found then raise exception 'Invitation not found or no longer pending'; end if;
 if lower(v_inv.email) IS DISTINCT FROM v_email then raise exception 'Invitation email does not match authenticated user'; end if;
 if v_inv.expires_at<=now() then update public.company_access_invitations set status='expired',updated_at=now() where id=v_inv.id; return jsonb_build_object('status','expired'); end if;
 if exists(select 1 from public.company_memberships where company_id=v_inv.company_id and user_id=v_uid) then raise exception 'User already has access to this company'; end if;
 insert into public.company_memberships(company_id,user_id,role,verification_status,verification_method,verified_at) values(v_inv.company_id,v_uid,v_inv.role,'verified','account_invitation',now());
 update public.company_access_invitations set status='accepted',accepted_by=v_uid,accepted_at=now(),updated_at=now() where id=v_inv.id;
 return jsonb_build_object('status','accepted','company_id',v_inv.company_id,'role',v_inv.role);
end $function$;
REVOKE ALL ON FUNCTION public.accept_my_company_invitation(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.accept_my_company_invitation(uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.decline_my_company_invitation(p_invitation_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_email text;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select lower(email) into v_email from auth.users where id=v_uid;
 update public.company_access_invitations set status='revoked',updated_at=now()
 where id=p_invitation_id and status='pending' and lower(email)=v_email;
 return found;
end $function$;
REVOKE ALL ON FUNCTION public.decline_my_company_invitation(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.decline_my_company_invitation(uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.get_my_company_access(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception using errcode='42501',message='Authentication required'; end if;
 if not exists(select 1 from public.company_memberships where company_id=p_company_id and user_id=v_uid and role='owner' and verification_status='verified')
 then raise exception using errcode='42501',message='Verified owner required'; end if;
 return jsonb_build_object(
  'members',coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,'role',m.role,'verification_status',m.verification_status) order by m.created_at)
    from public.company_memberships m where m.company_id=p_company_id),'[]'::jsonb),
  'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'role',i.role,'status',i.status,'expires_at',i.expires_at,'created_at',i.created_at) order by i.created_at desc)
    from public.company_access_invitations i where i.company_id=p_company_id and i.status='pending'),'[]'::jsonb)
 );
end $function$;
REVOKE ALL ON FUNCTION public.get_my_company_access(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_company_access(uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.get_my_pending_company_invitations()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_email text;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select lower(email) into v_email from auth.users where id=v_uid;
 update public.company_access_invitations set status='expired',updated_at=now() where status='pending' and expires_at<=now() and lower(email)=v_email;
 return coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'company_id',i.company_id,'company_name',c.name,'company_slug',c.slug,'role',i.role,'created_at',i.created_at,'expires_at',i.expires_at) order by i.created_at desc)
 from public.company_access_invitations i join public.companies c on c.id=i.company_id
 where i.status='pending' and lower(i.email)=v_email),'[]'::jsonb);
end $function$;
REVOKE ALL ON FUNCTION public.get_my_pending_company_invitations() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_pending_company_invitations() TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.revoke_company_access_invitation(p_invitation_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_company uuid;
begin
 if v_uid is null then raise exception using errcode='42501',message='Authentication required'; end if;
 select company_id into v_company from public.company_access_invitations where id=p_invitation_id and status='pending';
 if v_company is null then return false; end if;
 if not exists(select 1 from public.company_memberships where company_id=v_company and user_id=v_uid and role='owner' and verification_status='verified')
 then raise exception using errcode='42501',message='Verified owner required'; end if;
 update public.company_access_invitations set status='revoked',updated_at=now() where id=p_invitation_id and status='pending';
 return found;
end $function$;
REVOKE ALL ON FUNCTION public.revoke_company_access_invitation(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.revoke_company_access_invitation(uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.owner_invite_existing_company_user(p_company_id uuid, p_email text, p_role text DEFAULT 'manager'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_owner uuid:=auth.uid(); v_target uuid; v_email text:=lower(btrim(p_email)); v_token text; v_hash text; v_inv uuid;
begin
 if v_owner is null then raise exception 'Authentication required'; end if;
 if p_role not in ('admin','manager','analyst') then raise exception 'Invalid role'; end if;
 if not exists(select 1 from public.company_memberships where company_id=p_company_id and user_id=v_owner and role='owner' and verification_status='verified') then raise exception 'Owner required'; end if;
 select id into v_target from auth.users where lower(email)=v_email limit 1;
 if v_target is null then return jsonb_build_object('existing_user',false); end if;
 if v_target=v_owner then raise exception 'Cannot invite yourself'; end if;
 if exists(select 1 from public.company_memberships where company_id=p_company_id and user_id=v_target) then raise exception 'User already has access to this company'; end if;
 update public.company_access_invitations set status='revoked',updated_at=now() where company_id=p_company_id and lower(email)=v_email and status='pending';
 v_token:=gen_random_uuid()::text||replace(gen_random_uuid()::text,'-','');
 v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
 insert into public.company_access_invitations(company_id,email,role,invited_by,token_hash)
 values(p_company_id,v_email,p_role,v_owner,v_hash) returning id into v_inv;
 return jsonb_build_object('existing_user',true,'invitation_id',v_inv,'token',v_token);
end $function$;
REVOKE ALL ON FUNCTION public.owner_invite_existing_company_user(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.owner_invite_existing_company_user(uuid,text,text) TO authenticated,service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
