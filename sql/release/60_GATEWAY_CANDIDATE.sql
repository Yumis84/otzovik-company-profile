-- REVIEW ONLY. App-owned reservations; no trigger on managed Storage.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN
 IF EXISTS(SELECT FROM pg_trigger WHERE tgname='specialist_object_integrity' AND NOT tgisinternal) THEN RAISE EXCEPTION 'Remove unapproved legacy guard in isolated fixture only; hosted drift requires review'; END IF;
END $$;
CREATE TABLE public.specialist_upload_control(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),enabled boolean NOT NULL DEFAULT false);
INSERT INTO public.specialist_upload_control VALUES(true,false);
CREATE TABLE public.specialist_upload_reservations(
 id uuid PRIMARY KEY, profile_id uuid NOT NULL, specialist_id uuid REFERENCES public.specialist_profiles(id) ON DELETE RESTRICT,
 object_name text NOT NULL UNIQUE, kind text NOT NULL CHECK(kind IN ('avatar','portfolio')),
 fingerprint text, mime text, size_bytes integer, caption text,
 state text NOT NULL CHECK(state IN ('uploading','ready','deleting','deleted')),
 CHECK((state='deleted' AND specialist_id IS NULL) OR (state<>'deleted' AND specialist_id IS NOT NULL AND specialist_id=profile_id)),
 created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL DEFAULT now()+interval '10 minutes'
);
CREATE INDEX ON public.specialist_upload_reservations(specialist_id);
ALTER TABLE public.specialist_upload_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_upload_control FORCE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_upload_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_upload_reservations FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_upload_control,public.specialist_upload_reservations FROM PUBLIC,anon,authenticated;
-- Deny even if another permissive policy accidentally grants broad access.
-- Company buckets are unaffected. service_role remains server-only.
DROP POLICY IF EXISTS specialist_object_insert ON storage.objects;
DROP POLICY IF EXISTS specialist_object_delete ON storage.objects;
DROP POLICY IF EXISTS specialist_gateway_insert_only ON storage.objects;
DROP POLICY IF EXISTS specialist_gateway_update_only ON storage.objects;
DROP POLICY IF EXISTS specialist_gateway_delete_only ON storage.objects;
CREATE POLICY specialist_gateway_insert_only ON storage.objects AS RESTRICTIVE FOR INSERT TO anon,authenticated WITH CHECK(bucket_id IS DISTINCT FROM 'specialist-media');
CREATE POLICY specialist_gateway_update_only ON storage.objects AS RESTRICTIVE FOR UPDATE TO anon,authenticated USING(bucket_id IS DISTINCT FROM 'specialist-media') WITH CHECK(bucket_id IS DISTINCT FROM 'specialist-media');
CREATE POLICY specialist_gateway_delete_only ON storage.objects AS RESTRICTIVE FOR DELETE TO anon,authenticated USING(bucket_id IS DISTINCT FROM 'specialist-media');
CREATE FUNCTION public.get_my_specialist_upload_capability(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 RETURN jsonb_build_object('protocol',1,'enabled',(SELECT enabled FROM public.specialist_upload_control WHERE singleton),'limit',20);
END $$;
CREATE FUNCTION public.specialist_gateway_reserve(p_owner uuid,p_specialist_id uuid,p_request_id uuid,p_kind text,p_fingerprint text,p_mime text,p_size integer,p_caption text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.specialist_upload_reservations; n integer; path text; ext text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF NOT (SELECT enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Uploads disabled'; END IF;
 IF p_request_id IS NULL OR p_kind NOT IN ('avatar','portfolio') OR p_kind IS NULL OR p_fingerprint !~ '^[a-f0-9]{64}$' OR p_fingerprint IS NULL OR p_mime NOT IN ('image/png','image/jpeg','image/webp') OR p_mime IS NULL OR p_size NOT BETWEEN 1 AND 5242880 OR p_size IS NULL OR char_length(coalesce(p_caption,''))>500 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid upload'; END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id;
 IF FOUND THEN
  IF r.profile_id<>p_specialist_id THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Upload unavailable'; END IF;
  IF r.state='deleted' THEN RETURN to_jsonb(r)||jsonb_build_object('upload_allowed',false); END IF;
  IF r.fingerprint IS DISTINCT FROM p_fingerprint OR r.kind<>p_kind OR r.caption IS DISTINCT FROM p_caption THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Request changed'; END IF;
  RETURN to_jsonb(r)||jsonb_build_object('upload_allowed',false);
 END IF;
 SELECT count(*)::int INTO n FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text;
 n:=n+(SELECT count(*)::int FROM public.specialist_upload_reservations u WHERE u.specialist_id=p_specialist_id AND u.state<>'deleted' AND NOT EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=u.object_name));
 IF n>=20 THEN RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Upload limit reached'; END IF;
 IF p_kind='avatar' AND (EXISTS(SELECT FROM public.specialist_media WHERE specialist_id=p_specialist_id AND kind='avatar') OR EXISTS(SELECT FROM public.specialist_upload_reservations WHERE specialist_id=p_specialist_id AND kind='avatar' AND state<>'deleted')) THEN RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='Avatar already exists'; END IF;
 ext:=CASE p_mime WHEN 'image/png' THEN 'png' WHEN 'image/jpeg' THEN 'jpg' ELSE 'webp' END;
 path:=p_specialist_id::text||'/'||p_kind||'/'||p_request_id::text||'.'||ext;
 IF EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=path) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Object already exists'; END IF;
 INSERT INTO public.specialist_upload_reservations(id,profile_id,specialist_id,object_name,kind,fingerprint,mime,size_bytes,caption,state) VALUES(p_request_id,p_specialist_id,p_specialist_id,path,p_kind,p_fingerprint,p_mime,p_size,p_caption,'uploading') RETURNING * INTO r;
 RETURN to_jsonb(r)||jsonb_build_object('upload_allowed',true);
END $$;
CREATE FUNCTION public.specialist_gateway_finish(p_owner uuid,p_specialist_id uuid,p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.specialist_upload_reservations; v public.specialist_media; meta jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id AND specialist_id=p_specialist_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Upload unavailable'; END IF;
 IF r.state NOT IN ('uploading','ready') THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Upload retired'; END IF;
 SELECT metadata INTO meta FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name;
 IF NOT FOUND OR (meta->>'size')::bigint IS DISTINCT FROM r.size_bytes OR meta->>'mimetype' IS DISTINCT FROM r.mime THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Upload pending or metadata mismatch; reservation retained'; END IF;
 INSERT INTO public.specialist_media(specialist_id,object_name,kind,caption) VALUES(p_specialist_id,r.object_name,r.kind,r.caption) ON CONFLICT(object_name) DO UPDATE SET caption=excluded.caption RETURNING * INTO v;
 UPDATE public.specialist_upload_reservations SET state='ready' WHERE id=r.id;
 RETURN to_jsonb(v);
END $$;
CREATE FUNCTION public.specialist_gateway_begin_delete(p_owner uuid,p_specialist_id uuid,p_object_name text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.specialist_upload_reservations; kind text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF NOT (SELECT enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Media mutations disabled'; END IF;
 IF p_object_name IS NULL OR split_part(p_object_name,'/',1)<>p_specialist_id::text OR p_object_name !~ '^[0-9a-f-]{36}/(avatar|portfolio)/[0-9a-f-]{36}[.](png|jpg|jpeg|webp)$' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Object unavailable'; END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE object_name=p_object_name FOR UPDATE;
 IF FOUND THEN
  IF r.state='uploading' THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Unknown in-flight upload; retain reservation'; END IF;
  IF r.state='deleted' THEN RETURN to_jsonb(r); END IF;
  UPDATE public.specialist_upload_reservations SET state='deleting' WHERE id=r.id RETURNING * INTO r;
 ELSE
  IF NOT EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=p_object_name) AND NOT EXISTS(SELECT FROM public.specialist_media WHERE specialist_id=p_specialist_id AND object_name=p_object_name) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Object unavailable'; END IF;
  kind:=split_part(p_object_name,'/',2);
  INSERT INTO public.specialist_upload_reservations(id,profile_id,specialist_id,object_name,kind,state) VALUES(gen_random_uuid(),p_specialist_id,p_specialist_id,p_object_name,kind,'deleting') RETURNING * INTO r;
 END IF;
 RETURN to_jsonb(r);
END $$;
CREATE FUNCTION public.specialist_gateway_finish_delete(p_owner uuid,p_specialist_id uuid,p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.specialist_upload_reservations;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id AND profile_id=p_specialist_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Object unavailable'; END IF;
 IF r.state NOT IN ('deleting','deleted') OR EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Storage deletion not confirmed'; END IF;
 DELETE FROM public.specialist_media WHERE specialist_id=p_specialist_id AND object_name=r.object_name;
 UPDATE public.specialist_upload_reservations SET state='deleted',specialist_id=NULL,fingerprint=NULL,mime=NULL,size_bytes=NULL,caption=NULL WHERE id=r.id;
 RETURN jsonb_build_object('deleted',true);
END $$;
CREATE FUNCTION public.specialist_gateway_reconcile(p_owner uuid,p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_owner IS NULL OR NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'object_name',r.object_name,'state',r.state,'expired',r.expires_at<now(),'object_exists',EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=r.object_name),'media_exists',EXISTS(SELECT FROM public.specialist_media m WHERE m.object_name=r.object_name))) FROM public.specialist_upload_reservations r WHERE specialist_id=p_specialist_id AND state<>'deleted'),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.get_my_specialist_upload_capability(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_upload_capability(uuid) TO authenticated;
DO $acl$ DECLARE r record; BEGIN
 FOR r IN SELECT oid::regprocedure signature FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'specialist_gateway_%' LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
 END LOOP;
END $acl$;
-- Browser metadata mutation is disabled: gateway owns completion/deletion.
REVOKE EXECUTE ON FUNCTION public.register_my_specialist_media(uuid,text,text,text),public.delete_my_specialist_media(uuid,uuid) FROM authenticated;
CREATE OR REPLACE FUNCTION public.delete_my_specialist_draft(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 IF NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF EXISTS(SELECT FROM public.specialist_upload_reservations WHERE specialist_id=p_specialist_id AND state<>'deleted') OR EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Remove specialist files before deleting draft'; END IF;
 DELETE FROM public.specialist_profiles WHERE id=p_specialist_id;
 RETURN jsonb_build_object('id',p_specialist_id,'deleted',true);
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;
