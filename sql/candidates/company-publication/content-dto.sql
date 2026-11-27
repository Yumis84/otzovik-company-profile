BEGIN;
-- Existing canonical native-content readers are required; absent readers fail installation.
DO $$ BEGIN
 IF to_regprocedure('private.get_public_reviews_v1(uuid)') IS NULL OR to_regprocedure('private.get_public_official_qna_v1(uuid)') IS NULL THEN
  RAISE EXCEPTION 'canonical native content readers required';
 END IF;
END $$;
CREATE FUNCTION private.get_company_complete_candidate_v1(p_slug text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
WITH base AS (SELECT private.get_company_base_candidate_v1(p_slug) d),
visible AS (SELECT d,(d->>'id')::uuid id FROM base WHERE d IS NOT NULL),
native AS (
 SELECT v.id,coalesce(jsonb_agg(x.item ORDER BY x.item->>'published_at' DESC,x.item->>'id') FILTER(WHERE x.item IS NOT NULL),'[]'::jsonb) items
 FROM visible v LEFT JOIN LATERAL (
  SELECT j.item FROM jsonb_array_elements(private.get_public_reviews_v1(v.id)) j(item)
  JOIN public.reviews r ON r.id=(j.item->>'id')::uuid AND r.company_id=v.id AND r.status='published'
  JOIN public.review_sources s ON s.id=r.source_id AND s.company_id=v.id AND s.status='published' AND s.source_type='first_party_reviews'
  WHERE (r.location_id IS NULL OR EXISTS(SELECT 1 FROM public.company_locations l WHERE l.id=r.location_id AND l.company_id=v.id AND l.status='published'))
   AND NOT EXISTS(SELECT 1 FROM private.review_revisions_v1 rr WHERE rr.company_id=v.id AND rr.review_id=r.id AND (rr.erased_at IS NOT NULL OR rr.redaction_status='erased'))
 ) x ON true GROUP BY v.id
)
SELECT v.d || jsonb_build_object('sources',private.get_company_sources_candidate(v.id),
 'reviews',n.items,'questions_answers',private.get_public_official_qna_v1(v.id),
 'native_rating',jsonb_build_object('rating',(SELECT round(avg((j->>'rating')::numeric),2) FROM jsonb_array_elements(n.items) j WHERE j->>'rating' IS NOT NULL AND (j->>'rating_scale')::numeric=5),'rating_scale',5,'review_count',jsonb_array_length(n.items)))
FROM visible v JOIN native n ON n.id=v.id;
$$;
REVOKE ALL ON FUNCTION private.get_company_complete_candidate_v1(text) FROM PUBLIC,anon,authenticated;
COMMIT;
