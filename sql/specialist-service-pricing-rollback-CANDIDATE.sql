-- OPTIONAL DESTRUCTIVE CONTRACT ROLLBACK: never automatic, separate approval required.
-- Preferred rollback: revert UI only, retain additive schema and compatible wrappers.
-- Refuses ANY non-null extension metadata; no price/unit/mode can be silently lost.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
LOCK TABLE public.specialist_services IN ACCESS EXCLUSIVE MODE;
DO $guard$ BEGIN
 IF EXISTS(SELECT 1 FROM public.specialist_services WHERE price_mode IS NOT NULL OR price_unit IS NOT NULL)
 THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Extended pricing exists: use data-preserving UI rollback'; END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.save_my_specialist_service(p_specialist_id uuid, p_service_id uuid, p_name text, p_description text DEFAULT NULL::text, p_price_from numeric DEFAULT NULL::numeric, p_price_to numeric DEFAULT NULL::numeric, p_currency text DEFAULT 'RUB'::text, p_duration_minutes integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_version integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v public.specialist_services; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF p_service_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Service id required'; END IF;
 SELECT * INTO v FROM public.specialist_services WHERE id=p_service_id AND specialist_id=p_specialist_id FOR UPDATE;
 IF FOUND THEN
  IF p_version IS DISTINCT FROM v.version THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Reload changed service'; END IF;
  UPDATE public.specialist_services SET name=btrim(p_name),description=nullif(btrim(p_description),''),price_from=p_price_from,price_to=p_price_to,currency=p_currency,duration_minutes=p_duration_minutes,is_active=p_is_active,version=version+1,updated_at=now() WHERE id=p_service_id RETURNING * INTO v;
 ELSE
  IF EXISTS(SELECT FROM public.specialist_services WHERE id=p_service_id) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Service unavailable'; END IF;
  IF p_version IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Service no longer exists'; END IF;
  IF (SELECT count(*) FROM public.specialist_services WHERE specialist_id=p_specialist_id)>=50 THEN RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Service limit reached'; END IF;
  INSERT INTO public.specialist_services(id,specialist_id,name,description,price_from,price_to,currency,duration_minutes,is_active) VALUES(p_service_id,p_specialist_id,btrim(p_name),nullif(btrim(p_description),''),p_price_from,p_price_to,p_currency,p_duration_minutes,p_is_active) RETURNING * INTO v;
 END IF; RETURN to_jsonb(v); END;
$function$;

DROP FUNCTION public.save_my_specialist_service_v2(uuid,uuid,text,text,text,text,numeric,numeric,text,integer,boolean,integer);
DROP FUNCTION public.get_my_specialist_service_pricing(uuid);
DROP FUNCTION public.specialist_service_pricing_save_internal(uuid,uuid,text,text,text,text,numeric,numeric,text,integer,boolean,integer,boolean);
ALTER TABLE public.specialist_services DROP CONSTRAINT specialist_services_price_mode_check,DROP CONSTRAINT specialist_services_price_unit_check,DROP COLUMN price_mode,DROP COLUMN price_unit;
COMMIT;
