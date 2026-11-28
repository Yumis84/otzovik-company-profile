BEGIN;
CREATE OR REPLACE FUNCTION private.get_company_sources_candidate(c uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'url',s.profile_url,'rating',r.rating,'rating_scale',r.rating_scale,'rating_count',r.rating_count,'review_count',r.review_count,'checked_at',r.checked_at) ORDER BY s.id),'[]'::jsonb)
FROM public.review_sources s LEFT JOIN LATERAL (SELECT rating,rating_scale,rating_count,review_count,checked_at FROM public.source_ratings WHERE source_id=s.id AND status='published' ORDER BY checked_at DESC,id DESC LIMIT 1) r ON true
WHERE s.company_id=c AND s.status='published' AND (s.location_id IS NULL OR EXISTS(SELECT 1 FROM public.company_locations l WHERE l.id=s.location_id AND l.company_id=c AND l.status='published')) AND private.is_company_publicly_readable_v1(c)
$$;
REVOKE ALL ON FUNCTION private.get_company_sources_candidate(uuid) FROM PUBLIC,anon,authenticated;
COMMIT;
