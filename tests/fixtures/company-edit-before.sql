CREATE OR REPLACE FUNCTION public.update_my_company_profile(p_company_id uuid, p_name text, p_description text DEFAULT NULL::text, p_website text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_email text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_user_id uuid := auth.uid(); v_role text; v_old jsonb; v_new jsonb;
begin
 if v_user_id is null then raise exception 'authentication_required' using errcode='42501'; end if;
 if nullif(trim(coalesce(p_name,'')),'') is null then raise exception 'name_required' using errcode='22023'; end if;
 if char_length(trim(p_name))>200 then raise exception 'name_too_long' using errcode='22023'; end if;
 if char_length(coalesce(p_description,''))>2000 then raise exception 'description_too_long' using errcode='22023'; end if;
 if char_length(coalesce(p_website,''))>500 then raise exception 'website_too_long' using errcode='22023'; end if;
 if char_length(coalesce(p_phone,''))>100 then raise exception 'phone_too_long' using errcode='22023'; end if;
 if char_length(coalesce(p_city,''))>120 then raise exception 'city_too_long' using errcode='22023'; end if;
 if char_length(coalesce(p_email,''))>320 then raise exception 'email_too_long' using errcode='22023'; end if;
 select cm.role into v_role from public.company_memberships cm join public.companies c on c.id=cm.company_id and c.status='active'
 where cm.user_id=v_user_id and cm.company_id=p_company_id and cm.verification_status='verified' and cm.role in ('owner','admin') limit 1;
 if v_role is null then raise exception 'verified_owner_or_admin_required' using errcode='42501'; end if;
 select jsonb_build_object('name',c.name,'description',c.description,'website',c.website,'phone',c.phone,'city',c.city,'email',c.email)
 into v_old from public.companies c where c.id=p_company_id for update;
 update public.companies set name=trim(p_name),description=nullif(trim(coalesce(p_description,'')),''),
 website=nullif(trim(coalesce(p_website,'')),''),phone=nullif(trim(coalesce(p_phone,'')),''),
 city=nullif(trim(coalesce(p_city,'')),''),email=nullif(trim(coalesce(p_email,'')),''),
 updated_at=now() where id=p_company_id;
 select jsonb_build_object('id',c.id,'slug',c.slug,'name',c.name,'description',c.description,'website',c.website,'phone',c.phone,'city',c.city,'email',c.email,'status',c.status,'profile_status',c.profile_status)
 into v_new from public.companies c where c.id=p_company_id;
 insert into public.audit_log(company_id,user_id,action,target_type,target_id,metadata)
 values(p_company_id,v_user_id,'company_profile.updated','company',p_company_id::text,jsonb_build_object('role',v_role,'before',v_old,'after',v_new));
 return jsonb_build_object('company_id',p_company_id,'role',v_role,'company',v_new);
end; $function$
;
REVOKE ALL ON FUNCTION public.update_my_company_profile(uuid,text,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.update_my_company_profile(uuid,text,text,text,text,text,text) TO authenticated,service_role;

