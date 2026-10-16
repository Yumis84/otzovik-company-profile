-- OTZOVIK Specialist V1, candidate migration. REVIEW ONLY: DO NOT APPLY TO PRODUCTION.
-- Independent specialist drafts; company schema, membership and RPCs unchanged.
BEGIN;

CREATE TABLE IF NOT EXISTS public.specialist_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  slug text NOT NULL UNIQUE,
  display_name text NOT NULL,
  profession text,
  specialization text,
  city text,
  description text,
  profile_status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT specialist_profiles_slug_format CHECK (
    slug ~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$'
    AND slug !~ '^xn--'
    AND slug NOT IN ('www','api','admin','test','test2','account','login','profiles','specialists')
  ),
  CONSTRAINT specialist_profiles_name_length CHECK (char_length(btrim(display_name)) BETWEEN 2 AND 200),
  CONSTRAINT specialist_profiles_status_check CHECK (profile_status IN ('draft','published','unpublished','suspended'))
);

CREATE INDEX IF NOT EXISTS specialist_profiles_owner_idx ON public.specialist_profiles(owner_user_id);
ALTER TABLE public.specialist_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_profiles FROM PUBLIC, anon, authenticated;

-- No direct table writes by clients. All draft creation goes through this narrow RPC.
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
  IF char_length(v_name) NOT BETWEEN 2 AND 200 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid specialist name';
  END IF;
  IF char_length(coalesce(p_profession,'')) > 120 OR char_length(coalesce(p_specialization,'')) > 160 OR char_length(coalesce(p_city,'')) > 120 OR char_length(coalesce(p_description,'')) > 2000 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Specialist field too long';
  END IF;
  IF v_slug !~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$'
     OR v_slug ~ '^xn--'
     OR v_slug IN ('www','api','admin','test','test2','account','login','profiles','specialists')
  THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid or reserved slug';
  END IF;
  -- Company and specialist profiles share a public hostname namespace.
  IF EXISTS (SELECT 1 FROM public.companies WHERE slug = v_slug) THEN
    RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='Profile address already taken';
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

CREATE OR REPLACE FUNCTION public.get_my_specialists()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Authentication required';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'id',s.id,'slug',s.slug,'display_name',s.display_name,
      'profession',s.profession,'specialization',s.specialization,
      'city',s.city,'description',s.description,'profile_status',s.profile_status
    ) ORDER BY s.created_at DESC)
    FROM public.specialist_profiles s WHERE s.owner_user_id = v_user_id
  ),'[]'::jsonb);
END
$function$;

REVOKE ALL ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_specialists() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_specialists() TO authenticated;

-- Deliberately no public SELECT, publish RPC, specialist reviews or credentials yet.
-- Publication and consent require separately reviewed migration and acceptance tests.
COMMIT;
