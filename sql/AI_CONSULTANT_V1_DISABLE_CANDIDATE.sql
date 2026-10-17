BEGIN;
UPDATE ai_private.platform SET disabled=true;
UPDATE ai_private.configs SET enabled=false;
DELETE FROM ai_private.sessions;
REVOKE EXECUTE ON FUNCTION public.save_my_ai_config(text,uuid,integer,jsonb) FROM authenticated;
COMMIT;
