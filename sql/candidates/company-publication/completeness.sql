BEGIN;
CREATE FUNCTION private.publish_snapshot_complete_candidate(d jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
SELECT coalesce(jsonb_typeof(d->'sources')='array' AND jsonb_typeof(d->'reviews')='array' AND jsonb_typeof(d->'questions_answers')='array' AND jsonb_typeof(d->'native_rating')='object' AND (d->'native_rating') ? 'rating' AND jsonb_typeof(d->'native_rating'->'review_count')='number' AND (d->'native_rating'->>'review_count') ~ '^[0-9]+$' AND jsonb_typeof(d->'locations')='array' AND jsonb_typeof(d->'services')='array' AND jsonb_typeof(d->'media')='array',false)
$$;
REVOKE ALL ON FUNCTION private.publish_snapshot_complete_candidate(jsonb) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION private.guard_publish_artifact_candidate() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM jsonb_each_text(NEW.manifest) m WHERE m.key !~ '^(index\.html|profile\.(css|json|md)|llms\.txt|media/[A-Za-z0-9_-]+\.(png|jpg|jpeg|webp))$' OR m.value !~ '^[0-9a-f]{64}$')
 OR NEW.digest IS DISTINCT FROM (SELECT encode(sha256(convert_to(string_agg(m.key||':'||m.value,E'\n' ORDER BY m.key COLLATE "C"),'UTF8')),'hex') FROM jsonb_each_text(NEW.manifest) m)
 THEN RAISE EXCEPTION 'invalid artifact manifest'; END IF;
 IF NOT EXISTS(SELECT 1 FROM private.company_publish_attempt_candidate a WHERE a.id=NEW.attempt_id AND a.run_id=NEW.run_id AND a.state='building' AND a.lease_until>clock_timestamp() AND private.publish_snapshot_complete_candidate(a.snapshot)) THEN RAISE EXCEPTION 'invalid or incomplete candidate'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.guard_publish_artifact_candidate() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_publish_artifact_candidate BEFORE INSERT OR UPDATE ON private.company_publish_artifact_candidate FOR EACH ROW EXECUTE FUNCTION private.guard_publish_artifact_candidate();
COMMIT;
