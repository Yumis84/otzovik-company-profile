-- Review candidate. Apply in an isolated clone before enabling UI.
BEGIN;
CREATE FUNCTION public.update_my_company_service(p_company_id uuid,p_service_id uuid,p_name text,p_category text,p_description text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_user uuid:=auth.uid(); v_role text; v_name text:=btrim(p_name);
BEGIN
 SELECT role INTO v_role FROM public.company_memberships
 WHERE company_id=p_company_id AND user_id=v_user AND verification_status='verified' AND role IN ('owner','admin');
 IF v_role IS NULL THEN RAISE EXCEPTION 'verified_owner_or_admin_required' USING ERRCODE='42501'; END IF;
 IF v_name IS NULL OR char_length(v_name) NOT BETWEEN 1 AND 200 OR char_length(p_category)>200 OR char_length(p_description)>500 THEN
  RAISE EXCEPTION 'invalid_company_service_fields' USING ERRCODE='22023';
 END IF;
 UPDATE public.company_services SET name=v_name,category=nullif(btrim(p_category),''),description=nullif(btrim(p_description),''),updated_at=now()
 WHERE id=p_service_id AND company_id=p_company_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'company_service_not_found' USING ERRCODE='P0002'; END IF;
 INSERT INTO public.audit_log(company_id,user_id,action,target_type,target_id,metadata)
 VALUES(p_company_id,v_user,'company_service.update','service',p_service_id,jsonb_build_object('role',v_role));
 RETURN jsonb_build_object('id',p_service_id,'company_id',p_company_id);
END $$;
REVOKE ALL ON FUNCTION public.update_my_company_service(uuid,uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.update_my_company_service(uuid,uuid,text,text,text) TO authenticated;
COMMIT;
