-- ISOLATED REVIEW CANDIDATE ONLY. Requires publication foundation and existing operator gateway.
-- Never apply to hosted or production. Publication remains disabled.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
-- Refuse to overwrite an unexpected installed operator contract.
DO $preflight$
DECLARE item record;
BEGIN
 FOR item IN SELECT * FROM (VALUES
  ('public.delete_my_specialist_draft(uuid)','0e19307109d1fa40e665e885c8caab08'),
  ('public.specialist_gateway_erasure_inventory(uuid,uuid)','2e0aa31c6b05c604b4baf5c52d73bc23'),
  ('public.specialist_gateway_force_retire(uuid,uuid,uuid,text,text,text,jsonb)','ea996c011328fb772d71576f4a1c8c88'),
  ('public.confirm_my_specialist_erasure(uuid,uuid)','0bfc39c25476dbcc85f2afced603fbcf'),
  ('public.specialist_operator_authorize(uuid,uuid,uuid,text,text)','86bd6148c97590f19d7fb9004c4e3326'),
  ('public.specialist_operator_plan_erasure(uuid,uuid,uuid)','b03e4405968520dea532091959fe46e1')
 ) AS expected(signature,digest) LOOP
  IF pg_catalog.md5(pg_catalog.pg_get_functiondef(pg_catalog.to_regprocedure(item.signature))) IS DISTINCT FROM item.digest THEN
   RAISE EXCEPTION 'Erasure prerequisite drift: %',item.signature;
  END IF;
 END LOOP;
END
$preflight$;
ALTER TABLE public.specialist_profiles DROP CONSTRAINT specialist_profiles_status_check;
ALTER TABLE public.specialist_profiles ADD CONSTRAINT specialist_profiles_status_check CHECK (profile_status IN ('draft','erasing'));
CREATE OR REPLACE FUNCTION public.confirm_my_specialist_erasure(p_specialist_id uuid,p_confirmation_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $confirm$
DECLARE r public.specialist_erasure_confirmations;
BEGIN
 IF auth.uid() IS NULL OR p_confirmation_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status IN ('draft','erasing') FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 INSERT INTO public.specialist_erasure_confirmations(id,profile_id,owner_user_id) VALUES(p_confirmation_id,p_specialist_id,auth.uid()) ON CONFLICT(id) DO NOTHING;
 SELECT * INTO r FROM public.specialist_erasure_confirmations WHERE id=p_confirmation_id AND profile_id=p_specialist_id AND owner_user_id=auth.uid() AND expires_at>now();
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Confirmation unavailable or expired'; END IF;
 UPDATE public.specialist_profiles SET profile_status='erasing' WHERE id=p_specialist_id;
 INSERT INTO public.specialist_publication_state(specialist_id,state,published_revision_id) VALUES(p_specialist_id,'erasing',NULL)
 ON CONFLICT(specialist_id) DO UPDATE SET state='erasing',published_revision_id=NULL;
 RETURN jsonb_build_object('confirmation_id',r.id,'expires_at',r.expires_at);
END $confirm$;
CREATE OR REPLACE FUNCTION public.specialist_operator_authorize(p_specialist_id uuid,p_confirmation_id uuid,p_request_id uuid,p_purpose text,p_ticket text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $authorize$
DECLARE v_result public.specialist_erasure_authorizations; deadline timestamptz;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_operator_identities WHERE user_id=auth.uid() AND enabled) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Registered operator required'; END IF;
 IF p_ticket IS NULL OR p_ticket !~ '^OTZ-[A-Z0-9-]{8,100}$' OR p_purpose IS NULL OR p_purpose NOT IN ('profile_erasure','orphan_cleanup') THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid reviewed authorization'; END IF;
 IF p_purpose='profile_erasure' THEN
  SELECT c.expires_at INTO deadline FROM public.specialist_erasure_confirmations c JOIN public.specialist_profiles p ON p.id=c.profile_id AND p.owner_user_id=c.owner_user_id AND p.profile_status IN ('draft','erasing') WHERE c.id=p_confirmation_id AND c.profile_id=p_specialist_id AND c.expires_at>now();
  IF NOT FOUND OR p_request_id IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Live owner confirmation required'; END IF;
 ELSE
  IF p_confirmation_id IS NOT NULL OR EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id) OR NOT EXISTS(SELECT FROM public.specialist_upload_reservations r WHERE r.id=p_request_id AND r.profile_id=p_specialist_id AND r.state='deleted' AND r.specialist_id IS NULL AND EXISTS(SELECT FROM public.specialist_upload_audit a WHERE a.request_id=r.id AND a.profile_id=r.profile_id)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Audited deleted-profile tombstone required'; END IF;
  deadline:=now()+interval '15 minutes';
 END IF;
 INSERT INTO public.specialist_erasure_authorizations(profile_id,request_id,purpose,approved_by,confirmation_id,ticket,expires_at) VALUES(p_specialist_id,p_request_id,p_purpose,auth.uid(),p_confirmation_id,p_ticket,deadline) RETURNING * INTO v_result;
 RETURN jsonb_build_object('authorization_id',v_result.id,'approved_by',v_result.approved_by,'expires_at',v_result.expires_at);
END $authorize$;

CREATE OR REPLACE FUNCTION public.specialist_operator_plan_erasure(p_owner uuid,p_specialist_id uuid,p_authorization_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $plan$
DECLARE o record;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status IN ('draft','erasing') FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 PERFORM public.specialist_operator_check(p_authorization_id,p_specialist_id,NULL,'profile_erasure');
 IF (SELECT enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Disable admission first'; END IF;
 FOR o IN SELECT name FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text LOOP
  IF o.name !~ '^[0-9a-f-]{36}/(avatar|portfolio)/[0-9a-f-]{36}[.](png|jpg|jpeg|webp)$' THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Unexpected legacy path requires review'; END IF;
  INSERT INTO public.specialist_upload_reservations(id,profile_id,specialist_id,object_name,kind,state) SELECT gen_random_uuid(),p_specialist_id,p_specialist_id,o.name,split_part(o.name,'/',2),'ready' WHERE NOT EXISTS(SELECT FROM public.specialist_upload_reservations WHERE object_name=o.name);
 END LOOP;
 RETURN public.specialist_gateway_erasure_inventory(p_owner,p_specialist_id)||jsonb_build_object('planned',true,'authorization_id',p_authorization_id);
END $plan$;

CREATE OR REPLACE FUNCTION public.specialist_gateway_force_retire(p_owner uuid,p_specialist_id uuid,p_request_id uuid,p_phase text,p_actor text,p_reason text,p_proof jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $retire$
DECLARE r public.specialist_upload_reservations;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status IN ('draft','erasing') FOR UPDATE;
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
 IF p_owner IS NULL OR NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status IN ('draft','erasing')) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 RETURN jsonb_build_object('uploads_enabled',(SELECT enabled FROM public.specialist_upload_control WHERE singleton),
 'reservations',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'object_name',r.object_name,'state',r.state)) FROM public.specialist_upload_reservations r WHERE (r.specialist_id=p_specialist_id AND r.state<>'deleted') OR (r.profile_id=p_specialist_id AND r.state='deleted' AND EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='specialist-media' AND o.name=r.object_name))),'[]'::jsonb),
 'objects',coalesce((SELECT jsonb_agg(name) FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text),'[]'::jsonb));
END $inventory$;

CREATE OR REPLACE FUNCTION public.delete_my_specialist_draft(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authentication required'; END IF;
 IF NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status IN ('draft','erasing')) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status IN ('draft','erasing') FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF EXISTS(SELECT FROM public.specialist_upload_reservations WHERE specialist_id=p_specialist_id AND state<>'deleted') OR EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Remove specialist files before deleting draft'; END IF;
 DELETE FROM public.specialist_profiles WHERE id=p_specialist_id;
 RETURN jsonb_build_object('id',p_specialist_id,'deleted',true);
END $$;
COMMIT;
