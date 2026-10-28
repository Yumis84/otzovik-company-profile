-- REVIEW CANDIDATE ONLY. PR39 delta. No hosted apply or automatic migration.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN
 IF EXISTS(SELECT FROM pg_roles WHERE rolname='specialist_operator') OR to_regclass('public.specialist_operator_identities') IS NOT NULL THEN RAISE EXCEPTION 'Operator installation drift; stop and review'; END IF;
 IF md5(pg_get_functiondef('public.specialist_gateway_force_retire(uuid,uuid,uuid,text,text,text,jsonb)'::regprocedure)) IS DISTINCT FROM 'c84009d7cc02a661ac9335bcef7a2cb4' THEN
  -- Exact PR39 definition pin is populated from the committed catalog by the build helper.
  RAISE EXCEPTION 'PR39 force_retire definition drift';
 END IF;
END $$;
CREATE ROLE specialist_operator NOLOGIN NOINHERIT NOBYPASSRLS NOCREATEDB NOCREATEROLE;
GRANT USAGE ON SCHEMA public,storage TO specialist_operator;
DO $$ BEGIN IF EXISTS(SELECT FROM pg_roles WHERE rolname='authenticator') THEN GRANT specialist_operator TO authenticator; END IF; END $$;
CREATE TABLE public.specialist_operator_identities(user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,enabled boolean NOT NULL DEFAULT true);
CREATE TABLE public.specialist_erasure_confirmations(id uuid PRIMARY KEY,profile_id uuid NOT NULL,owner_user_id uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),expires_at timestamptz NOT NULL DEFAULT now()+interval '15 minutes');
CREATE TABLE public.specialist_erasure_authorizations(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),profile_id uuid NOT NULL,request_id uuid,purpose text NOT NULL CHECK(purpose IN ('profile_erasure','orphan_cleanup')),approved_by uuid NOT NULL,confirmation_id uuid,ticket text NOT NULL CHECK(ticket ~ '^OTZ-[A-Z0-9-]{8,100}$'),created_at timestamptz NOT NULL DEFAULT now(),expires_at timestamptz NOT NULL);
ALTER TABLE public.specialist_operator_identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_operator_identities FORCE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_erasure_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_erasure_confirmations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_erasure_authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_erasure_authorizations FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_operator_identities,public.specialist_erasure_confirmations,public.specialist_erasure_authorizations FROM PUBLIC,anon,authenticated,service_role,specialist_operator;
ALTER TABLE public.specialist_upload_audit DROP CONSTRAINT specialist_upload_audit_action_check;
ALTER TABLE public.specialist_upload_audit ADD CONSTRAINT specialist_upload_audit_action_check CHECK(action IN ('definite_rejection','operator_begin','operator_finish','orphan_begin','orphan_finish'));
-- Database-enforced consumption: a reviewed orphan authorization may open only one begin.
CREATE UNIQUE INDEX specialist_orphan_authorization_once ON public.specialist_upload_audit (((evidence->>'authorization_id')::uuid)) WHERE action='orphan_begin';
REVOKE ALL ON public.specialist_upload_audit FROM specialist_operator;
CREATE FUNCTION public.confirm_my_specialist_erasure(p_specialist_id uuid,p_confirmation_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $confirm$
DECLARE r public.specialist_erasure_confirmations;
BEGIN
 IF auth.uid() IS NULL OR p_confirmation_id IS NULL OR NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 INSERT INTO public.specialist_erasure_confirmations(id,profile_id,owner_user_id) VALUES(p_confirmation_id,p_specialist_id,auth.uid()) ON CONFLICT(id) DO NOTHING;
 SELECT * INTO r FROM public.specialist_erasure_confirmations WHERE id=p_confirmation_id AND profile_id=p_specialist_id AND owner_user_id=auth.uid() AND expires_at>now();
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Confirmation unavailable or expired'; END IF;
 RETURN jsonb_build_object('confirmation_id',r.id,'expires_at',r.expires_at);
END $confirm$;
REVOKE ALL ON FUNCTION public.confirm_my_specialist_erasure(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.confirm_my_specialist_erasure(uuid,uuid) TO authenticated;
CREATE FUNCTION public.specialist_operator_authorize(p_specialist_id uuid,p_confirmation_id uuid,p_request_id uuid,p_purpose text,p_ticket text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $authorize$
DECLARE v_result public.specialist_erasure_authorizations; deadline timestamptz;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_operator_identities WHERE user_id=auth.uid() AND enabled) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Registered operator required'; END IF;
 IF p_ticket IS NULL OR p_ticket !~ '^OTZ-[A-Z0-9-]{8,100}$' OR p_purpose IS NULL OR p_purpose NOT IN ('profile_erasure','orphan_cleanup') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid reviewed authorization'; END IF;
 IF p_purpose='profile_erasure' THEN
  SELECT c.expires_at INTO deadline FROM public.specialist_erasure_confirmations c JOIN public.specialist_profiles p ON p.id=c.profile_id AND p.owner_user_id=c.owner_user_id AND p.profile_status='draft' WHERE c.id=p_confirmation_id AND c.profile_id=p_specialist_id AND c.expires_at>now();
  IF NOT FOUND OR p_request_id IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Live owner confirmation required'; END IF;
 ELSE
  IF p_confirmation_id IS NOT NULL OR EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id) OR NOT EXISTS(SELECT FROM public.specialist_upload_reservations r WHERE r.id=p_request_id AND r.profile_id=p_specialist_id AND r.state='deleted' AND r.specialist_id IS NULL AND EXISTS(SELECT FROM public.specialist_upload_audit a WHERE a.request_id=r.id AND a.profile_id=r.profile_id)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Audited deleted-profile tombstone required'; END IF;
  deadline:=now()+interval '15 minutes';
 END IF;
 INSERT INTO public.specialist_erasure_authorizations(profile_id,request_id,purpose,approved_by,confirmation_id,ticket,expires_at) VALUES(p_specialist_id,p_request_id,p_purpose,auth.uid(),p_confirmation_id,p_ticket,deadline) RETURNING * INTO v_result;
 RETURN jsonb_build_object('authorization_id',v_result.id,'approved_by',v_result.approved_by,'expires_at',v_result.expires_at);
END $authorize$;
CREATE FUNCTION public.specialist_operator_check(p_authorization_id uuid,p_specialist_id uuid,p_request_id uuid,p_purpose text,p_resume boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $check$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_operator_identities WHERE user_id=auth.uid() AND enabled) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Registered operator required'; END IF;
 IF NOT EXISTS(SELECT FROM public.specialist_erasure_authorizations WHERE id=p_authorization_id AND profile_id=p_specialist_id AND purpose=p_purpose AND (request_id IS NULL OR request_id=p_request_id) AND approved_by<>auth.uid() AND (expires_at>now() OR p_resume)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Independent reviewed authorization required'; END IF;
 RETURN auth.uid();
END $check$;
CREATE FUNCTION public.specialist_operator_plan_erasure(p_owner uuid,p_specialist_id uuid,p_authorization_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $plan$
DECLARE o record;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 PERFORM public.specialist_operator_check(p_authorization_id,p_specialist_id,NULL,'profile_erasure');
 IF (SELECT enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Disable admission first'; END IF;
 FOR o IN SELECT name FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text LOOP
  IF o.name !~ '^[0-9a-f-]{36}/(avatar|portfolio)/[0-9a-f-]{36}[.](png|jpg|jpeg|webp)$' THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Unexpected legacy path requires review'; END IF;
  INSERT INTO public.specialist_upload_reservations(id,profile_id,specialist_id,object_name,kind,state) SELECT gen_random_uuid(),p_specialist_id,p_specialist_id,o.name,split_part(o.name,'/',2),'ready' WHERE NOT EXISTS(SELECT FROM public.specialist_upload_reservations WHERE object_name=o.name);
 END LOOP;
 RETURN public.specialist_gateway_erasure_inventory(p_owner,p_specialist_id)||jsonb_build_object('planned',true,'authorization_id',p_authorization_id);
END $plan$;
CREATE FUNCTION public.specialist_operator_cleanup_orphan(p_request_id uuid,p_phase text,p_proof jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $orphan$
DECLARE r public.specialist_upload_reservations; v_actor uuid; resumed boolean; completed boolean;
BEGIN
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Tombstone unavailable'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||r.profile_id::text,0));
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id FOR UPDATE;
 IF EXISTS(SELECT FROM public.specialist_profiles WHERE id=r.profile_id) OR r.state<>'deleted' OR r.specialist_id IS NOT NULL OR NOT EXISTS(SELECT FROM public.specialist_upload_audit WHERE request_id=r.id AND profile_id=r.profile_id) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Audited deleted-profile tombstone required'; END IF;
 IF (SELECT enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Disable admission first'; END IF;
 IF p_phase IS NULL OR p_phase NOT IN ('begin','finish') OR p_proof IS NULL OR jsonb_typeof(p_proof)<>'object' OR octet_length(p_proof::text)>8192 OR p_proof->>'mode' IS DISTINCT FROM 'orphan_cleanup' OR p_proof->>'request_id' IS DISTINCT FROM r.id::text OR p_proof->'all_writers_stopped' IS DISTINCT FROM 'true'::jsonb OR coalesce(p_proof->>'kind','') NOT IN ('provider_terminal_no_late_writer','credentials_revoked_all_writers_drained') OR coalesce(char_length(p_proof->>'evidence_ref'),0) NOT BETWEEN 8 AND 1000 OR coalesce(p_proof->>'authorization_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Reviewed writer-stop evidence required'; END IF;
 completed:=EXISTS(SELECT FROM public.specialist_upload_audit WHERE request_id=r.id AND action='orphan_finish' AND evidence=p_proof AND actor=auth.uid()::text);
 resumed:=EXISTS(SELECT FROM public.specialist_upload_audit a WHERE a.request_id=r.id AND a.action='orphan_begin' AND a.evidence=p_proof AND a.actor=auth.uid()::text AND (p_phase='finish' OR NOT EXISTS(SELECT FROM public.specialist_upload_audit z WHERE z.request_id=r.id AND z.action='orphan_finish' AND z.evidence=p_proof AND z.actor=a.actor AND z.created_at>=a.created_at)));
 -- Serialize all uses of this authorization, including different proof values.
 PERFORM 1 FROM public.specialist_erasure_authorizations WHERE id=(p_proof->>'authorization_id')::uuid FOR UPDATE;
 v_actor:=public.specialist_operator_check((p_proof->>'authorization_id')::uuid,r.profile_id,r.id,'orphan_cleanup',resumed OR (completed AND NOT EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name)));
 IF p_phase='begin' AND NOT completed THEN
  IF resumed THEN
   IF NOT EXISTS(SELECT FROM public.specialist_erasure_authorizations WHERE id=(p_proof->>'authorization_id')::uuid AND expires_at>clock_timestamp()) OR NOT EXISTS(SELECT FROM public.specialist_upload_audit WHERE request_id=r.id AND action='orphan_begin' AND evidence=p_proof AND actor=v_actor::text AND created_at>clock_timestamp()-interval '15 minutes') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Begin expired; fresh authorization required'; END IF;
   RETURN jsonb_build_object('deleted',false,'object_name',r.object_name);
  END IF;
  IF EXISTS(SELECT FROM public.specialist_upload_audit WHERE action='orphan_begin' AND evidence->>'authorization_id'=p_proof->>'authorization_id') THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Authorization already consumed'; END IF;
 END IF;
 IF p_phase='begin' AND completed THEN
  IF EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='New late object needs fresh authorization and proof'; END IF;
  RETURN jsonb_build_object('deleted',true,'object_name',r.object_name);
 END IF;
 IF p_phase='finish' THEN
  IF NOT resumed OR EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Audited begin and Storage deletion required'; END IF;
  IF EXISTS(SELECT FROM public.specialist_upload_audit WHERE request_id=r.id AND action='orphan_finish' AND evidence=p_proof AND actor=v_actor::text) THEN RETURN jsonb_build_object('deleted',true); END IF;
 END IF;
 INSERT INTO public.specialist_upload_audit(request_id,profile_id,action,actor,reason,evidence) VALUES(r.id,r.profile_id,CASE p_phase WHEN 'begin' THEN 'orphan_begin' ELSE 'orphan_finish' END,v_actor::text,'Authorized deleted-profile orphan cleanup',p_proof);
 RETURN jsonb_build_object('deleted',p_phase='finish','object_name',r.object_name);
END $orphan$;
CREATE FUNCTION public.can_operator_remove_specialist_object(p_name text) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $remove$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT FROM public.specialist_operator_identities WHERE user_id=auth.uid() AND enabled) AND EXISTS(
 SELECT FROM public.specialist_upload_reservations r JOIN public.specialist_upload_audit a ON a.request_id=r.id AND a.profile_id=r.profile_id
 WHERE r.object_name=p_name AND a.actor=auth.uid()::text
 AND a.created_at>clock_timestamp()-interval '15 minutes'
 AND EXISTS(SELECT FROM public.specialist_erasure_authorizations u WHERE u.id::text=a.evidence->>'authorization_id' AND u.profile_id=r.profile_id AND u.approved_by<>auth.uid() AND u.expires_at>clock_timestamp() AND ((a.action='orphan_begin' AND u.purpose='orphan_cleanup' AND u.request_id=r.id) OR (a.action='operator_begin' AND u.purpose='profile_erasure'))) AND (
 (r.state='deleting' AND a.action='operator_begin' AND NOT EXISTS(SELECT FROM public.specialist_upload_audit z WHERE z.request_id=r.id AND z.action='operator_finish' AND z.evidence=a.evidence AND z.actor=a.actor AND z.created_at>=a.created_at)) OR
 (r.state='deleted' AND a.action='orphan_begin' AND NOT EXISTS(SELECT FROM public.specialist_upload_audit z WHERE z.request_id=r.id AND z.action='orphan_finish' AND z.evidence=a.evidence AND z.actor=a.actor AND z.created_at>=a.created_at) AND NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=r.profile_id))))
$remove$;
GRANT SELECT,DELETE ON storage.objects TO specialist_operator;
CREATE POLICY specialist_operator_read ON storage.objects FOR SELECT TO specialist_operator USING(bucket_id='specialist-media' AND public.can_operator_remove_specialist_object(name));
CREATE POLICY specialist_operator_remove ON storage.objects FOR DELETE TO specialist_operator USING(bucket_id='specialist-media' AND public.can_operator_remove_specialist_object(name));
-- Fail closed even if an unrelated permissive policy later grants broad operator access.
CREATE POLICY specialist_operator_scope_read ON storage.objects AS RESTRICTIVE FOR SELECT TO specialist_operator USING(bucket_id='specialist-media' AND public.can_operator_remove_specialist_object(name));
CREATE POLICY specialist_operator_scope_remove ON storage.objects AS RESTRICTIVE FOR DELETE TO specialist_operator USING(bucket_id='specialist-media' AND public.can_operator_remove_specialist_object(name));
DO $acl$ DECLARE r record; BEGIN
 FOR r IN SELECT oid::regprocedure signature FROM pg_proc WHERE pronamespace='public'::regnamespace AND (proname LIKE 'specialist_operator_%' OR proname IN ('can_operator_remove_specialist_object','specialist_gateway_force_retire','specialist_gateway_erasure_inventory')) LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role,specialist_operator',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO specialist_operator',r.signature);
 END LOOP;
END $acl$;
GRANT EXECUTE ON FUNCTION public.specialist_gateway_metrics() TO specialist_operator;
-- Replacement definitions are appended by the build helper, then postconditions compile against PG17.
CREATE OR REPLACE FUNCTION public.specialist_gateway_force_retire(p_owner uuid,p_specialist_id uuid,p_request_id uuid,p_phase text,p_actor text,p_reason text,p_proof jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $retire$
DECLARE r public.specialist_upload_reservations;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF (SELECT enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Disable upload admission before operator retirement'; END IF;
 IF p_phase IS NULL OR p_phase NOT IN ('begin','finish') OR p_reason IS NULL OR char_length(p_reason) NOT BETWEEN 3 AND 500 OR p_proof IS NULL OR jsonb_typeof(p_proof)<>'object' OR octet_length(p_proof::text)>8192
 OR (p_proof->>'kind') IS NULL OR (p_proof->>'kind') NOT IN ('provider_terminal_no_late_writer','credentials_revoked_all_writers_drained')
 OR coalesce(char_length(p_proof->>'evidence_ref'),0) NOT BETWEEN 8 AND 1000
 OR (p_proof->>'request_id') IS DISTINCT FROM p_request_id::text
 OR p_proof->'all_writers_stopped' IS DISTINCT FROM 'true'::jsonb THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Reviewed external no-late-writer evidence required; TTL is not proof';
 END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id AND profile_id=p_specialist_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Upload unavailable'; END IF;
 IF coalesce(p_proof->>'authorization_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR coalesce(p_proof->>'mode','') NOT IN ('quarantine_retire','confirmed_erasure') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Explicit authorized erasure mode required'; END IF;
 IF (r.state='ready' OR EXISTS(SELECT FROM public.specialist_media WHERE object_name=r.object_name)) AND p_proof->>'mode' IS DISTINCT FROM 'confirmed_erasure' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Ready media requires confirmed erasure mode'; END IF;
 p_actor:=public.specialist_operator_check((p_proof->>'authorization_id')::uuid,p_specialist_id,p_request_id,'profile_erasure',EXISTS(SELECT FROM public.specialist_upload_audit a WHERE a.request_id=r.id AND a.action='operator_begin' AND a.evidence=p_proof AND a.actor=auth.uid()::text AND (p_phase='finish' OR NOT EXISTS(SELECT FROM public.specialist_upload_audit z WHERE z.request_id=r.id AND z.action='operator_finish' AND z.evidence=p_proof AND z.actor=a.actor AND z.created_at>=a.created_at))))::text;
 IF r.state='deleted' AND NOT EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name) THEN RETURN jsonb_build_object('retired',true,'object_name',r.object_name); END IF;
 IF p_phase='begin' THEN
  INSERT INTO public.specialist_upload_audit(request_id,profile_id,action,actor,reason,evidence) VALUES(r.id,p_specialist_id,'operator_begin',p_actor,p_reason,p_proof);
  UPDATE public.specialist_upload_reservations SET state='deleting',specialist_id=p_specialist_id WHERE id=r.id;
  RETURN jsonb_build_object('retired',false,'object_name',r.object_name);
 END IF;
 IF r.state<>'deleting' OR NOT EXISTS(SELECT FROM public.specialist_upload_audit WHERE request_id=r.id AND action='operator_begin' AND evidence=p_proof AND actor=p_actor) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Audited begin with same proof required'; END IF;
 IF EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Remove object through Storage API first'; END IF;
 DELETE FROM public.specialist_media WHERE specialist_id=p_specialist_id AND object_name=r.object_name;
 INSERT INTO public.specialist_upload_audit(request_id,profile_id,action,actor,reason,evidence) VALUES(r.id,p_specialist_id,'operator_finish',p_actor,p_reason,p_proof);
 UPDATE public.specialist_upload_reservations SET state='deleted',specialist_id=NULL,fingerprint=NULL,mime=NULL,size_bytes=NULL,caption=NULL WHERE id=r.id;
 RETURN jsonb_build_object('retired',true,'object_name',r.object_name);
END $retire$;
CREATE OR REPLACE FUNCTION public.specialist_gateway_erasure_inventory(p_owner uuid,p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $inventory$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_operator_identities WHERE user_id=auth.uid() AND enabled) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Registered operator required'; END IF;
 IF p_owner IS NULL OR NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 RETURN jsonb_build_object('uploads_enabled',(SELECT enabled FROM public.specialist_upload_control WHERE singleton),
 'reservations',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'object_name',r.object_name,'state',r.state)) FROM public.specialist_upload_reservations r WHERE (r.specialist_id=p_specialist_id AND r.state<>'deleted') OR (r.profile_id=p_specialist_id AND r.state='deleted' AND EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=r.object_name))),'[]'::jsonb),
 'objects',coalesce((SELECT jsonb_agg(name) FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text),'[]'::jsonb));
END $inventory$;
CREATE OR REPLACE FUNCTION public.specialist_gateway_metrics() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $metrics$
 SELECT jsonb_build_object(
 'severity',CASE WHEN EXISTS(SELECT FROM (SELECT split_part(name,'/',1) profile FROM storage.objects WHERE bucket_id='specialist-media' UNION ALL SELECT r.profile_id::text FROM public.specialist_upload_reservations r WHERE r.state<>'deleted' AND NOT EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=r.object_name)) slots GROUP BY profile HAVING count(*)>20) OR EXISTS(SELECT FROM storage.objects o JOIN public.specialist_upload_reservations r ON r.object_name=o.name WHERE o.bucket_id='specialist-media' AND r.state='deleted') THEN 'critical' WHEN EXISTS(SELECT FROM public.specialist_upload_reservations WHERE state='uploading' AND expires_at<now()) THEN 'warning' ELSE 'none' END,
 'critical_over_quota',EXISTS(SELECT FROM (SELECT split_part(name,'/',1) profile FROM storage.objects WHERE bucket_id='specialist-media' UNION ALL SELECT r.profile_id::text FROM public.specialist_upload_reservations r WHERE r.state<>'deleted' AND NOT EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=r.object_name)) slots GROUP BY profile HAVING count(*)>20),
 'warning_quarantine',EXISTS(SELECT FROM public.specialist_upload_reservations WHERE state='uploading' AND expires_at<now()),
 'critical_orphan',EXISTS(SELECT FROM storage.objects o JOIN public.specialist_upload_reservations r ON r.object_name=o.name WHERE o.bucket_id='specialist-media' AND r.state='deleted'),
 'quarantined',(SELECT count(*) FROM public.specialist_upload_reservations WHERE state='uploading' AND expires_at<now()),
 'pending',(SELECT count(*) FROM public.specialist_upload_reservations WHERE state='uploading'),
 'deleting',(SELECT count(*) FROM public.specialist_upload_reservations WHERE state='deleting'),
 'definite_rejections',(SELECT count(*) FROM public.specialist_upload_audit WHERE action='definite_rejection'),
 'operator_retirements',(SELECT count(*) FROM public.specialist_upload_audit WHERE action='operator_finish'),
 'late_orphan_objects',(SELECT count(*) FROM storage.objects o JOIN public.specialist_upload_reservations r ON r.object_name=o.name WHERE o.bucket_id='specialist-media' AND r.state='deleted'),
 'over_quota_profiles',(SELECT count(*) FROM (SELECT profile FROM (SELECT split_part(name,'/',1) profile FROM storage.objects WHERE bucket_id='specialist-media' UNION ALL SELECT r.profile_id::text FROM public.specialist_upload_reservations r WHERE r.state<>'deleted' AND NOT EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=r.object_name)) slots GROUP BY profile HAVING count(*)>20) q),
 'alert',EXISTS(SELECT FROM (SELECT split_part(name,'/',1) profile FROM storage.objects WHERE bucket_id='specialist-media' UNION ALL SELECT r.profile_id::text FROM public.specialist_upload_reservations r WHERE r.state<>'deleted' AND NOT EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=r.object_name)) slots GROUP BY profile HAVING count(*)>20) OR EXISTS(SELECT FROM public.specialist_upload_reservations WHERE state='uploading' AND expires_at<now()) OR EXISTS(SELECT FROM storage.objects o JOIN public.specialist_upload_reservations r ON r.object_name=o.name WHERE o.bucket_id='specialist-media' AND r.state='deleted'))
$metrics$;

REVOKE ALL ON FUNCTION public.specialist_operator_check(uuid,uuid,uuid,text,boolean) FROM PUBLIC,anon,authenticated,service_role,specialist_operator;
NOTIFY pgrst,'reload schema';
COMMIT;
