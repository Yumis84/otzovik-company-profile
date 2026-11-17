-- ISOLATED REVIEW ONLY. Uses the existing specialist_operator identity.
-- No enabling function; public activation requires an independent owner decision.
BEGIN;
CREATE TABLE public.specialist_public_operator_audit_v1 (
 event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 specialist_id uuid REFERENCES public.specialist_profiles(id) ON DELETE SET NULL,
 actor uuid NOT NULL,
 action text NOT NULL CHECK(action IN ('suspend','disable_projection')),
 reason text NOT NULL CHECK(char_length(btrim(reason)) BETWEEN 3 AND 500),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.specialist_public_operator_audit_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_public_operator_audit_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_public_operator_audit_v1 FROM PUBLIC,anon,authenticated,service_role,specialist_operator;
CREATE FUNCTION public.specialist_suspend_public_v1(p_specialist_id uuid,p_reason text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $suspend$
DECLARE s public.specialist_publication_state;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_operator_identities WHERE user_id=auth.uid() AND enabled) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Registered operator required'; END IF;
 IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Reason required'; END IF;
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Trusted RLS-bypass owner required'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('specialist-media:'||p_specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 INSERT INTO public.specialist_publication_state(specialist_id) VALUES(p_specialist_id) ON CONFLICT(specialist_id) DO NOTHING;
 SELECT * INTO s FROM public.specialist_publication_state WHERE specialist_id=p_specialist_id FOR UPDATE;
 IF s.state='erasing' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist unavailable'; END IF;
 IF s.state<>'suspended' THEN
  UPDATE public.specialist_publication_state SET state='suspended',published_revision_id=NULL WHERE specialist_id=p_specialist_id;
  INSERT INTO public.specialist_public_operator_audit_v1(specialist_id,actor,action,reason) VALUES(p_specialist_id,auth.uid(),'suspend',p_reason);
 END IF;
 RETURN jsonb_build_object('suspended',true);
END $suspend$;
REVOKE ALL ON FUNCTION public.specialist_suspend_public_v1(uuid,text) FROM PUBLIC,anon,authenticated,service_role,specialist_operator;
GRANT EXECUTE ON FUNCTION public.specialist_suspend_public_v1(uuid,text) TO specialist_operator;
CREATE FUNCTION public.specialist_disable_public_v1(p_reason text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $disable$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.specialist_operator_identities WHERE user_id=auth.uid() AND enabled) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Registered operator required'; END IF;
 IF p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Reason required'; END IF;
 IF NOT EXISTS(SELECT FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Trusted RLS-bypass owner required'; END IF;
 UPDATE public.specialist_public_control SET enabled=false WHERE singleton AND enabled;
 IF FOUND THEN INSERT INTO public.specialist_public_operator_audit_v1(actor,action,reason) VALUES(auth.uid(),'disable_projection',p_reason); END IF;
 RETURN jsonb_build_object('enabled',false);
END $disable$;
REVOKE ALL ON FUNCTION public.specialist_disable_public_v1(text) FROM PUBLIC,anon,authenticated,service_role,specialist_operator;
GRANT EXECUTE ON FUNCTION public.specialist_disable_public_v1(text) TO specialist_operator;
COMMIT;
