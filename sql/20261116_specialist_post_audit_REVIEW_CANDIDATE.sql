-- REVIEW CANDIDATE ONLY: not applied. P1-1/P1-3, P1-4 fail-closed capacity guard.
-- Verify control lock order and disable concurrency. No GRANT/REVOKE; P1-2 owner decision remains open.
BEGIN;
CREATE OR REPLACE FUNCTION public.specialist_public_fields_version_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $fn$
BEGIN
  IF ROW(NEW.slug, NEW.display_name, NEW.profession, NEW.specialization, NEW.city, NEW.description)
     IS DISTINCT FROM ROW(OLD.slug, OLD.display_name, OLD.profession, OLD.specialization, OLD.city, OLD.description) THEN
    NEW.version := OLD.version + 1;
  ELSE
    NEW.version := OLD.version;
  END IF;
  RETURN NEW;
END
$fn$;
-- ISOLATED REVIEW ONLY. No HTTP cache configuration or production activation.
CREATE OR REPLACE FUNCTION public.get_public_specialist_v1(p_slug text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $getter$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RETURN NULL; END IF;
 IF p_slug IS NULL OR p_slug<>pg_catalog.lower(pg_catalog.btrim(p_slug)) OR p_slug !~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$' OR position('--' IN p_slug)>0 THEN RETURN NULL; END IF;
 IF NOT coalesce((SELECT enabled FROM public.specialist_public_control WHERE singleton),false) THEN RETURN NULL; END IF;
 SELECT jsonb_build_object('slug',r.slug,'display_name',r.display_name,'profession',r.profession,'specialization',r.specialization,'city',r.city,'description',r.description)
 INTO result FROM public.specialist_public_revisions r
 JOIN public.specialist_publication_state s ON s.specialist_id=r.specialist_id AND s.published_revision_id=r.revision_id AND s.state='published'
 JOIN public.specialist_profiles p ON p.id=s.specialist_id AND p.profile_status='draft' AND p.slug=r.slug
 WHERE r.slug=p_slug AND EXISTS (SELECT 1 FROM public.profile_slug_registry g WHERE g.slug=r.slug AND g.profile_kind='specialist' AND g.profile_id=p.id);
 RETURN result;
END $getter$;
CREATE OR REPLACE FUNCTION public.publish_my_specialist_v1(p_specialist_id uuid,p_expected_version integer,p_request_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $publish$
DECLARE p public.specialist_profiles; s public.specialist_publication_state; previous public.specialist_publish_requests_v1; revision uuid;
BEGIN
 IF auth.uid() IS NULL OR p_request_id IS NULL OR p_expected_version IS NULL OR p_expected_version<1 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Trusted RLS-bypass owner required'; END IF;
 PERFORM 1 FROM public.specialist_public_control WHERE singleton AND enabled FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Public display disabled'; END IF;
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
 IF (SELECT count(*) FROM public.specialist_publish_requests_v1 WHERE specialist_id=p_specialist_id)>=1000 THEN RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Publication request limit reached'; END IF;
 IF p.version<>p_expected_version THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Version conflict'; END IF;
 PERFORM 1 FROM public.profile_slug_registry WHERE slug=p.slug AND profile_kind='specialist' AND profile_id=p.id FOR UPDATE;
 IF NOT FOUND OR position('--' IN p.slug)>0 OR EXISTS(SELECT FROM public.specialist_reserved_slugs_v1 WHERE slug=p.slug) OR EXISTS(SELECT FROM public.specialist_slug_tombstones_v1 WHERE slug=p.slug AND hold_until>pg_catalog.clock_timestamp()) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 INSERT INTO public.specialist_public_revisions(specialist_id,client_request_id,source_version,slug,display_name,profession,specialization,city,description)
 VALUES(p.id,p_request_id,p.version,p.slug,p.display_name,p.profession,p.specialization,p.city,p.description) RETURNING revision_id INTO revision;
 INSERT INTO public.specialist_publish_requests_v1(specialist_id,request_id,expected_version,revision_id) VALUES(p.id,p_request_id,p_expected_version,revision);
 UPDATE public.specialist_publication_state SET state='published',published_revision_id=revision WHERE specialist_id=p.id;
 RETURN jsonb_build_object('revision_id',revision,'source_version',p.version,'replayed',false,'published',true);
END $publish$;
COMMIT;
