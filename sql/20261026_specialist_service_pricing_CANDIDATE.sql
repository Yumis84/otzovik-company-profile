-- CANDIDATE ONLY. Requires separate GO for hosted staging. Prerequisite PR31 editor schema.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
ALTER TABLE public.specialist_services ADD COLUMN price_mode text, ADD COLUMN price_unit text;
ALTER TABLE public.specialist_services ADD CONSTRAINT specialist_services_price_mode_check CHECK (
 price_mode IS NULL OR
 (price_mode='priced' AND (price_from IS NOT NULL OR price_to IS NOT NULL)) OR
 (price_mode IN ('negotiated','unspecified') AND price_from IS NULL AND price_to IS NULL)
) NOT VALID;
ALTER TABLE public.specialist_services ADD CONSTRAINT specialist_services_price_unit_check CHECK (
 price_unit IS NULL OR price_unit IN ('service','hour','lesson','day','square_meter','project')
) NOT VALID;
ALTER TABLE public.specialist_services VALIDATE CONSTRAINT specialist_services_price_mode_check;
ALTER TABLE public.specialist_services VALIDATE CONSTRAINT specialist_services_price_unit_check;

-- Shared implementation: inaccessible to browser roles; wrappers retain their contracts.
CREATE FUNCTION public.specialist_service_pricing_save_internal(
 p_specialist_id uuid,p_service_id uuid,p_name text,p_description text,
 p_price_mode text,p_price_unit text,p_price_from numeric,p_price_to numeric,
 p_currency text,p_duration_minutes integer,p_is_active boolean,p_version integer,
 p_legacy boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v public.specialist_services; v_mode text; v_unit text; v_found boolean;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF p_service_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Service id required'; END IF;
 SELECT * INTO v FROM public.specialist_services WHERE id=p_service_id AND specialist_id=p_specialist_id FOR UPDATE;
 v_found:=FOUND;
 IF v_found THEN
  IF p_version IS DISTINCT FROM v.version THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Reload changed service'; END IF;
 ELSE
  IF EXISTS(SELECT 1 FROM public.specialist_services WHERE id=p_service_id) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Service unavailable'; END IF;
  IF p_version IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Service no longer exists'; END IF;
  IF (SELECT count(*) FROM public.specialist_services WHERE specialist_id=p_specialist_id)>=50 THEN RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Service limit reached'; END IF;
 END IF;
 IF p_legacy THEN
  v_unit:=CASE WHEN v_found THEN v.price_unit ELSE NULL END;
  IF NOT v_found THEN v_mode:=NULL;
  ELSIF p_price_from IS NOT DISTINCT FROM v.price_from AND p_price_to IS NOT DISTINCT FROM v.price_to THEN v_mode:=v.price_mode;
  ELSE v_mode:=CASE WHEN p_price_from IS NOT NULL OR p_price_to IS NOT NULL THEN 'priced' ELSE 'unspecified' END;
  END IF;
 ELSE
  IF p_price_mode IS NULL OR p_price_mode NOT IN ('priced','negotiated','unspecified') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid price mode'; END IF;
  v_mode:=p_price_mode;v_unit:=p_price_unit;
 END IF;
 IF p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 2 AND 150
  OR char_length(p_description)>2000 OR p_currency IS NULL OR p_currency NOT IN ('RUB','USD','EUR')
  OR p_is_active IS NULL OR (p_duration_minutes IS NOT NULL AND p_duration_minutes NOT BETWEEN 1 AND 1440)
  OR (v_unit IS NOT NULL AND v_unit NOT IN ('service','hour','lesson','day','square_meter','project'))
  OR (p_price_from IS NOT NULL AND (p_price_from::text IN ('NaN','Infinity','-Infinity') OR p_price_from<0 OR p_price_from>100000000))
  OR (p_price_to IS NOT NULL AND (p_price_to::text IN ('NaN','Infinity','-Infinity') OR p_price_to<0 OR p_price_to>100000000))
  OR (p_price_from IS NOT NULL AND p_price_to IS NOT NULL AND p_price_to<p_price_from)
  OR (v_mode='priced' AND p_price_from IS NULL AND p_price_to IS NULL)
  OR (v_mode IN ('negotiated','unspecified') AND (p_price_from IS NOT NULL OR p_price_to IS NOT NULL))
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid service pricing or fields'; END IF;
 IF NOT p_legacy AND ((p_price_from IS NOT NULL AND p_price_from<>round(p_price_from,2)) OR (p_price_to IS NOT NULL AND p_price_to<>round(p_price_to,2))) THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Use at most two decimal places'; END IF;
 IF v_found THEN
  UPDATE public.specialist_services SET name=btrim(p_name),description=nullif(btrim(p_description),''),
   price_from=p_price_from,price_to=p_price_to,currency=p_currency,duration_minutes=p_duration_minutes,
   is_active=p_is_active,price_mode=v_mode,price_unit=v_unit,version=version+1,updated_at=now()
   WHERE id=p_service_id AND specialist_id=p_specialist_id RETURNING * INTO v;
 ELSE
  INSERT INTO public.specialist_services(id,specialist_id,name,description,price_from,price_to,currency,duration_minutes,is_active,price_mode,price_unit)
   VALUES(p_service_id,p_specialist_id,btrim(p_name),nullif(btrim(p_description),''),p_price_from,p_price_to,p_currency,p_duration_minutes,p_is_active,v_mode,v_unit)
   RETURNING * INTO v;
 END IF;
 RETURN to_jsonb(v);
END $fn$;
REVOKE ALL ON FUNCTION public.specialist_service_pricing_save_internal(uuid,uuid,text,text,text,text,numeric,numeric,text,integer,boolean,integer,boolean) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.save_my_specialist_service_v2(
 p_specialist_id uuid,p_service_id uuid,p_name text,p_description text,p_price_mode text,p_price_unit text,
 p_price_from numeric,p_price_to numeric,p_currency text,p_duration_minutes integer,p_is_active boolean,p_version integer
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $fn$
 SELECT public.specialist_service_pricing_save_internal(p_specialist_id,p_service_id,p_name,p_description,p_price_mode,p_price_unit,p_price_from,p_price_to,p_currency,p_duration_minutes,p_is_active,p_version,false);
$fn$;
REVOKE ALL ON FUNCTION public.save_my_specialist_service_v2(uuid,uuid,text,text,text,text,numeric,numeric,text,integer,boolean,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_my_specialist_service_v2(uuid,uuid,text,text,text,text,numeric,numeric,text,integer,boolean,integer) TO authenticated;

-- Same v1 signature/defaults/OID; no blind resetting of the new metadata.
CREATE OR REPLACE FUNCTION public.save_my_specialist_service(
 p_specialist_id uuid,p_service_id uuid,p_name text,p_description text DEFAULT NULL,
 p_price_from numeric DEFAULT NULL,p_price_to numeric DEFAULT NULL,p_currency text DEFAULT 'RUB',
 p_duration_minutes integer DEFAULT NULL,p_is_active boolean DEFAULT true,p_version integer DEFAULT NULL
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $fn$
 SELECT public.specialist_service_pricing_save_internal(p_specialist_id,p_service_id,p_name,p_description,NULL,NULL,p_price_from,p_price_to,p_currency,p_duration_minutes,p_is_active,p_version,true);
$fn$;
REVOKE ALL ON FUNCTION public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer) TO authenticated;

CREATE FUNCTION public.get_my_specialist_service_pricing(p_specialist_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft')
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 RETURN jsonb_build_object('schema_version',2);
END $fn$;
REVOKE ALL ON FUNCTION public.get_my_specialist_service_pricing(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_service_pricing(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
