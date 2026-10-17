-- CANDIDATE ONLY: separate private bucket, no public media route.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION 'Trusted BYPASSRLS owner required'; END IF; IF EXISTS(SELECT FROM storage.buckets WHERE id='specialist-media') THEN RAISE EXCEPTION 'Review existing specialist bucket before migration'; END IF; END $$;
-- BYPASSRLS does not grant table ownership or permission to CREATE POLICY.
DO $storage_owner$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND rolsuper)
 AND NOT EXISTS(SELECT FROM pg_class c WHERE c.oid='storage.objects'::regclass AND pg_has_role(current_user,c.relowner,'USAGE')) THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Storage policy deployment requires storage.objects ownership; do not grant roles or change managed table ownership to bypass this gate';
 END IF;
 IF NOT has_table_privilege(current_user,'storage.buckets','INSERT') THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Storage bucket INSERT privilege required';
 END IF;
END $storage_owner$;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('specialist-media','specialist-media',false,5242880,ARRAY['image/jpeg','image/png','image/webp']);
CREATE TABLE public.specialist_media (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), specialist_id uuid NOT NULL REFERENCES public.specialist_profiles(id) ON DELETE CASCADE,
 object_name text NOT NULL UNIQUE, kind text NOT NULL CHECK(kind IN ('avatar','portfolio')),
 caption text CHECK(char_length(caption)<=500), created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(object_name LIKE specialist_id::text||'/'||kind||'/%')
);
CREATE INDEX ON public.specialist_media(specialist_id);
CREATE UNIQUE INDEX specialist_one_avatar ON public.specialist_media(specialist_id) WHERE kind='avatar';
ALTER TABLE public.specialist_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_media FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_media FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.can_manage_specialist_object(p_name text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(avatar|portfolio)/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](webp|png|jpg|jpeg)$'
 AND EXISTS(SELECT FROM public.specialist_profiles WHERE id=CASE WHEN split_part(p_name,'/',1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN split_part(p_name,'/',1)::uuid END AND owner_user_id=auth.uid() AND profile_status='draft');
$$;
CREATE FUNCTION public.can_upload_specialist_object(p_name text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.can_manage_specialist_object(p_name) THEN RETURN false; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||split_part(p_name,'/',1),0));
 -- Recheck ownership after waiting; coordinate with draft deletion and pin its row.
 PERFORM 1 FROM public.specialist_profiles WHERE id=CASE WHEN split_part(p_name,'/',1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN split_part(p_name,'/',1)::uuid END AND owner_user_id=auth.uid() AND profile_status='draft' FOR KEY SHARE;
 IF NOT FOUND THEN RETURN false; END IF;
 RETURN (SELECT count(*) FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=split_part(p_name,'/',1))<20;
END $$;
REVOKE ALL ON FUNCTION public.can_manage_specialist_object(text),public.can_upload_specialist_object(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_specialist_object(text),public.can_upload_specialist_object(text) TO authenticated;
CREATE POLICY specialist_object_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='specialist-media' AND public.can_manage_specialist_object(name));
CREATE POLICY specialist_object_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='specialist-media' AND public.can_upload_specialist_object(name));
CREATE POLICY specialist_object_delete ON storage.objects FOR DELETE TO authenticated USING(bucket_id='specialist-media' AND public.can_manage_specialist_object(name));
-- No UPDATE/upsert or anonymous policy; new UUID for each upload.
CREATE FUNCTION public.get_my_specialist_media(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF; PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft'; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; RETURN coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at,x.id) FROM public.specialist_media x WHERE specialist_id=p_specialist_id),'[]'::jsonb); END;
$fn$;
CREATE FUNCTION public.register_my_specialist_media(p_specialist_id uuid,p_object_name text,p_kind text,p_caption text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v public.specialist_media; meta jsonb; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF; PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF p_object_name IS NULL OR NOT public.can_manage_specialist_object(p_object_name) OR split_part(p_object_name,'/',1)<>p_specialist_id::text OR split_part(p_object_name,'/',2) IS DISTINCT FROM p_kind OR p_kind NOT IN ('avatar','portfolio') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid media path'; END IF;
 SELECT metadata INTO meta FROM storage.objects WHERE bucket_id='specialist-media' AND name=p_object_name;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='Upload required'; END IF;
 IF coalesce((meta->>'size')::bigint,0) NOT BETWEEN 1 AND 5242880 OR coalesce(meta->>'mimetype','') NOT IN ('image/jpeg','image/png','image/webp') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid image metadata'; END IF;
 INSERT INTO public.specialist_media(specialist_id,object_name,kind,caption) VALUES(p_specialist_id,p_object_name,p_kind,nullif(btrim(p_caption),''))
 ON CONFLICT(object_name) DO UPDATE SET caption=excluded.caption RETURNING * INTO v;
 RETURN to_jsonb(v); END;
$fn$;
CREATE FUNCTION public.delete_my_specialist_media(p_specialist_id uuid,p_media_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v public.specialist_media; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF; PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; DELETE FROM public.specialist_media WHERE id=p_media_id AND specialist_id=p_specialist_id RETURNING * INTO v; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Media unavailable'; END IF; RETURN to_jsonb(v); END;
$fn$;
REVOKE ALL ON FUNCTION public.get_my_specialist_media(uuid) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.get_my_specialist_media(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.register_my_specialist_media(uuid,text,text,text) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.register_my_specialist_media(uuid,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.delete_my_specialist_media(uuid,uuid) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.delete_my_specialist_media(uuid,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
