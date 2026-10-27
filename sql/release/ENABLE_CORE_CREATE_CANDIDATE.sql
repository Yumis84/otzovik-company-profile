-- REVIEW ONLY. Requires approved definition/ACL snapshot.
BEGIN;
GRANT EXECUTE ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
