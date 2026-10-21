BEGIN;
DO $guard$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN
 RAISE EXCEPTION 'AI candidate requires trusted BYPASSRLS deployment role' USING ERRCODE='42501';
 END IF;
END $guard$;
UPDATE ai_private.platform SET disabled=true;
UPDATE ai_private.configs SET enabled=false;
DELETE FROM ai_private.sessions;
REVOKE EXECUTE ON FUNCTION public.save_my_ai_config(text,uuid,integer,jsonb) FROM authenticated;
COMMIT;
