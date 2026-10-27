-- REVIEW ONLY. Company untouched; existing specialist read/edit retained.
BEGIN;
REVOKE EXECUTE ON FUNCTION public.create_my_specialist_draft(text,text,text,text,text,text) FROM authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
