-- REVIEW ONLY. Apply after specialist_drafts_independent candidate, not to production without approval.
BEGIN;
CREATE OR REPLACE FUNCTION public.update_my_specialist_draft(p_id uuid,p_display_name text,p_profession text,p_specialization text DEFAULT NULL,p_city text DEFAULT NULL,p_description text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE v_uid uuid := auth.uid(); v_id uuid;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 IF char_length(btrim(coalesce(p_display_name,''))) NOT BETWEEN 2 AND 150 OR char_length(btrim(coalesce(p_profession,''))) NOT BETWEEN 1 AND 120 OR char_length(coalesce(p_specialization,'')) > 160 OR char_length(coalesce(p_city,'')) > 120 OR char_length(coalesce(p_description,'')) > 2000 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid fields'; END IF;
 UPDATE public.specialist_profiles SET display_name=btrim(p_display_name),profession=nullif(btrim(coalesce(p_profession,'')),''),specialization=nullif(btrim(coalesce(p_specialization,'')),''),city=nullif(btrim(coalesce(p_city,'')),''),description=nullif(btrim(coalesce(p_description,'')),''),updated_at=now() WHERE id=p_id AND owner_user_id=v_uid AND profile_status='draft' RETURNING id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft not found or access denied'; END IF;
 RETURN jsonb_build_object('id',v_id,'profile_status','draft');
END
$fn$;
REVOKE ALL ON FUNCTION public.update_my_specialist_draft(uuid,text,text,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_specialist_draft(uuid,text,text,text,text,text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
