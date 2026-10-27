CREATE OR REPLACE FUNCTION public.create_my_specialist_draft(p_display_name text, p_slug text, p_profession text DEFAULT NULL::text, p_specialization text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_description text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
$function$
