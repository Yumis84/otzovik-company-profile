-- Staging candidate. Requires the v1 publication, editor, channels and upload gateway schemas.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE public.specialist_revision_details_v1 (
 specialist_id uuid NOT NULL, revision_id uuid NOT NULL, items jsonb NOT NULL,
 PRIMARY KEY(specialist_id,revision_id),
 FOREIGN KEY(specialist_id,revision_id) REFERENCES public.specialist_public_revisions ON DELETE CASCADE
);
ALTER TABLE public.specialist_revision_details_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_revision_details_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_revision_details_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.get_my_specialist_public_options_v1(p_specialist_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft') THEN
  RAISE insufficient_privilege;
 END IF;
 RETURN (SELECT coalesce(jsonb_agg(item ORDER BY section, sort, id),'[]') FROM (
 SELECT 1 AS section,0 AS sort,id,jsonb_build_object('type','service','name',name,'description',description,'from',price_from,'to',price_to,'currency',currency) AS item
 FROM public.specialist_services WHERE specialist_id=p_specialist_id AND is_active
 UNION ALL SELECT 2,sort_order,id,jsonb_build_object('type','contact','label',coalesce(nullif(label,''),kind),'href',href)
 FROM public.specialist_contact_channels WHERE specialist_id=p_specialist_id
 UNION ALL SELECT 3,0,m.id,jsonb_build_object('type','photo','id',m.id,'caption',m.caption,'kind',m.kind)
 FROM public.specialist_media m JOIN public.specialist_upload_reservations u ON u.specialist_id=m.specialist_id AND u.object_name=m.object_name AND u.state='ready'
 WHERE m.specialist_id=p_specialist_id
 ) options);
END $$;
REVOKE ALL ON FUNCTION public.get_my_specialist_public_options_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_specialist_public_options_v1(uuid) TO authenticated;

CREATE FUNCTION public.publish_my_specialist_details_v1(p_specialist_id uuid,p_expected_version integer,p_request_id uuid,p_items jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE receipt jsonb; options jsonb; stored jsonb;
BEGIN
 IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR octet_length(p_items::text)>262144 THEN RAISE invalid_parameter_value; END IF;
 IF jsonb_array_length(p_items)>100 THEN RAISE invalid_parameter_value; END IF;
 -- Underlying v1 holds the profile lock, authorizes owner, checks CAS and performs replay handling.
 receipt:=public.publish_my_specialist_v1(p_specialist_id,p_expected_version,p_request_id);
 IF (receipt->>'replayed')::boolean THEN
  SELECT items INTO stored FROM public.specialist_revision_details_v1 WHERE specialist_id=p_specialist_id AND revision_id=(receipt->>'revision_id')::uuid;
  IF coalesce(stored,'[]')<>p_items AND (receipt->>'published')::boolean THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Selection changed'; END IF;
  RETURN receipt;
 END IF;
 options:=public.get_my_specialist_public_options_v1(p_specialist_id);
 IF EXISTS(SELECT FROM jsonb_array_elements(p_items) x WHERE NOT EXISTS(SELECT FROM jsonb_array_elements(options) y WHERE y.value=x.value)) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Refresh publication options';
 END IF;
 INSERT INTO public.specialist_revision_details_v1 VALUES(p_specialist_id,(receipt->>'revision_id')::uuid,p_items);
 RETURN receipt;
END $$;
REVOKE ALL ON FUNCTION public.publish_my_specialist_details_v1(uuid,integer,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.publish_my_specialist_details_v1(uuid,integer,uuid,jsonb) TO authenticated;
CREATE OR REPLACE FUNCTION public.get_public_specialist_v1(p_slug text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $getter$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RETURN NULL; END IF;
 IF p_slug IS NULL OR p_slug<>pg_catalog.lower(pg_catalog.btrim(p_slug)) OR p_slug !~ '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$' OR position('--' IN p_slug)>0 THEN RETURN NULL; END IF;
 IF NOT coalesce((SELECT enabled FROM public.specialist_public_control WHERE singleton),false) THEN RETURN NULL; END IF;
 SELECT jsonb_build_object('slug',r.slug,'display_name',r.display_name,'profession',r.profession,'specialization',r.specialization,'city',r.city,'description',r.description,'items',coalesce(d.items,'[]'))
 INTO result FROM public.specialist_public_revisions r
 LEFT JOIN public.specialist_revision_details_v1 d USING(specialist_id,revision_id)
 JOIN public.specialist_publication_state s ON s.specialist_id=r.specialist_id AND s.published_revision_id=r.revision_id AND s.state='published'
 JOIN public.specialist_profiles p ON p.id=s.specialist_id AND p.profile_status='draft'
 WHERE r.slug=p_slug;
 RETURN result;
END $getter$;
REVOKE ALL ON FUNCTION public.get_public_specialist_v1(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_public_specialist_v1(text) TO anon,authenticated;
-- Service-only resolution. Never accept a bucket or object path from the guest.
CREATE FUNCTION public.resolve_public_specialist_photo_v1(p_slug text,p_photo uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT m.object_name FROM public.specialist_media m
 JOIN public.specialist_profiles p ON p.id=m.specialist_id AND p.slug=p_slug
 JOIN public.specialist_upload_reservations u ON u.specialist_id=m.specialist_id AND u.object_name=m.object_name AND u.state='ready'
 WHERE m.id=p_photo AND EXISTS (
 SELECT FROM jsonb_array_elements(public.get_public_specialist_v1(p_slug)->'items') x
 WHERE x->>'type'='photo' AND x->>'id'=p_photo::text)
$$;
REVOKE ALL ON FUNCTION public.resolve_public_specialist_photo_v1(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.resolve_public_specialist_photo_v1(text,uuid) TO service_role;
COMMIT;
