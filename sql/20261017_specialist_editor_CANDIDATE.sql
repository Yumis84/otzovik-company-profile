-- CANDIDATE ONLY: private specialist editor. Not applied to production.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION 'Trusted BYPASSRLS owner required'; END IF; END $$;
CREATE TABLE public.specialist_services (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 specialist_id uuid NOT NULL REFERENCES public.specialist_profiles(id) ON DELETE CASCADE,
 name text NOT NULL CHECK(char_length(btrim(name)) BETWEEN 2 AND 150),
 description text CHECK(char_length(description)<=2000),
 price_from numeric(12,2) CHECK(price_from BETWEEN 0 AND 100000000),
 price_to numeric(12,2) CHECK(price_to BETWEEN 0 AND 100000000 AND (price_from IS NULL OR price_to>=price_from)),
 currency text NOT NULL DEFAULT 'RUB' CHECK(currency IN ('RUB','USD','EUR')),
 duration_minutes integer CHECK(duration_minutes BETWEEN 1 AND 1440),
 is_active boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON public.specialist_services(specialist_id);
CREATE TABLE public.specialist_settings (
 specialist_id uuid PRIMARY KEY REFERENCES public.specialist_profiles(id) ON DELETE CASCADE,
 phone text CHECK(char_length(phone)<=100), email text CHECK(char_length(email)<=320),
 website text CHECK(char_length(website)<=500 AND website ~ '^https://[^[:space:]]+$'),
 work_formats text[] NOT NULL DEFAULT '{}' CHECK(work_formats <@ ARRAY['online','studio','onsite']::text[] AND array_position(work_formats,NULL) IS NULL),
 service_area text CHECK(char_length(service_area)<=300),
 qualifications text CHECK(char_length(qualifications)<=2000),
 contact_visibility text NOT NULL DEFAULT 'private' CHECK(contact_visibility='private'),
 version integer NOT NULL DEFAULT 1, updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.specialist_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_services FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_services FROM PUBLIC,anon,authenticated;
ALTER TABLE public.specialist_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_settings FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.get_my_specialist_services(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; RETURN coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at,x.id) FROM public.specialist_services x WHERE specialist_id=p_specialist_id),'[]'::jsonb); END;
$fn$;
CREATE OR REPLACE FUNCTION public.save_my_specialist_service(p_specialist_id uuid,p_service_id uuid,p_name text,p_description text DEFAULT NULL,p_price_from numeric DEFAULT NULL,p_price_to numeric DEFAULT NULL,p_currency text DEFAULT 'RUB',p_duration_minutes integer DEFAULT NULL,p_is_active boolean DEFAULT true,p_version integer DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v public.specialist_services; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF p_service_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Service id required'; END IF;
 SELECT * INTO v FROM public.specialist_services WHERE id=p_service_id FOR UPDATE;
 IF FOUND THEN
  IF v.specialist_id<>p_specialist_id THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Service unavailable'; END IF;
  IF p_version IS DISTINCT FROM v.version THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Reload changed service'; END IF;
  UPDATE public.specialist_services SET name=btrim(p_name),description=nullif(btrim(p_description),''),price_from=p_price_from,price_to=p_price_to,currency=p_currency,duration_minutes=p_duration_minutes,is_active=p_is_active,version=version+1,updated_at=now() WHERE id=p_service_id RETURNING * INTO v;
 ELSE
  IF p_version IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Service no longer exists'; END IF;
  IF (SELECT count(*) FROM public.specialist_services WHERE specialist_id=p_specialist_id)>=50 THEN RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Service limit reached'; END IF;
  INSERT INTO public.specialist_services(id,specialist_id,name,description,price_from,price_to,currency,duration_minutes,is_active) VALUES(p_service_id,p_specialist_id,btrim(p_name),nullif(btrim(p_description),''),p_price_from,p_price_to,p_currency,p_duration_minutes,p_is_active) RETURNING * INTO v;
 END IF; RETURN to_jsonb(v); END;
$fn$;
CREATE OR REPLACE FUNCTION public.delete_my_specialist_service(p_specialist_id uuid,p_service_id uuid,p_version integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; DELETE FROM public.specialist_services WHERE id=p_service_id AND specialist_id=p_specialist_id AND version=p_version; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Reload service'; END IF; RETURN jsonb_build_object('id',p_service_id); END;
$fn$;
CREATE OR REPLACE FUNCTION public.get_my_specialist_settings(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; RETURN coalesce((SELECT to_jsonb(x) FROM public.specialist_settings x WHERE specialist_id=p_specialist_id),jsonb_build_object('specialist_id',p_specialist_id,'work_formats','[]'::jsonb,'contact_visibility','private','version',0)); END;
$fn$;
CREATE OR REPLACE FUNCTION public.save_my_specialist_settings(p_specialist_id uuid,p_phone text DEFAULT NULL,p_email text DEFAULT NULL,p_website text DEFAULT NULL,p_work_formats text[] DEFAULT '{}',p_service_area text DEFAULT NULL,p_qualifications text DEFAULT NULL,p_version integer DEFAULT 0) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v public.specialist_settings; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 SELECT * INTO v FROM public.specialist_settings WHERE specialist_id=p_specialist_id FOR UPDATE;
 IF coalesce(v.version,0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Reload changed contacts'; END IF;
 INSERT INTO public.specialist_settings(specialist_id,phone,email,website,work_formats,service_area,qualifications)
 VALUES(p_specialist_id,nullif(btrim(p_phone),''),nullif(btrim(p_email),''),nullif(btrim(p_website),''),p_work_formats,nullif(btrim(p_service_area),''),nullif(btrim(p_qualifications),''))
 ON CONFLICT(specialist_id) DO UPDATE SET phone=excluded.phone,email=excluded.email,website=excluded.website,work_formats=excluded.work_formats,service_area=excluded.service_area,qualifications=excluded.qualifications,version=specialist_settings.version+1,updated_at=now() RETURNING * INTO v;
 RETURN to_jsonb(v); END;
$fn$;
REVOKE ALL ON FUNCTION public.get_my_specialist_services(uuid) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.get_my_specialist_services(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.delete_my_specialist_service(uuid,uuid,integer) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.delete_my_specialist_service(uuid,uuid,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_specialist_settings(uuid) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.get_my_specialist_settings(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
