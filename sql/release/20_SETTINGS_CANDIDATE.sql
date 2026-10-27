-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
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

ALTER TABLE public.specialist_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_settings FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.get_my_specialist_settings(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft';
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
REVOKE ALL ON FUNCTION public.get_my_specialist_settings(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
