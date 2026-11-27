-- ISOLATED REVIEW ONLY. Requires the closed C1/C2 foundation. No public API.
-- Enforce current revision plus at most one other; erase cascades remain allowed.
BEGIN;
CREATE FUNCTION public.specialist_revision_insert_lock_v1() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Trusted RLS-bypass owner required';
 END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('specialist-media:'||NEW.specialist_id::text,0));
 PERFORM 1 FROM public.specialist_profiles WHERE id=NEW.specialist_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23503',MESSAGE='Specialist unavailable'; END IF;
 RETURN NEW;
END $fn$;
CREATE FUNCTION public.specialist_revision_retention_v1() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Trusted RLS-bypass owner required';
 END IF;
 DELETE FROM public.specialist_public_revisions r WHERE r.specialist_id=NEW.specialist_id AND r.revision_id NOT IN (
  SELECT x.revision_id FROM public.specialist_public_revisions x
  WHERE x.specialist_id=NEW.specialist_id
  ORDER BY (x.revision_id=NEW.revision_id) DESC,
   (x.revision_id=(SELECT s.published_revision_id FROM public.specialist_publication_state s WHERE s.specialist_id=NEW.specialist_id)) DESC NULLS LAST,
   x.created_at DESC,x.revision_id DESC LIMIT 2
 );
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.specialist_revision_insert_lock_v1(),public.specialist_revision_retention_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER specialist_revision_insert_lock_v1 BEFORE INSERT ON public.specialist_public_revisions FOR EACH ROW EXECUTE FUNCTION public.specialist_revision_insert_lock_v1();
CREATE TRIGGER specialist_revision_retention_v1 AFTER INSERT ON public.specialist_public_revisions FOR EACH ROW EXECUTE FUNCTION public.specialist_revision_retention_v1();
COMMIT;
