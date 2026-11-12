-- ISOLATED REVIEW ONLY. Owner status for the existing specialist editor.
BEGIN;
CREATE FUNCTION public.get_my_specialist_publication_v1(p_specialist_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $status$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 SELECT jsonb_build_object('version',p.version,'state',coalesce(s.state,'unpublished'),'public_enabled',coalesce((SELECT enabled FROM public.specialist_public_control WHERE singleton),false),'preview',jsonb_build_object('display_name',p.display_name,'profession',p.profession,'specialization',p.specialization,'city',p.city,'description',p.description))
 INTO result FROM public.specialist_profiles p LEFT JOIN public.specialist_publication_state s ON s.specialist_id=p.id
 WHERE p.id=p_specialist_id AND p.owner_user_id=auth.uid() AND p.profile_status='draft';
 IF result IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 RETURN result;
END $status$;
REVOKE ALL ON FUNCTION public.get_my_specialist_publication_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_publication_v1(uuid) TO authenticated;
COMMIT;
