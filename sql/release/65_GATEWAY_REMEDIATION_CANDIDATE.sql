-- REVIEW ONLY. Delta after phase 60; never auto-apply hosted.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN
 IF to_regclass('public.specialist_upload_audit') IS NOT NULL THEN RAISE EXCEPTION 'Remediation already present; stop and review drift'; END IF;
 IF (SELECT md5(pg_get_functiondef('public.specialist_gateway_begin_delete(uuid,uuid,text)'::regprocedure))) IS DISTINCT FROM 'd9978d621b1059d23dfb655fe0cf84a6' THEN RAISE EXCEPTION 'PR38 begin_delete drift'; END IF;
 IF (SELECT md5(pg_get_functiondef('public.get_my_specialist_upload_capability(uuid)'::regprocedure))) IS DISTINCT FROM '67a5d0c9760eaf16765b1756b1cc3a29' THEN RAISE EXCEPTION 'PR38 capability drift'; END IF;
END $$;
ALTER TABLE public.specialist_upload_control ADD COLUMN deletions_enabled boolean NOT NULL DEFAULT false;
CREATE TABLE public.specialist_upload_audit(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),request_id uuid NOT NULL,profile_id uuid NOT NULL,
 action text NOT NULL CHECK(action IN ('definite_rejection','operator_begin','operator_finish')),
 actor text NOT NULL CHECK(char_length(actor) BETWEEN 3 AND 200),reason text NOT NULL CHECK(char_length(reason) BETWEEN 3 AND 500),
 evidence jsonb NOT NULL CHECK(jsonb_typeof(evidence)='object' AND octet_length(evidence::text)<=8192),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON public.specialist_upload_audit(request_id,created_at);
ALTER TABLE public.specialist_upload_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_upload_audit FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_upload_audit FROM PUBLIC,anon,authenticated,service_role;
-- No direct audit writes or mutation grants, including service_role; only pinned DEFINER functions.
CREATE FUNCTION public.specialist_gateway_reject(p_owner uuid,p_specialist_id uuid,p_request_id uuid,p_http_status integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $reject$
DECLARE r public.specialist_upload_reservations;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF p_http_status IS NULL OR p_http_status<400 OR p_http_status>=500 OR p_http_status IN (408,409) THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Not a definite Storage rejection'; END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id AND profile_id=p_specialist_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Upload unavailable'; END IF;
 IF r.state='deleted' THEN RETURN jsonb_build_object('retired',true); END IF;
 IF r.state<>'uploading' OR EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Object or nonpending request; retain reservation'; END IF;
 INSERT INTO public.specialist_upload_audit(request_id,profile_id,action,actor,reason,evidence) VALUES(r.id,p_specialist_id,'definite_rejection','gateway','Storage returned terminal non-timeout non-conflict 4xx',jsonb_build_object('http_status',p_http_status,'one_attempt',true));
 UPDATE public.specialist_upload_reservations SET state='deleted',specialist_id=NULL,fingerprint=NULL,mime=NULL,size_bytes=NULL,caption=NULL WHERE id=r.id;
 RETURN jsonb_build_object('retired',true);
END $reject$;
-- Operator assertions are privileged external evidence, NOT a SQL-verifiable timeout.
-- No user endpoint calls this function. No automatic TTL retirement exists.
CREATE FUNCTION public.specialist_gateway_force_retire(p_owner uuid,p_specialist_id uuid,p_request_id uuid,p_phase text,p_actor text,p_reason text,p_proof jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $retire$
DECLARE r public.specialist_upload_reservations;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF (SELECT enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Disable upload admission before operator retirement'; END IF;
 IF p_phase IS NULL OR p_phase NOT IN ('begin','finish') OR p_actor IS NULL OR char_length(p_actor) NOT BETWEEN 3 AND 200 OR p_reason IS NULL OR char_length(p_reason) NOT BETWEEN 3 AND 500 OR p_proof IS NULL OR jsonb_typeof(p_proof)<>'object' OR octet_length(p_proof::text)>8192
 OR (p_proof->>'kind') IS NULL OR (p_proof->>'kind') NOT IN ('provider_terminal_no_late_writer','credentials_revoked_all_writers_drained')
 OR coalesce(char_length(p_proof->>'evidence_ref'),0) NOT BETWEEN 8 AND 1000
 OR (p_proof->>'request_id') IS DISTINCT FROM p_request_id::text
 OR p_proof->'all_writers_stopped' IS DISTINCT FROM 'true'::jsonb THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Reviewed external no-late-writer evidence required; TTL is not proof';
 END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE id=p_request_id AND profile_id=p_specialist_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Upload unavailable'; END IF;
 IF r.state='deleted' THEN RETURN jsonb_build_object('retired',true,'object_name',r.object_name); END IF;
 IF p_phase='begin' THEN
  INSERT INTO public.specialist_upload_audit(request_id,profile_id,action,actor,reason,evidence) VALUES(r.id,p_specialist_id,'operator_begin',p_actor,p_reason,p_proof);
  UPDATE public.specialist_upload_reservations SET state='deleting' WHERE id=r.id;
  RETURN jsonb_build_object('retired',false,'object_name',r.object_name);
 END IF;
 IF r.state<>'deleting' OR NOT EXISTS(SELECT FROM public.specialist_upload_audit WHERE request_id=r.id AND action='operator_begin' AND evidence=p_proof) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Audited begin with same proof required'; END IF;
 IF EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=r.object_name) THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Remove object through Storage API first'; END IF;
 DELETE FROM public.specialist_media WHERE specialist_id=p_specialist_id AND object_name=r.object_name;
 INSERT INTO public.specialist_upload_audit(request_id,profile_id,action,actor,reason,evidence) VALUES(r.id,p_specialist_id,'operator_finish',p_actor,p_reason,p_proof);
 UPDATE public.specialist_upload_reservations SET state='deleted',specialist_id=NULL,fingerprint=NULL,mime=NULL,size_bytes=NULL,caption=NULL WHERE id=r.id;
 RETURN jsonb_build_object('retired',true,'object_name',r.object_name);
END $retire$;
CREATE FUNCTION public.specialist_gateway_metrics() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $metrics$
 SELECT jsonb_build_object(
 'quarantined',(SELECT count(*) FROM public.specialist_upload_reservations WHERE state='uploading' AND expires_at<now()),
 'pending',(SELECT count(*) FROM public.specialist_upload_reservations WHERE state='uploading'),
 'deleting',(SELECT count(*) FROM public.specialist_upload_reservations WHERE state='deleting'),
 'definite_rejections',(SELECT count(*) FROM public.specialist_upload_audit WHERE action='definite_rejection'),
 'operator_retirements',(SELECT count(*) FROM public.specialist_upload_audit WHERE action='operator_finish'),
 'late_orphan_objects',(SELECT count(*) FROM storage.objects o JOIN public.specialist_upload_reservations r ON r.object_name=o.name WHERE o.bucket_id='specialist-media' AND r.state='deleted'),
 'over_quota_profiles',(SELECT count(*) FROM (SELECT split_part(name,'/',1) FROM storage.objects WHERE bucket_id='specialist-media' GROUP BY split_part(name,'/',1) HAVING count(*)>20) q),
 'alert',EXISTS(SELECT FROM public.specialist_upload_reservations WHERE state='uploading' AND expires_at<now()) OR EXISTS(SELECT FROM storage.objects o JOIN public.specialist_upload_reservations r ON r.object_name=o.name WHERE o.bucket_id='specialist-media' AND r.state='deleted'))
$metrics$;
DO $acl$ DECLARE r record; BEGIN
 FOR r IN SELECT oid::regprocedure signature FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('specialist_gateway_reject','specialist_gateway_force_retire','specialist_gateway_metrics') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
 END LOOP;
END $acl$;
CREATE OR REPLACE FUNCTION public.get_my_specialist_upload_capability(p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $capability$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 RETURN jsonb_build_object('protocol',1,'enabled',(SELECT enabled FROM public.specialist_upload_control WHERE singleton),'deletions_enabled',(SELECT deletions_enabled FROM public.specialist_upload_control WHERE singleton),'limit',20);
END $capability$;
CREATE OR REPLACE FUNCTION public.specialist_gateway_begin_delete(p_owner uuid,p_specialist_id uuid,p_object_name text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.specialist_upload_reservations; kind text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND OR p_owner IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 IF NOT (SELECT deletions_enabled FROM public.specialist_upload_control WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Media deletion disabled'; END IF;
 IF p_object_name IS NULL OR split_part(p_object_name,'/',1)<>p_specialist_id::text OR p_object_name !~ '^[0-9a-f-]{36}/(avatar|portfolio)/[0-9a-f-]{36}[.](png|jpg|jpeg|webp)$' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Object unavailable'; END IF;
 SELECT * INTO r FROM public.specialist_upload_reservations WHERE object_name=p_object_name FOR UPDATE;
 IF FOUND THEN
  IF r.state='uploading' THEN RAISE EXCEPTION USING ERRCODE='PT409',MESSAGE='Unknown in-flight upload; retain reservation'; END IF;
  IF r.state='deleted' THEN RETURN to_jsonb(r); END IF;
  UPDATE public.specialist_upload_reservations SET state='deleting' WHERE id=r.id RETURNING * INTO r;
 ELSE
  IF NOT EXISTS(SELECT FROM storage.objects WHERE bucket_id='specialist-media' AND name=p_object_name) AND NOT EXISTS(SELECT FROM public.specialist_media WHERE specialist_id=p_specialist_id AND object_name=p_object_name) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Object unavailable'; END IF;
  kind:=split_part(p_object_name,'/',2);
  INSERT INTO public.specialist_upload_reservations(id,profile_id,specialist_id,object_name,kind,state) VALUES(gen_random_uuid(),p_specialist_id,p_specialist_id,p_object_name,kind,'deleting') RETURNING * INTO r;
 END IF;
 RETURN to_jsonb(r);
END $$;

CREATE FUNCTION public.specialist_gateway_erasure_inventory(p_owner uuid,p_specialist_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $inventory$
BEGIN
 IF p_owner IS NULL OR NOT EXISTS(SELECT FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=p_owner AND profile_status='draft') THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Draft unavailable'; END IF;
 RETURN jsonb_build_object('uploads_enabled',(SELECT enabled FROM public.specialist_upload_control WHERE singleton),
 'reservations',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'object_name',object_name,'state',state)) FROM public.specialist_upload_reservations WHERE specialist_id=p_specialist_id AND state<>'deleted'),'[]'::jsonb),
 'objects',coalesce((SELECT jsonb_agg(name) FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=p_specialist_id::text),'[]'::jsonb));
END $inventory$;
REVOKE ALL ON FUNCTION public.specialist_gateway_erasure_inventory(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.specialist_gateway_erasure_inventory(uuid,uuid) TO service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
