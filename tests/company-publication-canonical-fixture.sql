-- Synthetic disposable fixture. Reader definitions are captured separately from the canonical catalog.
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.uid',true),'')::uuid $$;
CREATE TABLE public.company_memberships(company_id uuid,user_id uuid,role text,verification_status text,UNIQUE(company_id,user_id));
INSERT INTO public.company_memberships VALUES('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','owner','verified');
CREATE TABLE private.review_revisions_v1(company_id uuid,review_id uuid,version int,body_public text,language text,erased_at timestamptz,redaction_status text);
CREATE TABLE private.questions_v1(id uuid,company_id uuid,legacy_qna_id uuid,current_revision_id uuid,status text,answered_at timestamptz,category text,program_label text,created_at timestamptz,updated_at timestamptz);
CREATE TABLE private.question_revisions_v1(id uuid,company_id uuid,body_public text,language text,erased_at timestamptz);
CREATE TABLE private.official_statements_v2(company_id uuid,question_id uuid,review_id uuid,current_published_revision_id uuid);
CREATE TABLE private.statement_revisions_v2(id uuid,company_id uuid,body text,status text,published_at timestamptz,created_at timestamptz);
