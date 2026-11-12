-- ISOLATED REVIEW ONLY. Requires C1/C2, quarantine, erasure barrier and retention.
-- No public getter or activation. Do not apply to hosted or production.
BEGIN;
CREATE TABLE public.specialist_publish_requests_v1 (
 specialist_id uuid NOT NULL REFERENCES public.specialist_profiles(id) ON DELETE CASCADE,
 request_id uuid NOT NULL,
 expected_version integer NOT NULL CHECK(expected_version>0),
 revision_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(specialist_id,request_id)
);
ALTER TABLE public.specialist_publish_requests_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_publish_requests_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_publish_requests_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.publish_my_specialist_v1(p_specialist_id uuid,p_expected_version integer,p_request_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $publish$
DECLARE p public.specialist_profiles; s public.specialist_publication_state; previous public.specialist_publish_requests_v1; revision uuid;
BEGIN
 IF auth.uid() IS NULL OR p_request_id IS NULL OR p_expected_version IS NULL OR p_expected_version<1 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Trusted RLS-bypass owner required'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('specialist-media:'||p_specialist_id::text,0));
 SELECT * INTO p FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND OR p.profile_status<>'draft' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 INSERT INTO public.specialist_publication_state(specialist_id) VALUES(p_specialist_id) ON CONFLICT(specialist_id) DO NOTHING;
 SELECT * INTO s FROM public.specialist_publication_state WHERE specialist_id=p_specialist_id FOR UPDATE;
 IF s.state IN ('suspended','erasing') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 SELECT * INTO previous FROM public.specialist_publish_requests_v1 WHERE specialist_id=p_specialist_id AND request_id=p_request_id;
 IF FOUND THEN
  IF previous.expected_version<>p_expected_version THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Request conflict'; END IF;
  RETURN jsonb_build_object('revision_id',previous.revision_id,'source_version',previous.expected_version,'replayed',true,'published',s.state='published' AND s.published_revision_id=previous.revision_id);
 END IF;
 IF p.version<>p_expected_version THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Version conflict'; END IF;
 PERFORM 1 FROM public.profile_slug_registry WHERE slug=p.slug AND profile_kind='specialist' AND profile_id=p.id FOR UPDATE;
 IF NOT FOUND OR position('--' IN p.slug)>0 OR EXISTS(SELECT FROM public.specialist_reserved_slugs_v1 WHERE slug=p.slug) OR EXISTS(SELECT FROM public.specialist_slug_tombstones_v1 WHERE slug=p.slug AND hold_until>pg_catalog.clock_timestamp()) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 INSERT INTO public.specialist_public_revisions(specialist_id,client_request_id,source_version,slug,display_name,profession,specialization,city,description)
 VALUES(p.id,p_request_id,p.version,p.slug,p.display_name,p.profession,p.specialization,p.city,p.description) RETURNING revision_id INTO revision;
 INSERT INTO public.specialist_publish_requests_v1(specialist_id,request_id,expected_version,revision_id) VALUES(p.id,p_request_id,p_expected_version,revision);
 UPDATE public.specialist_publication_state SET state='published',published_revision_id=revision WHERE specialist_id=p.id;
 RETURN jsonb_build_object('revision_id',revision,'source_version',p.version,'replayed',false,'published',true);
END $publish$;
REVOKE ALL ON FUNCTION public.publish_my_specialist_v1(uuid,integer,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.publish_my_specialist_v1(uuid,integer,uuid) TO authenticated;

CREATE FUNCTION public.unpublish_my_specialist_v1(p_specialist_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $unpublish$
DECLARE s public.specialist_publication_state;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Trusted RLS-bypass owner required'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 INSERT INTO public.specialist_publication_state(specialist_id) VALUES(p_specialist_id) ON CONFLICT(specialist_id) DO NOTHING;
 SELECT * INTO s FROM public.specialist_publication_state WHERE specialist_id=p_specialist_id FOR UPDATE;
 IF s.state IN ('suspended','erasing') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 UPDATE public.specialist_publication_state SET state='unpublished',published_revision_id=NULL WHERE specialist_id=p_specialist_id;
 RETURN jsonb_build_object('published',false);
END $unpublish$;
REVOKE ALL ON FUNCTION public.unpublish_my_specialist_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.unpublish_my_specialist_v1(uuid) TO authenticated;
COMMIT;
