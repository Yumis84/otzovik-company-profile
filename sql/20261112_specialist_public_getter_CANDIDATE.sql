-- ISOLATED REVIEW ONLY. No HTTP cache configuration or production activation.
BEGIN;
CREATE FUNCTION public.get_public_specialist_v1(p_slug text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $getter$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RETURN NULL; END IF;
 IF p_slug IS NULL OR p_slug<>pg_catalog.lower(pg_catalog.btrim(p_slug)) OR p_slug !~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$' OR position('--' IN p_slug)>0 THEN RETURN NULL; END IF;
 IF NOT coalesce((SELECT enabled FROM public.specialist_public_control WHERE singleton),false) THEN RETURN NULL; END IF;
 SELECT jsonb_build_object('slug',r.slug,'display_name',r.display_name,'profession',r.profession,'specialization',r.specialization,'city',r.city,'description',r.description)
 INTO result FROM public.specialist_public_revisions r
 JOIN public.specialist_publication_state s ON s.specialist_id=r.specialist_id AND s.published_revision_id=r.revision_id AND s.state='published'
 JOIN public.specialist_profiles p ON p.id=s.specialist_id AND p.profile_status='draft'
 WHERE r.slug=p_slug;
 RETURN result;
END $getter$;
REVOKE ALL ON FUNCTION public.get_public_specialist_v1(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_public_specialist_v1(text) TO anon,authenticated;
COMMIT;
