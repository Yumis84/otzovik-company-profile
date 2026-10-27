-- CANDIDATE ONLY. One explicit reviewed phase, no auto apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN IF md5(pg_get_functiondef('public.create_my_specialist_draft(text,text,text,text,text,text)'::regprocedure)) IS DISTINCT FROM '64f33fb6fd83f891363c2035f39ca73c' THEN RAISE EXCEPTION 'Create RPC drift; review diff first'; END IF; END $$;
-- CANDIDATE ONLY. Limit new drafts; release slug only on explicit owner deletion.

CREATE OR REPLACE FUNCTION public.create_my_specialist_draft(
  p_display_name text,
  p_slug text,
  p_profession text DEFAULT NULL,
  p_specialization text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_description text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_name text := btrim(coalesce(p_display_name,''));
  v_slug text := lower(btrim(coalesce(p_slug,'')));
  v_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Authentication required';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('specialist-drafts:'||v_user_id::text,0));
  IF (SELECT count(*) FROM public.specialist_profiles WHERE owner_user_id=v_user_id)>=10 THEN RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Draft limit reached'; END IF;
  IF char_length(v_name) NOT BETWEEN 2 AND 150 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid specialist name';
  END IF;
  IF char_length(btrim(coalesce(p_profession,''))) NOT BETWEEN 1 AND 120 OR char_length(coalesce(p_specialization,'')) > 160 OR char_length(coalesce(p_city,'')) > 120 OR char_length(coalesce(p_description,'')) > 2000 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Specialist field too long';
  END IF;
  IF v_slug !~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$'
     OR v_slug ~ '^xn--'
     OR v_slug IN ('www','api','admin','test','test2','account','login','profiles','specialists')
  THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid or reserved slug';
  END IF;
  INSERT INTO public.specialist_profiles(owner_user_id,slug,display_name,profession,specialization,city,description)
  VALUES (v_user_id,v_slug,v_name,
          nullif(btrim(coalesce(p_profession,'')),''),
          nullif(btrim(coalesce(p_specialization,'')),''),
          nullif(btrim(coalesce(p_city,'')),''),nullif(btrim(coalesce(p_description,'')),''))
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('id',v_id,'slug',v_slug,'profile_status','draft');
END
$function$;
CREATE FUNCTION public.delete_my_specialist_draft(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 IF NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Remove specialist files before deleting draft'; END IF;
 DELETE FROM public.specialist_profiles WHERE id=p_specialist_id;
 RETURN jsonb_build_object('id',p_specialist_id,'deleted',true);
END $$;
REVOKE ALL ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text),public.delete_my_specialist_draft(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text),public.delete_my_specialist_draft(uuid) TO authenticated;



NOTIFY pgrst,'reload schema';
COMMIT;
