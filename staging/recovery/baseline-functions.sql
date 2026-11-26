CREATE OR REPLACE FUNCTION public.can_manage_specialist_object(p_name text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT auth.uid() IS NOT NULL AND p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(avatar|portfolio)/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](webp|png|jpg|jpeg)$'
 AND EXISTS(SELECT FROM public.specialist_profiles WHERE id=CASE WHEN split_part(p_name,'/',1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN split_part(p_name,'/',1)::uuid END AND owner_user_id=auth.uid() AND profile_status='draft');
$function$
;
REVOKE ALL ON FUNCTION public.can_manage_specialist_object(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.can_manage_specialist_object(text) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.can_upload_specialist_object(p_name text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NOT public.can_manage_specialist_object(p_name) THEN RETURN false; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||split_part(p_name,'/',1),0));
 -- Recheck ownership after waiting; coordinate with draft deletion and pin its row.
 PERFORM 1 FROM public.specialist_profiles WHERE id=CASE WHEN split_part(p_name,'/',1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN split_part(p_name,'/',1)::uuid END AND owner_user_id=auth.uid() AND profile_status='draft' FOR KEY SHARE;
 IF NOT FOUND THEN RETURN false; END IF;
 RETURN (SELECT count(*) FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=split_part(p_name,'/',1))<20;
END $function$
;
REVOKE ALL ON FUNCTION public.can_upload_specialist_object(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.can_upload_specialist_object(text) TO service_role,authenticated;
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
$function$
;
REVOKE ALL ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.delete_my_specialist_draft(p_specialist_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 IF NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Remove specialist files before deleting draft'; END IF;
 DELETE FROM public.specialist_profiles WHERE id=p_specialist_id;
 RETURN jsonb_build_object('id',p_specialist_id,'deleted',true);
END $function$
;
REVOKE ALL ON FUNCTION public.delete_my_specialist_draft(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.delete_my_specialist_draft(uuid) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.delete_my_specialist_media(p_specialist_id uuid, p_media_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v public.specialist_media; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF; PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; DELETE FROM public.specialist_media WHERE id=p_media_id AND specialist_id=p_specialist_id RETURNING * INTO v; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Media unavailable'; END IF; RETURN to_jsonb(v); END;
$function$
;
REVOKE ALL ON FUNCTION public.delete_my_specialist_media(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.delete_my_specialist_media(uuid,uuid) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.delete_my_specialist_service(p_specialist_id uuid, p_service_id uuid, p_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; DELETE FROM public.specialist_services WHERE id=p_service_id AND specialist_id=p_specialist_id AND version=p_version; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Reload service'; END IF; RETURN jsonb_build_object('id',p_service_id); END;
$function$
;
REVOKE ALL ON FUNCTION public.delete_my_specialist_service(uuid,uuid,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.delete_my_specialist_service(uuid,uuid,integer) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.get_my_specialist_media(p_specialist_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF; PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft'; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; RETURN coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at,x.id) FROM public.specialist_media x WHERE specialist_id=p_specialist_id),'[]'::jsonb); END;
$function$
;
REVOKE ALL ON FUNCTION public.get_my_specialist_media(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_media(uuid) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.get_my_specialist_services(p_specialist_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; RETURN coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at,x.id) FROM public.specialist_services x WHERE specialist_id=p_specialist_id),'[]'::jsonb); END;
$function$
;
REVOKE ALL ON FUNCTION public.get_my_specialist_services(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_services(uuid) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.get_my_specialist_settings(p_specialist_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF; RETURN coalesce((SELECT to_jsonb(x) FROM public.specialist_settings x WHERE specialist_id=p_specialist_id),jsonb_build_object('specialist_id',p_specialist_id,'work_formats','[]'::jsonb,'contact_visibility','private','version',0)); END;
$function$
;
REVOKE ALL ON FUNCTION public.get_my_specialist_settings(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_settings(uuid) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.get_my_specialists()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
$function$
;
REVOKE ALL ON FUNCTION public.get_my_specialists() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_specialists() TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.list_my_specialist_channels(p_specialist_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v integer; rows jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft';
 IF NOT FOUND THEN RAISE EXCEPTION 'Draft not found' USING ERRCODE='42501'; END IF;
 SELECT version INTO v FROM public.specialist_channel_sets WHERE specialist_id=p_specialist_id;
 SELECT coalesce(jsonb_agg(to_jsonb(c)-'specialist_id' ORDER BY c.sort_order),'[]'::jsonb) INTO rows FROM public.specialist_contact_channels c WHERE specialist_id=p_specialist_id;
 RETURN jsonb_build_object('version',coalesce(v,0),'channels',rows);
END $function$
;
REVOKE ALL ON FUNCTION public.list_my_specialist_channels(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.list_my_specialist_channels(uuid) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.register_my_specialist_media(p_specialist_id uuid, p_object_name text, p_kind text, p_caption text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v public.specialist_media; meta jsonb; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF; PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF p_object_name IS NULL OR NOT public.can_manage_specialist_object(p_object_name) OR split_part(p_object_name,'/',1)<>p_specialist_id::text OR split_part(p_object_name,'/',2) IS DISTINCT FROM p_kind OR p_kind NOT IN ('avatar','portfolio') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid media path'; END IF;
 SELECT metadata INTO meta FROM storage.objects WHERE bucket_id='specialist-media' AND name=p_object_name;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='Upload required'; END IF;
 IF coalesce((meta->>'size')::bigint,0) NOT BETWEEN 1 AND 5242880 OR coalesce(meta->>'mimetype','') NOT IN ('image/jpeg','image/png','image/webp') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid image metadata'; END IF;
 INSERT INTO public.specialist_media(specialist_id,object_name,kind,caption) VALUES(p_specialist_id,p_object_name,p_kind,nullif(btrim(p_caption),''))
 ON CONFLICT(object_name) DO UPDATE SET caption=excluded.caption RETURNING * INTO v;
 RETURN to_jsonb(v); END;
$function$
;
REVOKE ALL ON FUNCTION public.register_my_specialist_media(uuid,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.register_my_specialist_media(uuid,text,text,text) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.save_my_specialist_channels(p_specialist_id uuid, p_version integer, p_channels jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v integer; r jsonb; normalized text; ord integer:=0; preferred integer:=0; cid uuid; lbl text; k text; flag text; allrows jsonb:='[]'; ids uuid[]:='{}'; keys text[]:='{}'; dedup text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Draft not found' USING ERRCODE='42501'; END IF;
 SELECT version INTO v FROM public.specialist_channel_sets WHERE specialist_id=p_specialist_id FOR UPDATE;
 IF p_version IS NULL OR p_version<0 OR p_version<>coalesce(v,0) THEN RAISE EXCEPTION 'Contacts changed; reload' USING ERRCODE='PT409'; END IF;
 IF p_channels IS NULL OR jsonb_typeof(p_channels)<>'array' THEN RAISE EXCEPTION 'Array required' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_channels)>20 THEN RAISE EXCEPTION 'Maximum 20 contacts' USING ERRCODE='54000'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_channels) LOOP
 IF jsonb_typeof(r)<>'object' THEN RAISE EXCEPTION 'Object required' USING ERRCODE='22023'; END IF;
 FOR k IN SELECT jsonb_object_keys(r) LOOP
 IF k NOT IN ('id','kind','value_raw','label','is_preferred','accepts_inquiries','is_public') THEN RAISE EXCEPTION 'Unknown field' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF jsonb_typeof(r->'id') IS DISTINCT FROM 'string' OR (r->>'id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 OR jsonb_typeof(r->'kind') IS DISTINCT FROM 'string' OR jsonb_typeof(r->'value_raw') IS DISTINCT FROM 'string'
 OR (r ? 'label' AND jsonb_typeof(r->'label') IS DISTINCT FROM 'string') THEN RAISE EXCEPTION 'Invalid field type' USING ERRCODE='22023'; END IF;
 FOREACH flag IN ARRAY ARRAY['is_preferred','accepts_inquiries','is_public'] LOOP
 IF r ? flag AND jsonb_typeof(r->flag) IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Boolean required' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF coalesce((r->>'is_public')::boolean,false) THEN RAISE EXCEPTION 'Public contacts not enabled' USING ERRCODE='22023'; END IF;
 cid:=(r->>'id')::uuid;
 IF cid=ANY(ids) THEN RAISE EXCEPTION 'Duplicate ID' USING ERRCODE='23505'; END IF;
 IF EXISTS(SELECT 1 FROM public.specialist_contact_channels WHERE id=cid AND specialist_id<>p_specialist_id) THEN RAISE EXCEPTION 'Foreign contact' USING ERRCODE='42501'; END IF;
 ids:=array_append(ids,cid);
 normalized:=public.specialist_channel_normalize(r->>'kind',r->>'value_raw');lbl:=btrim(coalesce(r->>'label',''));
 IF char_length(lbl)>40 OR lbl ~ '[[:cntrl:]]' THEN RAISE EXCEPTION 'Invalid label' USING ERRCODE='22023'; END IF;
 dedup:=(r->>'kind')||'|'||normalized;
 IF dedup=ANY(keys) THEN RAISE EXCEPTION 'Duplicate contact' USING ERRCODE='23505'; END IF;
 keys:=array_append(keys,dedup);
 IF coalesce((r->>'is_preferred')::boolean,false) THEN preferred:=preferred+1;END IF;
 IF preferred>1 THEN RAISE EXCEPTION 'One preferred contact only' USING ERRCODE='22023'; END IF;
 allrows:=allrows||jsonb_build_array(jsonb_build_object('id',cid,'kind',r->>'kind','value_raw',r->>'value_raw','href',normalized,'label',lbl,'sort_order',ord,'is_preferred',coalesce((r->>'is_preferred')::boolean,false),'accepts_inquiries',coalesce((r->>'accepts_inquiries')::boolean,false),'is_public',false));ord:=ord+1;
 END LOOP;
 INSERT INTO public.specialist_channel_sets(specialist_id,version) VALUES(p_specialist_id,1) ON CONFLICT(specialist_id) DO UPDATE SET version=public.specialist_channel_sets.version+1,updated_at=now();
 DELETE FROM public.specialist_contact_channels WHERE specialist_id=p_specialist_id;
 INSERT INTO public.specialist_contact_channels SELECT x.id,p_specialist_id,x.kind,x.value_raw,x.href,x.label,x.sort_order,x.is_preferred,x.accepts_inquiries,x.is_public
 FROM jsonb_to_recordset(allrows) AS x(id uuid,kind text,value_raw text,href text,label text,sort_order integer,is_preferred boolean,accepts_inquiries boolean,is_public boolean);
 RETURN public.list_my_specialist_channels(p_specialist_id);
END $function$
;
REVOKE ALL ON FUNCTION public.save_my_specialist_channels(uuid,integer,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.save_my_specialist_channels(uuid,integer,jsonb) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.save_my_specialist_service(p_specialist_id uuid, p_service_id uuid, p_name text, p_description text DEFAULT NULL::text, p_price_from numeric DEFAULT NULL::numeric, p_price_to numeric DEFAULT NULL::numeric, p_currency text DEFAULT 'RUB'::text, p_duration_minutes integer DEFAULT NULL::integer, p_is_active boolean DEFAULT true, p_version integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v public.specialist_services; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF p_service_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Service id required'; END IF;
 SELECT * INTO v FROM public.specialist_services WHERE id=p_service_id AND specialist_id=p_specialist_id FOR UPDATE;
 IF FOUND THEN
  IF p_version IS DISTINCT FROM v.version THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Reload changed service'; END IF;
  UPDATE public.specialist_services SET name=btrim(p_name),description=nullif(btrim(p_description),''),price_from=p_price_from,price_to=p_price_to,currency=p_currency,duration_minutes=p_duration_minutes,is_active=p_is_active,version=version+1,updated_at=now() WHERE id=p_service_id RETURNING * INTO v;
 ELSE
  IF EXISTS(SELECT FROM public.specialist_services WHERE id=p_service_id) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Service unavailable'; END IF;
  IF p_version IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Service no longer exists'; END IF;
  IF (SELECT count(*) FROM public.specialist_services WHERE specialist_id=p_specialist_id)>=50 THEN RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Service limit reached'; END IF;
  INSERT INTO public.specialist_services(id,specialist_id,name,description,price_from,price_to,currency,duration_minutes,is_active) VALUES(p_service_id,p_specialist_id,btrim(p_name),nullif(btrim(p_description),''),p_price_from,p_price_to,p_currency,p_duration_minutes,p_is_active) RETURNING * INTO v;
 END IF; RETURN to_jsonb(v); END;
$function$
;
REVOKE ALL ON FUNCTION public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.save_my_specialist_settings(p_specialist_id uuid, p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_website text DEFAULT NULL::text, p_work_formats text[] DEFAULT '{}'::text[], p_service_area text DEFAULT NULL::text, p_qualifications text DEFAULT NULL::text, p_version integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v public.specialist_settings; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 SELECT * INTO v FROM public.specialist_settings WHERE specialist_id=p_specialist_id FOR UPDATE;
 IF coalesce(v.version,0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Reload changed contacts'; END IF;
 INSERT INTO public.specialist_settings(specialist_id,phone,email,website,work_formats,service_area,qualifications)
 VALUES(p_specialist_id,nullif(btrim(p_phone),''),nullif(btrim(p_email),''),nullif(btrim(p_website),''),p_work_formats,nullif(btrim(p_service_area),''),nullif(btrim(p_qualifications),''))
 ON CONFLICT(specialist_id) DO UPDATE SET phone=excluded.phone,email=excluded.email,website=excluded.website,work_formats=excluded.work_formats,service_area=excluded.service_area,qualifications=excluded.qualifications,version=specialist_settings.version+1,updated_at=now() RETURNING * INTO v;
 RETURN to_jsonb(v); END;
$function$
;
REVOKE ALL ON FUNCTION public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer) TO service_role,authenticated;
CREATE OR REPLACE FUNCTION public.specialist_channel_normalize(p_kind text, p_value text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE s text:=btrim(p_value); m text[]; host text; path text; q text; segment text;
BEGIN
 IF p_kind IS NULL OR p_kind NOT IN ('telegram','max','vk','whatsapp','ok','website','portfolio')
 OR s IS NULL OR s='' OR char_length(s)>500 OR s ~ '[^!-~]' OR s ~ $r$[\\<>"']$r$
 OR s ~* '%(0[0-9a-f]|1[0-9a-f]|7f|5c|3c|3e|22|27)' THEN RAISE EXCEPTION 'Invalid contact' USING ERRCODE='22023'; END IF;
 IF p_kind='telegram' AND s ~ '^@[A-Za-z][A-Za-z0-9_]{0,31}$' THEN s:='https://t.me/'||substr(s,2); END IF;
 IF p_kind='whatsapp' AND s ~ '^\+[1-9][0-9]{7,14}$' THEN s:='https://wa.me/'||ltrim(s,'+'); END IF;
 m:=regexp_match(s,'^https://([^/?#]+)([^?#]*)(\?[^#]*)?$');
 IF s ~* '%([^0-9a-f]|[0-9a-f]([^0-9a-f]|$)|$)' OR s ~* '(/|%2f)(\.|%2e){1,2}(/|%2f|\?|$)' THEN RAISE EXCEPTION 'Invalid URL path' USING ERRCODE='22023'; END IF;
 IF m IS NULL THEN RAISE EXCEPTION 'HTTPS URL required' USING ERRCODE='22023'; END IF;
 host:=lower(m[1]);path:=coalesce(nullif(m[2],''),'/');q:=coalesce(m[3],'');
 IF char_length(host)>253 OR host !~ '\.[a-z]{2,63}$' OR host ~ '\.(local|localhost|internal|invalid|test|example)$' THEN RAISE EXCEPTION 'Invalid host' USING ERRCODE='22023'; END IF;
 FOREACH segment IN ARRAY string_to_array(host,'.') LOOP
 IF segment !~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' OR segment LIKE 'xn--%' THEN RAISE EXCEPTION 'Invalid host label' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF p_kind='telegram' THEN
 IF host NOT IN ('t.me','telegram.me') OR path !~ '^/[A-Za-z][A-Za-z0-9_]{0,31}/?$' OR q<>'' OR replace(path,'/','') ~* '^(share|proxy|socks|login|joinchat|addstickers|addemoji|boost|giftcode|invoice|iv|c|s|bg|contact|confirmphone|setlanguage)$' THEN RAISE EXCEPTION 'Invalid Telegram profile' USING ERRCODE='22023';END IF;
 host:='t.me';path:='/'||lower(replace(path,'/',''));
 ELSIF p_kind='whatsapp' THEN
 IF host<>'wa.me' OR path !~ '^/[1-9][0-9]{7,14}$' OR q<>'' THEN RAISE EXCEPTION 'Invalid WhatsApp number' USING ERRCODE='22023'; END IF;
 ELSIF p_kind='vk' THEN
 IF host NOT IN ('vk.com','m.vk.com') OR path !~ '^/[A-Za-z0-9_.-]+/?$' OR q<>'' OR path ~* '^/(away(\.php)?|login|oauth|share|cc)/?$' THEN RAISE EXCEPTION 'Invalid VK profile' USING ERRCODE='22023'; END IF;
 host:='vk.com';path:=lower(rtrim(path,'/'));
 ELSIF p_kind='ok' THEN
 IF host NOT IN ('ok.ru','m.ok.ru') OR path !~ '^/(profile/[0-9]+|[A-Za-z0-9_.-]+)/?$' OR q<>'' OR path ~* '^/(dk|login|help|outlink|away)/?$' THEN RAISE EXCEPTION 'Invalid OK profile' USING ERRCODE='22023'; END IF;
 host:='ok.ru';path:=lower(rtrim(path,'/'));
 ELSIF p_kind='max' THEN
 IF host<>'max.ru' OR path='/' OR q<>'' THEN RAISE EXCEPTION 'Copied MAX profile URL required' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN 'https://'||host||path||q;
END $function$
;
REVOKE ALL ON FUNCTION public.specialist_channel_normalize(text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.specialist_channel_normalize(text,text) TO service_role;
CREATE OR REPLACE FUNCTION public.update_my_specialist_draft(p_id uuid, p_display_name text, p_profession text, p_specialization text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_description text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_uid uuid := auth.uid(); v_id uuid;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 IF char_length(btrim(coalesce(p_display_name,''))) NOT BETWEEN 2 AND 150 OR char_length(btrim(coalesce(p_profession,''))) NOT BETWEEN 1 AND 120 OR char_length(coalesce(p_specialization,'')) > 160 OR char_length(coalesce(p_city,'')) > 120 OR char_length(coalesce(p_description,'')) > 2000 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid fields'; END IF;
 UPDATE public.specialist_profiles SET display_name=btrim(p_display_name),profession=nullif(btrim(coalesce(p_profession,'')),''),specialization=nullif(btrim(coalesce(p_specialization,'')),''),city=nullif(btrim(coalesce(p_city,'')),''),description=nullif(btrim(coalesce(p_description,'')),''),updated_at=now() WHERE id=p_id AND owner_user_id=v_uid AND profile_status='draft' RETURNING id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft not found or access denied'; END IF;
 RETURN jsonb_build_object('id',v_id,'profile_status','draft');
END
$function$
;
REVOKE ALL ON FUNCTION public.update_my_specialist_draft(uuid,text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.update_my_specialist_draft(uuid,text,text,text,text,text) TO service_role,authenticated;
