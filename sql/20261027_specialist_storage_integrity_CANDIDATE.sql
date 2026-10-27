-- CANDIDATE ONLY. Not applied to any hosted project.
-- Requires an independently approved managed storage.objects TRIGGER privilege.
-- RLS permission probes do not guarantee a lock spans the actual object insertion.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN
 IF NOT has_table_privilege(current_user,'storage.objects','TRIGGER') THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Storage integrity candidate requires explicit TRIGGER privilege; do not change managed ownership or grants to bypass';
 END IF;
END $$;
CREATE FUNCTION public.enforce_specialist_object_integrity() RETURNS trigger
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid;
BEGIN
 IF NEW.bucket_id IS DISTINCT FROM 'specialist-media' THEN RETURN NEW; END IF;
 IF NEW.name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(avatar|portfolio)/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](webp|png|jpg|jpeg)$' THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid specialist object path';
 END IF;
 v_id:=split_part(NEW.name,'/',1)::uuid;
 PERFORM pg_advisory_xact_lock(hashtextextended('specialist-media:'||v_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=v_id AND profile_status='draft' FOR KEY SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Specialist draft unavailable'; END IF;
 IF (SELECT count(*) FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=v_id::text)>=20 THEN
  RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='Specialist object quota reached';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.enforce_specialist_object_integrity() FROM PUBLIC,anon,authenticated;
-- Runs on the actual metadata INSERT, including service-role Storage internals.
-- Other buckets return immediately; no company policy, grant or row is changed.
CREATE TRIGGER specialist_object_integrity BEFORE INSERT ON storage.objects
FOR EACH ROW EXECUTE FUNCTION public.enforce_specialist_object_integrity();
COMMIT;
