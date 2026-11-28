-- Read-only captured canonical definition, production catalog 2026-11-27. Never auto-apply.
CREATE OR REPLACE FUNCTION private.get_public_official_qna_v1(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'private', 'public'
AS $function$
select coalesce(jsonb_agg(jsonb_build_object(
'id',coalesce(q.legacy_qna_id,q.id),'question_id',q.id,'question',qr.body_public,'answer',sr.body,'language',qr.language,'answered_at',q.answered_at,'published_at',sr.published_at,'updated_at',greatest(q.updated_at,sr.created_at),'category',q.category,'program_label',q.program_label
) order by sr.published_at desc nulls last,q.created_at desc),'[]'::jsonb)
from private.questions_v1 q
join private.question_revisions_v1 qr on qr.company_id=q.company_id and qr.id=q.current_revision_id
join private.official_statements_v2 os on os.company_id=q.company_id and os.question_id=q.id
join private.statement_revisions_v2 sr on sr.company_id=os.company_id and sr.id=os.current_published_revision_id and sr.status='published'
where q.company_id=p_company_id and q.status not in ('pending','needs_clarification','rejected','merged','hidden','archived') and q.answered_at is not null and qr.erased_at is null and qr.body_public is not null
$function$
;
