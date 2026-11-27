-- Read-only captured canonical definition, production catalog 2026-11-27. Never auto-apply.
CREATE OR REPLACE FUNCTION private.get_public_reviews_v1(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'private', 'public'
AS $function$
select coalesce(jsonb_agg(jsonb_build_object(
'id',r.id,'source_id',r.source_id,'location_id',r.location_id,'source_review_id',r.source_review_id,'source_url',r.source_url,'author',r.author_display_name,'published_at',r.published_at,'collected_at',r.collected_at,'rating',r.rating,'rating_scale',r.rating_scale,'body',coalesce(rr.body_public,r.body),'excerpt',r.excerpt,'language',coalesce(rr.language,r.language),'provenance',r.provenance,
'company_response',(select jsonb_build_object('statement',sr.body,'published_at',sr.published_at) from private.official_statements_v2 os join private.statement_revisions_v2 sr on sr.company_id=os.company_id and sr.id=os.current_published_revision_id where os.company_id=r.company_id and os.review_id=r.id and sr.status='published' limit 1)
) order by r.published_at desc nulls last),'[]'::jsonb)
from public.reviews r join public.review_sources rs on rs.id=r.source_id
left join lateral (select x.body_public,x.language from private.review_revisions_v1 x where x.company_id=r.company_id and x.review_id=r.id and x.erased_at is null and x.redaction_status<>'erased' order by x.version desc limit 1) rr on true
where r.company_id=p_company_id and r.status='published' and rs.source_type='first_party_reviews'
$function$
;
