-- Restores owner preview only; no profile or public activation.
BEGIN;
DO $guard$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN
 RAISE EXCEPTION 'AI candidate requires trusted BYPASSRLS deployment role' USING ERRCODE='42501';
 END IF;
END $guard$;
GRANT EXECUTE ON FUNCTION public.save_my_ai_config(text,uuid,integer,jsonb) TO authenticated;
UPDATE ai_private.platform SET disabled=false WHERE singleton;
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM ai_private.platform WHERE singleton AND NOT disabled) THEN RAISE EXCEPTION 'Platform singleton missing'; END IF; END $$;
COMMIT;
