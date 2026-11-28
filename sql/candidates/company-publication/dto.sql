BEGIN;
CREATE FUNCTION private.get_company_base_candidate_v1(p_slug text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
SELECT jsonb_build_object('id',c.id,'slug',c.slug,'name',c.name,'description',c.description,'legal_name',c.legal_name,'website',c.website,'phone',c.phone,'city',c.city,'profile_status',c.profile_status,'updated_at',c.updated_at,
'locations',coalesce((SELECT jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'relationship_type',l.relationship_type,'address',l.canonical_address,'city',l.city,'phone',l.phone,'hours',l.hours,'official_url',l.official_url,'source_url',l.source_url,'verified_at',l.verified_at) ORDER BY l.id) FROM public.company_locations l WHERE l.company_id=c.id AND l.status='published'),'[]'::jsonb),
'services',coalesce((SELECT jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'category',s.category,'description',s.description,'official_url',s.official_url,'source_url',s.source_url,'verified_at',s.verified_at) ORDER BY s.id) FROM public.company_services s WHERE s.company_id=c.id AND s.status='published'),'[]'::jsonb),
'media',coalesce((SELECT jsonb_agg(jsonb_build_object('id',m.id,'type',m.media_type,'object_name',m.storage_object_name,'sort_order',m.sort_order,'alt',m.alt_text,'caption',m.caption,'updated_at',m.updated_at) ORDER BY m.sort_order,m.id) FROM public.company_media m WHERE m.company_id=c.id AND m.status='published'),'[]'::jsonb))
FROM public.companies c WHERE c.id=private.resolve_public_company_id_v1(p_slug);
$$;
REVOKE ALL ON FUNCTION private.get_company_base_candidate_v1(text) FROM PUBLIC,anon,authenticated;
COMMIT;
