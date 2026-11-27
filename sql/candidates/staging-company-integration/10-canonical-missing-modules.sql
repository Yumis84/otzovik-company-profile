-- REVIEW ONLY: existing staging salmcnhexlftrgtiryyo; never auto-apply.
BEGIN;
SET LOCAL lock_timeout='3s'; SET LOCAL statement_timeout='60s';
SET LOCAL search_path=pg_catalog,public,private,extensions;
DO $pre$ BEGIN IF current_setting('server_version_num')::int < 170000 THEN RAISE EXCEPTION 'PG17 required'; END IF;
IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='private') THEN RAISE EXCEPTION 'unexpected existing private schema: recatalog before any ACL change'; END IF;
IF to_regclass('public.specialist_profiles') IS NULL OR to_regclass('public.company_access_invitations') IS NULL THEN RAISE EXCEPTION 'expected existing staging modules absent'; END IF;
IF to_regclass('private.actors') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: actors'; END IF;
IF to_regclass('private.compatibility_flags_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: compatibility_flags_v1'; END IF;
IF to_regclass('private.embedding_projection_refs_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: embedding_projection_refs_v1'; END IF;
IF to_regclass('private.erasure_projection_receipts_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: erasure_projection_receipts_v1'; END IF;
IF to_regclass('private.erasure_requests') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: erasure_requests'; END IF;
IF to_regclass('private.external_sources_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: external_sources_v1'; END IF;
IF to_regclass('private.external_sync_runs_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: external_sync_runs_v1'; END IF;
IF to_regclass('private.knowledge_change_proposals_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: knowledge_change_proposals_v1'; END IF;
IF to_regclass('private.knowledge_concepts_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: knowledge_concepts_v1'; END IF;
IF to_regclass('private.knowledge_publications_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: knowledge_publications_v1'; END IF;
IF to_regclass('private.knowledge_source_links_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: knowledge_source_links_v1'; END IF;
IF to_regclass('private.knowledge_variants_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: knowledge_variants_v1'; END IF;
IF to_regclass('private.knowledge_versions_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: knowledge_versions_v1'; END IF;
IF to_regclass('private.legal_holds') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: legal_holds'; END IF;
IF to_regclass('private.moderation_actions_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: moderation_actions_v1'; END IF;
IF to_regclass('private.moderation_cases_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: moderation_cases_v1'; END IF;
IF to_regclass('private.moderation_operators') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: moderation_operators'; END IF;
IF to_regclass('private.official_statements_v2') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: official_statements_v2'; END IF;
IF to_regclass('private.outbox_events_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: outbox_events_v1'; END IF;
IF to_regclass('private.own_review_rate_limits') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: own_review_rate_limits'; END IF;
IF to_regclass('private.own_review_submissions') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: own_review_submissions'; END IF;
IF to_regclass('private.persons') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: persons'; END IF;
IF to_regclass('private.projection_consumers_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: projection_consumers_v1'; END IF;
IF to_regclass('private.projection_receipts_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: projection_receipts_v1'; END IF;
IF to_regclass('private.public_author_person_links') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: public_author_person_links'; END IF;
IF to_regclass('private.question_messages_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: question_messages_v1'; END IF;
IF to_regclass('private.question_revisions_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: question_revisions_v1'; END IF;
IF to_regclass('private.questions_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: questions_v1'; END IF;
IF to_regclass('private.review_revisions_v1') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: review_revisions_v1'; END IF;
IF to_regclass('private.review_source_sync_jobs') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: review_source_sync_jobs'; END IF;
IF to_regclass('private.statement_revisions_v2') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: statement_revisions_v2'; END IF;
IF to_regclass('private.verification_evidence') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: verification_evidence'; END IF;
IF to_regclass('public.company_profile_public_access') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: company_profile_public_access'; END IF;
IF to_regclass('public.company_profile_publications') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: company_profile_publications'; END IF;
IF to_regclass('public.company_questions_answers') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: company_questions_answers'; END IF;
IF to_regclass('public.company_statements') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: company_statements'; END IF;
IF to_regclass('public.review_service_links') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: review_service_links'; END IF;
IF to_regclass('public.review_sources') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: review_sources'; END IF;
IF to_regclass('public.reviews') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: reviews'; END IF;
IF to_regclass('public.source_ratings') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: source_ratings'; END IF;
IF to_regclass('public.public_authors') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: public_authors'; END IF;
END $pre$;
DO $preflight$ BEGIN
IF (SELECT md5(jsonb_build_object(
'tables',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'force',c.relforcerowsecurity,
'columns',(SELECT jsonb_agg(jsonb_build_array(a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull,pg_get_expr(d.adbin,d.adrelid),a.attidentity,a.attgenerated) ORDER BY a.attnum) FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped),
'constraints',(SELECT jsonb_agg(jsonb_build_array(conname,contype,pg_get_constraintdef(x.oid,true)) ORDER BY conname) FROM pg_constraint x WHERE conrelid=c.oid),
'indexes',(SELECT jsonb_agg(pg_get_indexdef(i.indexrelid) ORDER BY pg_get_indexdef(i.indexrelid)) FROM pg_index i WHERE i.indrelid=c.oid AND NOT EXISTS(SELECT 1 FROM pg_constraint cc WHERE cc.conrelid=i.indrelid AND cc.conindid=i.indexrelid AND cc.contype IN('p','u','x'))),
'acl',(SELECT jsonb_agg(jsonb_build_array(CASE WHEN grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(grantee) END,privilege_type,is_grantable) ORDER BY CASE WHEN grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(grantee) END,privilege_type) FROM aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))))) ORDER BY n.nspname,c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.oid IN('public.audit_log'::regclass,'public.companies'::regclass,'public.company_access_invitations'::regclass,'public.company_locations'::regclass,'public.company_media'::regclass,'public.company_memberships'::regclass,'public.company_services'::regclass,'public.profile_slug_registry'::regclass,'public.specialist_channel_sets'::regclass,'public.specialist_contact_channels'::regclass,'public.specialist_erasure_authorizations'::regclass,'public.specialist_erasure_confirmations'::regclass,'public.specialist_media'::regclass,'public.specialist_operator_identities'::regclass,'public.specialist_profiles'::regclass,'public.specialist_public_control'::regclass,'public.specialist_public_operator_audit_v1'::regclass,'public.specialist_public_revisions'::regclass,'public.specialist_publication_state'::regclass,'public.specialist_publish_requests_v1'::regclass,'public.specialist_reserved_slugs_v1'::regclass,'public.specialist_revision_details_v1'::regclass,'public.specialist_services'::regclass,'public.specialist_settings'::regclass,'public.specialist_slug_tombstones_v1'::regclass,'public.specialist_upload_audit'::regclass,'public.specialist_upload_control'::regclass,'public.specialist_upload_reservations'::regclass,'public.test_publish_events'::regclass)),
'functions',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'args',oidvectortypes(p.proargtypes),'owner',pg_get_userbyid(p.proowner),'definition',md5(pg_get_functiondef(p.oid)),'acl',(SELECT jsonb_agg(jsonb_build_array(CASE WHEN grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(grantee) END,privilege_type,is_grantable) ORDER BY CASE WHEN grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(grantee) END,privilege_type) FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))))) ORDER BY n.nspname,p.proname,oidvectortypes(p.proargtypes)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.oid IN('media_internal.is_published_company_media_object(text)'::regprocedure,'public.accept_company_access_invitation(text)'::regprocedure,'public.accept_my_company_invitation(uuid)'::regprocedure,'public.can_manage_specialist_object(text)'::regprocedure,'public.can_operator_remove_specialist_object(text)'::regprocedure,'public.can_upload_specialist_object(text)'::regprocedure,'public.confirm_my_specialist_erasure(uuid, uuid)'::regprocedure,'public.create_my_company(text, text, text, text, text, text)'::regprocedure,'public.create_my_company_location(uuid, text, text, text, text, jsonb, text)'::regprocedure,'public.create_my_company_service(uuid, text, text, text, text)'::regprocedure,'public.create_my_specialist_draft(text, text, text, text, text, text)'::regprocedure,'public.decline_my_company_invitation(uuid)'::regprocedure,'public.delete_my_specialist_draft(uuid)'::regprocedure,'public.delete_my_specialist_media(uuid, uuid)'::regprocedure,'public.delete_my_specialist_service(uuid, uuid, integer)'::regprocedure,'public.get_my_companies()'::regprocedure,'public.get_my_company_access(uuid)'::regprocedure,'public.get_my_company_locations(uuid)'::regprocedure,'public.get_my_company_services(uuid)'::regprocedure,'public.get_my_pending_company_invitations()'::regprocedure,'public.get_my_specialist_media(uuid)'::regprocedure,'public.get_my_specialist_public_options_v1(uuid)'::regprocedure,'public.get_my_specialist_publication_v1(uuid)'::regprocedure,'public.get_my_specialist_services(uuid)'::regprocedure,'public.get_my_specialist_settings(uuid)'::regprocedure,'public.get_my_specialist_upload_capability(uuid)'::regprocedure,'public.get_my_specialists()'::regprocedure,'public.get_public_specialist_v1(text)'::regprocedure,'public.list_my_specialist_channels(uuid)'::regprocedure,'public.manage_my_company_location(uuid, uuid, text)'::regprocedure,'public.manage_my_company_service(uuid, uuid, text)'::regprocedure,'public.owner_invite_existing_company_user(uuid, text, text)'::regprocedure,'public.publish_my_specialist_details_v1(uuid, integer, uuid, jsonb)'::regprocedure,'public.publish_my_specialist_v1(uuid, integer, uuid)'::regprocedure,'public.register_my_company_media(uuid, text, text, text, text, integer)'::regprocedure,'public.register_my_specialist_media(uuid, text, text, text)'::regprocedure,'public.request_company_profile_publish()'::regprocedure,'public.resolve_public_specialist_photo_v1(text, uuid)'::regprocedure,'public.revoke_company_access_invitation(uuid)'::regprocedure,'public.save_my_specialist_channels(uuid, integer, jsonb)'::regprocedure,'public.save_my_specialist_service(uuid, uuid, text, text, numeric, numeric, text, integer, boolean, integer)'::regprocedure,'public.save_my_specialist_settings(uuid, text, text, text, text[], text, text, integer)'::regprocedure,'public.specialist_channel_normalize(text, text)'::regprocedure,'public.specialist_disable_public_v1(text)'::regprocedure,'public.specialist_gateway_begin_delete(uuid, uuid, text)'::regprocedure,'public.specialist_gateway_erasure_inventory(uuid, uuid)'::regprocedure,'public.specialist_gateway_finish(uuid, uuid, uuid)'::regprocedure,'public.specialist_gateway_finish_delete(uuid, uuid, uuid)'::regprocedure,'public.specialist_gateway_force_retire(uuid, uuid, uuid, text, text, text, jsonb)'::regprocedure,'public.specialist_gateway_metrics()'::regprocedure,'public.specialist_gateway_reconcile(uuid, uuid)'::regprocedure,'public.specialist_gateway_reject(uuid, uuid, uuid, integer)'::regprocedure,'public.specialist_gateway_reserve(uuid, uuid, uuid, text, text, text, integer, text)'::regprocedure,'public.specialist_operator_authorize(uuid, uuid, uuid, text, text)'::regprocedure,'public.specialist_operator_check(uuid, uuid, uuid, text, boolean)'::regprocedure,'public.specialist_operator_cleanup_orphan(uuid, text, jsonb)'::regprocedure,'public.specialist_operator_plan_erasure(uuid, uuid, uuid)'::regprocedure,'public.specialist_public_fields_version_v1()'::regprocedure,'public.specialist_revision_immutable_v1()'::regprocedure,'public.specialist_revision_insert_lock_v1()'::regprocedure,'public.specialist_revision_retention_v1()'::regprocedure,'public.specialist_slug_policy_v1()'::regprocedure,'public.specialist_slug_quarantine_purge_v1()'::regprocedure,'public.specialist_slug_quarantine_v1()'::regprocedure,'public.specialist_suspend_public_v1(uuid, text)'::regprocedure,'public.sync_profile_slug_registry()'::regprocedure,'public.unpublish_my_specialist_v1(uuid)'::regprocedure,'public.update_my_company_profile(uuid, text, text, text, text, text, text)'::regprocedure,'public.update_my_specialist_draft(uuid, text, text, text, text, text)'::regprocedure)),
'triggers',(SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,t.tgname,pg_get_triggerdef(t.oid,true),t.tgenabled) ORDER BY n.nspname,c.relname,t.tgname) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND c.oid IN('public.audit_log'::regclass,'public.companies'::regclass,'public.company_access_invitations'::regclass,'public.company_locations'::regclass,'public.company_media'::regclass,'public.company_memberships'::regclass,'public.company_services'::regclass,'public.profile_slug_registry'::regclass,'public.specialist_channel_sets'::regclass,'public.specialist_contact_channels'::regclass,'public.specialist_erasure_authorizations'::regclass,'public.specialist_erasure_confirmations'::regclass,'public.specialist_media'::regclass,'public.specialist_operator_identities'::regclass,'public.specialist_profiles'::regclass,'public.specialist_public_control'::regclass,'public.specialist_public_operator_audit_v1'::regclass,'public.specialist_public_revisions'::regclass,'public.specialist_publication_state'::regclass,'public.specialist_publish_requests_v1'::regclass,'public.specialist_reserved_slugs_v1'::regclass,'public.specialist_revision_details_v1'::regclass,'public.specialist_services'::regclass,'public.specialist_settings'::regclass,'public.specialist_slug_tombstones_v1'::regclass,'public.specialist_upload_audit'::regclass,'public.specialist_upload_control'::regclass,'public.specialist_upload_reservations'::regclass,'public.test_publish_events'::regclass)),
'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY p.schemaname,p.tablename,p.policyname) FROM pg_policies p WHERE p.schemaname='public' AND p.tablename IN('audit_log','companies','company_access_invitations','company_locations','company_media','company_memberships','company_services','profile_slug_registry','specialist_channel_sets','specialist_contact_channels','specialist_erasure_authorizations','specialist_erasure_confirmations','specialist_media','specialist_operator_identities','specialist_profiles','specialist_public_control','specialist_public_operator_audit_v1','specialist_public_revisions','specialist_publication_state','specialist_publish_requests_v1','specialist_reserved_slugs_v1','specialist_revision_details_v1','specialist_services','specialist_settings','specialist_slug_tombstones_v1','specialist_upload_audit','specialist_upload_control','specialist_upload_reservations','test_publish_events'))
)::text) fingerprint) IS DISTINCT FROM 'a3176df25a276840b49bb395a1cefe2b' THEN RAISE EXCEPTION 'staging baseline catalog drift; recapture and review before migration'; END IF;
IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='private') THEN RAISE EXCEPTION 'unexpected private schema; existing schema ACL must not be changed'; END IF;
END $preflight$;

CREATE SCHEMA private;
REVOKE ALL ON SCHEMA private FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
CREATE TABLE "private"."actors" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "actor_type" text NOT NULL,
 "person_id" uuid,
 "external_ref" text,
 "display_label" text,
 "active" boolean DEFAULT true NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."compatibility_flags_v1" (
 "key" text NOT NULL,
 "enabled" boolean NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
 "note" text
);
CREATE TABLE "private"."embedding_projection_refs_v1" (
 "company_id" uuid NOT NULL,
 "entity_type" text NOT NULL,
 "entity_id" uuid NOT NULL,
 "entity_version" bigint NOT NULL,
 "variant_id" uuid NOT NULL,
 "model_version" text NOT NULL,
 "vector_ref" text NOT NULL,
 "content_hash" text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "erased_at" timestamp with time zone
);
CREATE TABLE "private"."erasure_projection_receipts_v1" (
 "erasure_request_id" uuid NOT NULL,
 "consumer_key" text NOT NULL,
 "status" text DEFAULT 'pending'::text NOT NULL,
 "processed_at" timestamp with time zone,
 "detail_hash" text
);
CREATE TABLE "private"."erasure_requests" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "person_id" uuid NOT NULL,
 "status" text DEFAULT 'requested'::text NOT NULL,
 "requested_at" timestamp with time zone DEFAULT now() NOT NULL,
 "completed_at" timestamp with time zone,
 "reason" text
);
CREATE TABLE "private"."external_sources_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "source_type" text NOT NULL,
 "name" text NOT NULL,
 "canonical_ref" text NOT NULL,
 "status" text DEFAULT 'active'::text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."external_sync_runs_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "external_source_id" uuid NOT NULL,
 "status" text DEFAULT 'running'::text NOT NULL,
 "started_at" timestamp with time zone DEFAULT now() NOT NULL,
 "finished_at" timestamp with time zone,
 "source_checksum" text,
 "error_summary" text
);
CREATE TABLE "private"."knowledge_change_proposals_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "concept_id" uuid NOT NULL,
 "proposed_by_actor_id" uuid,
 "status" text DEFAULT 'draft'::text NOT NULL,
 "proposed_title" text,
 "proposed_body" text NOT NULL,
 "language" text NOT NULL,
 "reason" text,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
 "decided_at" timestamp with time zone
);
CREATE TABLE "private"."knowledge_concepts_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "concept_type" text DEFAULT 'faq'::text NOT NULL,
 "scope_type" text DEFAULT 'company'::text NOT NULL,
 "branch_id" uuid,
 "service_id" uuid,
 "authority" text NOT NULL,
 "external_source_id" uuid,
 "replaces_concept_id" uuid,
 "status" text DEFAULT 'active'::text NOT NULL,
 "created_by_actor_id" uuid,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."knowledge_publications_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "concept_id" uuid NOT NULL,
 "variant_id" uuid NOT NULL,
 "audience" text NOT NULL,
 "language" text NOT NULL,
 "status" text DEFAULT 'published'::text NOT NULL,
 "published_by_actor_id" uuid,
 "published_at" timestamp with time zone DEFAULT now() NOT NULL,
 "withdrawn_at" timestamp with time zone
);
CREATE TABLE "private"."knowledge_source_links_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "knowledge_version_id" uuid NOT NULL,
 "statement_revision_id" uuid,
 "external_source_id" uuid,
 "external_ref" text,
 "note" text,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."knowledge_variants_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "version_id" uuid NOT NULL,
 "language" text NOT NULL,
 "title" text,
 "body" text NOT NULL,
 "origin" text NOT NULL,
 "source_checksum" text NOT NULL,
 "verification_status" text DEFAULT 'unverified'::text NOT NULL,
 "verified_by_actor_id" uuid,
 "verified_at" timestamp with time zone,
 "review_due_at" timestamp with time zone,
 "actor_id" uuid,
 "provenance" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."knowledge_versions_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "concept_id" uuid NOT NULL,
 "version" integer NOT NULL,
 "source_language" text NOT NULL,
 "source_title" text,
 "source_body" text NOT NULL,
 "content_checksum" text NOT NULL,
 "status" text DEFAULT 'draft'::text NOT NULL,
 "actor_id" uuid,
 "provenance" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."legal_holds" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "person_id" uuid,
 "company_id" uuid,
 "status" text DEFAULT 'active'::text NOT NULL,
 "reason" text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "released_at" timestamp with time zone
);
CREATE TABLE "private"."moderation_actions_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "case_id" uuid NOT NULL,
 "actor_id" uuid,
 "action" text NOT NULL,
 "reason" text,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."moderation_cases_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "target_kind" text NOT NULL,
 "target_id" uuid NOT NULL,
 "status" text DEFAULT 'open'::text NOT NULL,
 "reason_code" text NOT NULL,
 "opened_by_actor_id" uuid,
 "opened_at" timestamp with time zone DEFAULT now() NOT NULL,
 "resolved_at" timestamp with time zone
);
CREATE TABLE "private"."moderation_operators" (
 "user_id" uuid NOT NULL,
 "role" text DEFAULT 'moderator'::text NOT NULL,
 "active" boolean DEFAULT true NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."official_statements_v2" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "review_id" uuid,
 "question_id" uuid,
 "current_draft_revision_id" uuid,
 "current_published_revision_id" uuid,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."outbox_events_v1" (
 "event_id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "event_type" text NOT NULL,
 "aggregate_type" text NOT NULL,
 "aggregate_id" uuid NOT NULL,
 "company_id" uuid NOT NULL,
 "aggregate_version" bigint NOT NULL,
 "actor_id" uuid,
 "schema_version" integer DEFAULT 1 NOT NULL,
 "payload_refs" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "occurred_at" timestamp with time zone DEFAULT now() NOT NULL,
 "published_at" timestamp with time zone,
 "attempts" integer DEFAULT 0 NOT NULL,
 "last_error" text
);
CREATE TABLE "private"."own_review_rate_limits" (
 "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
 "company_id" uuid NOT NULL,
 "source_ip_hash" text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."own_review_submissions" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "request_id" uuid NOT NULL,
 "company_id" uuid NOT NULL,
 "location_id" uuid,
 "author_display_name" text NOT NULL,
 "author_email" text NOT NULL,
 "rating" smallint NOT NULL,
 "body" text NOT NULL,
 "language" text DEFAULT 'ru'::text NOT NULL,
 "experience_confirmed_at" timestamp with time zone NOT NULL,
 "terms_accepted_at" timestamp with time zone NOT NULL,
 "terms_version" text NOT NULL,
 "privacy_accepted_at" timestamp with time zone NOT NULL,
 "privacy_version" text NOT NULL,
 "source_ip_hash" text,
 "user_agent" text,
 "status" text DEFAULT 'draft'::text NOT NULL,
 "moderator_notes" text,
 "moderated_at" timestamp with time zone,
 "published_review_id" uuid,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
 "ai_moderation_status" text DEFAULT 'pending'::text NOT NULL,
 "ai_risk_score" numeric,
 "ai_flags" jsonb DEFAULT '[]'::jsonb NOT NULL,
 "ai_summary" text,
 "ai_moderated_at" timestamp with time zone
);
CREATE TABLE "private"."persons" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "auth_user_id" uuid,
 "erased_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."projection_consumers_v1" (
 "consumer_key" text NOT NULL,
 "projection_type" text NOT NULL,
 "erasure_required" boolean DEFAULT true NOT NULL,
 "active" boolean DEFAULT true NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."projection_receipts_v1" (
 "consumer_key" text NOT NULL,
 "event_id" uuid NOT NULL,
 "processed_at" timestamp with time zone DEFAULT now() NOT NULL,
 "result_hash" text
);
CREATE TABLE "private"."public_author_person_links" (
 "public_author_id" uuid NOT NULL,
 "person_id" uuid NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."question_messages_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "question_id" uuid NOT NULL,
 "actor_id" uuid,
 "body_original" text,
 "body_public" text,
 "language" text DEFAULT 'ru'::text NOT NULL,
 "content_hash" text NOT NULL,
 "visibility" text DEFAULT 'private'::text NOT NULL,
 "erased_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."question_revisions_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "question_id" uuid NOT NULL,
 "version" integer NOT NULL,
 "body_original" text,
 "body_public" text,
 "language" text DEFAULT 'ru'::text NOT NULL,
 "content_hash" text NOT NULL,
 "actor_id" uuid,
 "provenance" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "redaction_status" text DEFAULT 'none'::text NOT NULL,
 "redaction_reason" text,
 "redacted_at" timestamp with time zone,
 "erased_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."questions_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "public_author_id" uuid,
 "status" text DEFAULT 'pending'::text NOT NULL,
 "current_revision_id" uuid,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
 "answered_at" timestamp with time zone,
 "legacy_qna_id" uuid,
 "category" text,
 "program_label" text
);
CREATE TABLE "private"."review_revisions_v1" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "review_id" uuid NOT NULL,
 "version" integer NOT NULL,
 "body_original" text,
 "body_public" text,
 "language" text DEFAULT 'ru'::text NOT NULL,
 "content_hash" text NOT NULL,
 "actor_id" uuid,
 "provenance" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "redaction_status" text DEFAULT 'none'::text NOT NULL,
 "redaction_reason" text,
 "redacted_at" timestamp with time zone,
 "erased_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."review_source_sync_jobs" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "source_id" uuid NOT NULL,
 "status" text DEFAULT 'pending'::text NOT NULL,
 "requested_at" timestamp with time zone DEFAULT now() NOT NULL,
 "started_at" timestamp with time zone,
 "finished_at" timestamp with time zone,
 "attempt_count" integer DEFAULT 0 NOT NULL,
 "result_snapshot_id" uuid,
 "error_code" text,
 "error_message" text,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "private"."statement_revisions_v2" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "official_statement_id" uuid NOT NULL,
 "version" integer NOT NULL,
 "body" text NOT NULL,
 "status" text DEFAULT 'draft'::text NOT NULL,
 "responds_to_review_revision_id" uuid,
 "actor_id" uuid,
 "on_behalf_of_actor_id" uuid,
 "approved_by_actor_id" uuid,
 "generation_run_id" uuid,
 "provenance" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "published_at" timestamp with time zone
);
CREATE TABLE "private"."verification_evidence" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid,
 "public_author_id" uuid,
 "evidence_type" text NOT NULL,
 "status" text DEFAULT 'pending'::text NOT NULL,
 "evidence_ref" text,
 "retention_until" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "verified_at" timestamp with time zone,
 "erased_at" timestamp with time zone
);
CREATE TABLE "public"."company_profile_public_access" (
 "company_id" uuid NOT NULL,
 "state" text DEFAULT 'inactive'::text NOT NULL,
 "review_intake_enabled" boolean DEFAULT false NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "public"."company_profile_publications" (
 "company_id" uuid NOT NULL,
 "slug" text NOT NULL,
 "requested_at" timestamp with time zone,
 "started_at" timestamp with time zone,
 "completed_at" timestamp with time zone,
 "status" text DEFAULT 'queued'::text NOT NULL,
 "source_revision" text,
 "artifact_revision" text,
 "workflow_run_id" bigint,
 "error_code" text,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "public"."company_questions_answers" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "question" text NOT NULL,
 "answer" text NOT NULL,
 "scope_type" text,
 "category" text,
 "program_label" text,
 "source_system" text DEFAULT 'otzovik'::text NOT NULL,
 "source_ref" text,
 "provenance" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "status" text DEFAULT 'draft'::text NOT NULL,
 "answered_at" timestamp with time zone,
 "published_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "public"."company_statements" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "user_id" uuid NOT NULL,
 "review_id" text NOT NULL,
 "statement" text NOT NULL,
 "status" text DEFAULT 'submitted'::text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "public"."review_service_links" (
 "review_id" uuid NOT NULL,
 "service_id" uuid NOT NULL
);
CREATE TABLE "public"."review_sources" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "location_id" uuid,
 "name" text NOT NULL,
 "source_type" text NOT NULL,
 "profile_url" text NOT NULL,
 "collection_method" text NOT NULL,
 "terms_notes" text,
 "status" text DEFAULT 'published'::text NOT NULL,
 "checked_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "public"."reviews" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "company_id" uuid NOT NULL,
 "source_id" uuid NOT NULL,
 "location_id" uuid,
 "source_review_id" text,
 "source_url" text NOT NULL,
 "author_display_name" text,
 "published_at" timestamp with time zone,
 "source_updated_at" timestamp with time zone,
 "collected_at" timestamp with time zone NOT NULL,
 "rating" numeric(4,2),
 "rating_scale" numeric(4,2) DEFAULT 5,
 "excerpt" text,
 "language" text DEFAULT 'ru'::text NOT NULL,
 "content_hash" text NOT NULL,
 "provenance" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "status" text DEFAULT 'draft'::text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
 "body" text NOT NULL
);
CREATE TABLE "public"."source_ratings" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "source_id" uuid NOT NULL,
 "rating" numeric(4,2) NOT NULL,
 "rating_scale" numeric(4,2) DEFAULT 5 NOT NULL,
 "rating_count" integer,
 "review_count" integer,
 "checked_at" timestamp with time zone NOT NULL,
 "status" text DEFAULT 'published'::text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "public"."public_authors" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "display_name" text,
 "status" text DEFAULT 'active'::text NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE UNIQUE INDEX company_locations_company_id_id_uq ON public.company_locations USING btree(company_id,id);
CREATE UNIQUE INDEX company_services_company_id_id_uq ON public.company_services USING btree(company_id,id);
ALTER TABLE "private"."actors" ADD CONSTRAINT "actors_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."compatibility_flags_v1" ADD CONSTRAINT "compatibility_flags_v1_pkey" PRIMARY KEY (key);
ALTER TABLE "private"."embedding_projection_refs_v1" ADD CONSTRAINT "embedding_projection_refs_v1_pkey" PRIMARY KEY (company_id, entity_type, entity_id, entity_version, model_version, variant_id);
ALTER TABLE "private"."erasure_projection_receipts_v1" ADD CONSTRAINT "erasure_projection_receipts_v1_pkey" PRIMARY KEY (erasure_request_id, consumer_key);
ALTER TABLE "private"."erasure_requests" ADD CONSTRAINT "erasure_requests_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."external_sources_v1" ADD CONSTRAINT "external_sources_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."external_sync_runs_v1" ADD CONSTRAINT "external_sync_runs_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."knowledge_change_proposals_v1" ADD CONSTRAINT "knowledge_change_proposals_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."knowledge_publications_v1" ADD CONSTRAINT "knowledge_publications_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."knowledge_source_links_v1" ADD CONSTRAINT "knowledge_source_links_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."legal_holds" ADD CONSTRAINT "legal_holds_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."moderation_actions_v1" ADD CONSTRAINT "moderation_actions_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."moderation_cases_v1" ADD CONSTRAINT "moderation_cases_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."moderation_operators" ADD CONSTRAINT "moderation_operators_pkey" PRIMARY KEY (user_id);
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_pkey" PRIMARY KEY (event_id);
ALTER TABLE "private"."own_review_rate_limits" ADD CONSTRAINT "own_review_rate_limits_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."persons" ADD CONSTRAINT "persons_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."projection_consumers_v1" ADD CONSTRAINT "projection_consumers_v1_pkey" PRIMARY KEY (consumer_key);
ALTER TABLE "private"."projection_receipts_v1" ADD CONSTRAINT "projection_receipts_v1_pkey" PRIMARY KEY (consumer_key, event_id);
ALTER TABLE "private"."public_author_person_links" ADD CONSTRAINT "public_author_person_links_pkey" PRIMARY KEY (public_author_id);
ALTER TABLE "private"."question_messages_v1" ADD CONSTRAINT "question_messages_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."questions_v1" ADD CONSTRAINT "questions_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."review_source_sync_jobs" ADD CONSTRAINT "review_source_sync_jobs_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."verification_evidence" ADD CONSTRAINT "verification_evidence_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."company_profile_public_access" ADD CONSTRAINT "company_profile_public_access_pkey" PRIMARY KEY (company_id);
ALTER TABLE "public"."company_profile_publications" ADD CONSTRAINT "company_profile_publications_pkey" PRIMARY KEY (company_id);
ALTER TABLE "public"."company_questions_answers" ADD CONSTRAINT "company_questions_answers_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."company_statements" ADD CONSTRAINT "company_statements_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."review_service_links" ADD CONSTRAINT "review_service_links_pkey" PRIMARY KEY (review_id, service_id);
ALTER TABLE "public"."review_sources" ADD CONSTRAINT "review_sources_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."public_authors" ADD CONSTRAINT "public_authors_pkey" PRIMARY KEY (id);
ALTER TABLE "private"."external_sources_v1" ADD CONSTRAINT "external_sources_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."external_sources_v1" ADD CONSTRAINT "external_sources_v1_company_id_source_type_canonical_ref_key" UNIQUE (company_id, source_type, canonical_ref);
ALTER TABLE "private"."external_sync_runs_v1" ADD CONSTRAINT "external_sync_runs_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."knowledge_change_proposals_v1" ADD CONSTRAINT "knowledge_change_proposals_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."knowledge_publications_v1" ADD CONSTRAINT "knowledge_publications_v1_company_id_concept_id_audience_la_key" UNIQUE (company_id, concept_id, audience, language);
ALTER TABLE "private"."knowledge_source_links_v1" ADD CONSTRAINT "knowledge_source_links_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_company_id_version_id_language_key" UNIQUE (company_id, version_id, language);
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_company_id_concept_id_version_key" UNIQUE (company_id, concept_id, version);
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_aggregate_type_aggregate_id_aggregate_vers_key" UNIQUE (aggregate_type, aggregate_id, aggregate_version, event_type);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_request_id_key" UNIQUE (request_id);
ALTER TABLE "private"."persons" ADD CONSTRAINT "persons_auth_user_id_key" UNIQUE (auth_user_id);
ALTER TABLE "private"."question_messages_v1" ADD CONSTRAINT "question_messages_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_company_id_question_id_version_key" UNIQUE (company_id, question_id, version);
ALTER TABLE "private"."questions_v1" ADD CONSTRAINT "questions_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_company_id_review_id_version_key" UNIQUE (company_id, review_id, version);
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_company_id_id_key" UNIQUE (company_id, id);
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_company_id_official_statement_id_ver_key" UNIQUE (company_id, official_statement_id, version);
ALTER TABLE "public"."company_questions_answers" ADD CONSTRAINT "company_questions_answers_company_id_source_system_source_r_key" UNIQUE (company_id, source_system, source_ref);
ALTER TABLE "public"."review_sources" ADD CONSTRAINT "review_sources_company_id_profile_url_key" UNIQUE (company_id, profile_url);
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_source_id_content_hash_key" UNIQUE (source_id, content_hash);
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_source_id_source_review_id_key" UNIQUE (source_id, source_review_id);
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_source_id_checked_at_key" UNIQUE (source_id, checked_at);
ALTER TABLE "private"."actors" ADD CONSTRAINT "actors_actor_type_check" CHECK (actor_type = ANY (ARRAY['human'::text, 'ai_agent'::text, 'system'::text, 'platform_moderator'::text]));
ALTER TABLE "private"."actors" ADD CONSTRAINT "actors_check" CHECK ((actor_type = ANY (ARRAY['human'::text, 'platform_moderator'::text])) AND person_id IS NOT NULL OR (actor_type = ANY (ARRAY['ai_agent'::text, 'system'::text])));
ALTER TABLE "private"."embedding_projection_refs_v1" ADD CONSTRAINT "embedding_projection_refs_v1_entity_version_check" CHECK (entity_version > 0);
ALTER TABLE "private"."erasure_projection_receipts_v1" ADD CONSTRAINT "erasure_projection_receipts_v1_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'not_applicable'::text]));
ALTER TABLE "private"."erasure_requests" ADD CONSTRAINT "erasure_requests_status_check" CHECK (status = ANY (ARRAY['requested'::text, 'processing'::text, 'completed'::text, 'rejected'::text, 'cancelled'::text]));
ALTER TABLE "private"."external_sources_v1" ADD CONSTRAINT "external_sources_v1_status_check" CHECK (status = ANY (ARRAY['active'::text, 'paused'::text, 'retired'::text]));
ALTER TABLE "private"."external_sync_runs_v1" ADD CONSTRAINT "external_sync_runs_v1_status_check" CHECK (status = ANY (ARRAY['running'::text, 'succeeded'::text, 'failed'::text, 'partial'::text]));
ALTER TABLE "private"."knowledge_change_proposals_v1" ADD CONSTRAINT "knowledge_change_proposals_v1_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'submitted'::text, 'accepted'::text, 'rejected'::text, 'expired'::text, 'synced'::text]));
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_authority_check" CHECK (authority = ANY (ARRAY['native'::text, 'external'::text]));
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_check" CHECK (scope_type = 'company'::text AND branch_id IS NULL AND service_id IS NULL OR scope_type = 'branch'::text AND branch_id IS NOT NULL AND service_id IS NULL OR scope_type = 'service'::text AND service_id IS NOT NULL AND branch_id IS NULL);
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_check1" CHECK (authority = 'native'::text AND external_source_id IS NULL OR authority = 'external'::text AND external_source_id IS NOT NULL);
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_scope_type_check" CHECK (scope_type = ANY (ARRAY['company'::text, 'branch'::text, 'service'::text]));
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_status_check" CHECK (status = ANY (ARRAY['active'::text, 'superseded'::text, 'retired'::text]));
ALTER TABLE "private"."knowledge_publications_v1" ADD CONSTRAINT "knowledge_publications_v1_audience_check" CHECK (audience = ANY (ARRAY['public'::text, 'company_ai'::text, 'internal'::text]));
ALTER TABLE "private"."knowledge_publications_v1" ADD CONSTRAINT "knowledge_publications_v1_status_check" CHECK (status = ANY (ARRAY['published'::text, 'withdrawn'::text]));
ALTER TABLE "private"."knowledge_source_links_v1" ADD CONSTRAINT "knowledge_source_links_v1_check" CHECK (((statement_revision_id IS NOT NULL)::integer + (external_source_id IS NOT NULL)::integer) = 1);
ALTER TABLE "private"."knowledge_source_links_v1" ADD CONSTRAINT "knowledge_source_links_v1_check1" CHECK (external_source_id IS NULL OR external_ref IS NOT NULL);
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_check" CHECK (verification_status = 'verified'::text AND verified_by_actor_id IS NOT NULL AND verified_at IS NOT NULL OR verification_status <> 'verified'::text);
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_origin_check" CHECK (origin = ANY (ARRAY['human'::text, 'machine'::text]));
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_provenance_check" CHECK (jsonb_typeof(provenance) = 'object'::text);
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_verification_status_check" CHECK (verification_status = ANY (ARRAY['unverified'::text, 'verified'::text, 'rejected'::text, 'stale'::text]));
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_provenance_check" CHECK (jsonb_typeof(provenance) = 'object'::text);
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'current'::text, 'superseded'::text, 'retired'::text]));
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_version_check" CHECK (version > 0);
ALTER TABLE "private"."legal_holds" ADD CONSTRAINT "legal_holds_check" CHECK (person_id IS NOT NULL OR company_id IS NOT NULL);
ALTER TABLE "private"."legal_holds" ADD CONSTRAINT "legal_holds_status_check" CHECK (status = ANY (ARRAY['active'::text, 'released'::text]));
ALTER TABLE "private"."moderation_cases_v1" ADD CONSTRAINT "moderation_cases_v1_status_check" CHECK (status = ANY (ARRAY['open'::text, 'reviewing'::text, 'resolved'::text, 'dismissed'::text]));
ALTER TABLE "private"."moderation_operators" ADD CONSTRAINT "moderation_operators_role_check" CHECK (role = ANY (ARRAY['moderator'::text, 'admin'::text]));
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_check" CHECK (((review_id IS NOT NULL)::integer + (question_id IS NOT NULL)::integer) = 1);
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_aggregate_version_check" CHECK (aggregate_version > 0);
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_attempts_check" CHECK (attempts >= 0);
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_payload_refs_check" CHECK (jsonb_typeof(payload_refs) = 'object'::text);
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_schema_version_check" CHECK (schema_version > 0);
ALTER TABLE "private"."own_review_rate_limits" ADD CONSTRAINT "own_review_rate_limits_source_ip_hash_check" CHECK (source_ip_hash ~ '^[0-9a-f]{64}$'::text);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_ai_moderation_status_check" CHECK (ai_moderation_status = ANY (ARRAY['pending'::text, 'passed'::text, 'flagged'::text, 'failed'::text]));
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_ai_risk_score_check" CHECK (ai_risk_score IS NULL OR ai_risk_score >= 0::numeric AND ai_risk_score <= 1::numeric);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_body_length" CHECK (char_length(btrim(body)) >= 50 AND char_length(btrim(body)) <= 5000);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_display_name_length" CHECK (char_length(btrim(author_display_name)) >= 2 AND char_length(btrim(author_display_name)) <= 80);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_email_format" CHECK (author_email ~* '^[A-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$'::text);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_email_length" CHECK (char_length(author_email) >= 3 AND char_length(author_email) <= 254);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_ip_hash_format" CHECK (source_ip_hash IS NULL OR source_ip_hash ~ '^[a-f0-9]{64}$'::text);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_language_format" CHECK (language ~ '^[a-z]{2}(-[A-Z]{2})?$'::text);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_privacy_version_required" CHECK (char_length(btrim(privacy_version)) >= 1 AND char_length(btrim(privacy_version)) <= 80);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_published_link" CHECK ((status = ANY (ARRAY['published'::text, 'removed'::text])) AND published_review_id IS NOT NULL OR (status <> ALL (ARRAY['published'::text, 'removed'::text])) AND published_review_id IS NULL);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_rating_range" CHECK (rating >= 1 AND rating <= 5);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_status" CHECK (status = ANY (ARRAY['draft'::text, 'verified'::text, 'rejected'::text, 'published'::text, 'disputed'::text, 'removed'::text]));
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_terms_version_required" CHECK (char_length(btrim(terms_version)) >= 1 AND char_length(btrim(terms_version)) <= 80);
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_user_agent_length" CHECK (user_agent IS NULL OR char_length(user_agent) <= 500);
ALTER TABLE "private"."projection_consumers_v1" ADD CONSTRAINT "projection_consumers_v1_projection_type_check" CHECK (projection_type = ANY (ARRAY['public_read'::text, 'search'::text, 'embedding'::text, 'export'::text, 'other'::text]));
ALTER TABLE "private"."question_messages_v1" ADD CONSTRAINT "question_messages_v1_check" CHECK (body_public IS NOT NULL OR erased_at IS NOT NULL);
ALTER TABLE "private"."question_messages_v1" ADD CONSTRAINT "question_messages_v1_visibility_check" CHECK (visibility = 'private'::text);
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_check" CHECK (body_public IS NOT NULL OR erased_at IS NOT NULL);
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_check1" CHECK (body_original IS NOT NULL OR erased_at IS NOT NULL);
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_provenance_check" CHECK (jsonb_typeof(provenance) = 'object'::text);
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_redaction_status_check" CHECK (redaction_status = ANY (ARRAY['none'::text, 'privacy_redacted'::text, 'legal_redacted'::text, 'moderation_redacted'::text, 'erased'::text]));
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_version_check" CHECK (version > 0);
ALTER TABLE "private"."questions_v1" ADD CONSTRAINT "questions_v1_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'needs_clarification'::text, 'answered'::text, 'rejected'::text, 'merged'::text, 'hidden'::text, 'archived'::text]));
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_check" CHECK (body_public IS NOT NULL OR erased_at IS NOT NULL);
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_check1" CHECK (body_original IS NOT NULL OR erased_at IS NOT NULL);
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_provenance_check" CHECK (jsonb_typeof(provenance) = 'object'::text);
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_redaction_status_check" CHECK (redaction_status = ANY (ARRAY['none'::text, 'privacy_redacted'::text, 'legal_redacted'::text, 'moderation_redacted'::text, 'erased'::text]));
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_version_check" CHECK (version > 0);
ALTER TABLE "private"."review_source_sync_jobs" ADD CONSTRAINT "review_source_sync_jobs_attempt_count_check" CHECK (attempt_count >= 0);
ALTER TABLE "private"."review_source_sync_jobs" ADD CONSTRAINT "review_source_sync_jobs_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'running'::text, 'succeeded'::text, 'failed'::text]));
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_body_check" CHECK (length(TRIM(BOTH FROM body)) >= 1 AND length(TRIM(BOTH FROM body)) <= 10000);
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_provenance_check" CHECK (jsonb_typeof(provenance) = 'object'::text);
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'superseded'::text, 'retracted'::text, 'hidden'::text]));
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_version_check" CHECK (version > 0);
ALTER TABLE "private"."verification_evidence" ADD CONSTRAINT "verification_evidence_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'verified'::text, 'rejected'::text, 'expired'::text, 'erased'::text]));
ALTER TABLE "public"."company_profile_public_access" ADD CONSTRAINT "company_profile_public_access_state_check" CHECK (state = ANY (ARRAY['active'::text, 'inactive'::text, 'suspended'::text]));
ALTER TABLE "public"."company_profile_publications" ADD CONSTRAINT "company_profile_publications_status_check" CHECK (status = ANY (ARRAY['queued'::text, 'building'::text, 'published'::text, 'failed'::text]));
ALTER TABLE "public"."company_questions_answers" ADD CONSTRAINT "company_questions_answers_answer_check" CHECK (char_length(btrim(answer)) >= 1 AND char_length(btrim(answer)) <= 10000);
ALTER TABLE "public"."company_questions_answers" ADD CONSTRAINT "company_questions_answers_question_check" CHECK (char_length(btrim(question)) >= 3 AND char_length(btrim(question)) <= 2000);
ALTER TABLE "public"."company_questions_answers" ADD CONSTRAINT "company_questions_answers_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text]));
ALTER TABLE "public"."company_statements" ADD CONSTRAINT "company_statements_review_id_uuid_format" CHECK (review_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'::text);
ALTER TABLE "public"."company_statements" ADD CONSTRAINT "company_statements_status_check" CHECK (status = ANY (ARRAY['submitted'::text, 'under_review'::text, 'published'::text, 'rejected'::text]));
ALTER TABLE "public"."review_sources" ADD CONSTRAINT "review_sources_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text]));
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_rating_check" CHECK (rating IS NULL OR rating >= 0::numeric);
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_rating_scale_check" CHECK (rating_scale IS NULL OR rating_scale > 0::numeric);
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'removed'::text, 'disputed'::text, 'archived'::text]));
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_rating_check" CHECK (rating >= 0::numeric);
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_rating_count_check" CHECK (rating_count >= 0);
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_rating_scale_check" CHECK (rating_scale > 0::numeric);
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_review_count_check" CHECK (review_count >= 0);
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text]));
ALTER TABLE "public"."public_authors" ADD CONSTRAINT "public_authors_status_check" CHECK (status = ANY (ARRAY['active'::text, 'anonymized'::text, 'suspended'::text]));
CREATE UNIQUE INDEX actors_human_person_type_uq ON private.actors USING btree (person_id, actor_type) WHERE (person_id IS NOT NULL);
CREATE INDEX embedding_projection_refs_v1_entity_idx ON private.embedding_projection_refs_v1 USING btree (company_id, entity_type, entity_id, erased_at);
CREATE INDEX erasure_projection_receipts_v1_status_idx ON private.erasure_projection_receipts_v1 USING btree (status, consumer_key);
CREATE INDEX external_sync_runs_v1_source_idx ON private.external_sync_runs_v1 USING btree (company_id, external_source_id, started_at DESC);
CREATE INDEX knowledge_change_proposals_v1_actor_idx ON private.knowledge_change_proposals_v1 USING btree (proposed_by_actor_id) WHERE (proposed_by_actor_id IS NOT NULL);
CREATE INDEX knowledge_change_proposals_v1_status_idx ON private.knowledge_change_proposals_v1 USING btree (company_id, status, updated_at DESC);
CREATE INDEX knowledge_concepts_v1_actor_idx ON private.knowledge_concepts_v1 USING btree (created_by_actor_id) WHERE (created_by_actor_id IS NOT NULL);
CREATE INDEX knowledge_concepts_v1_branch_idx ON private.knowledge_concepts_v1 USING btree (company_id, branch_id) WHERE (branch_id IS NOT NULL);
CREATE INDEX knowledge_concepts_v1_company_scope_idx ON private.knowledge_concepts_v1 USING btree (company_id, scope_type, status);
CREATE INDEX knowledge_concepts_v1_external_idx ON private.knowledge_concepts_v1 USING btree (company_id, external_source_id) WHERE (external_source_id IS NOT NULL);
CREATE INDEX knowledge_concepts_v1_replaces_idx ON private.knowledge_concepts_v1 USING btree (company_id, replaces_concept_id) WHERE (replaces_concept_id IS NOT NULL);
CREATE INDEX knowledge_concepts_v1_service_idx ON private.knowledge_concepts_v1 USING btree (company_id, service_id) WHERE (service_id IS NOT NULL);
CREATE INDEX knowledge_publications_v1_actor_idx ON private.knowledge_publications_v1 USING btree (published_by_actor_id) WHERE (published_by_actor_id IS NOT NULL);
CREATE INDEX knowledge_publications_v1_public_idx ON private.knowledge_publications_v1 USING btree (company_id, audience, status, language);
CREATE INDEX knowledge_publications_v1_variant_idx ON private.knowledge_publications_v1 USING btree (company_id, variant_id);
CREATE INDEX knowledge_source_links_v1_external_idx ON private.knowledge_source_links_v1 USING btree (company_id, external_source_id) WHERE (external_source_id IS NOT NULL);
CREATE INDEX knowledge_source_links_v1_statement_idx ON private.knowledge_source_links_v1 USING btree (company_id, statement_revision_id) WHERE (statement_revision_id IS NOT NULL);
CREATE INDEX knowledge_variants_v1_actor_idx ON private.knowledge_variants_v1 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE INDEX knowledge_variants_v1_verified_actor_idx ON private.knowledge_variants_v1 USING btree (verified_by_actor_id) WHERE (verified_by_actor_id IS NOT NULL);
CREATE INDEX knowledge_versions_v1_actor_idx ON private.knowledge_versions_v1 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE UNIQUE INDEX knowledge_versions_v1_one_current_uq ON private.knowledge_versions_v1 USING btree (company_id, concept_id) WHERE (status = 'current'::text);
CREATE INDEX legal_holds_company_idx ON private.legal_holds USING btree (company_id) WHERE (company_id IS NOT NULL);
CREATE INDEX legal_holds_person_idx ON private.legal_holds USING btree (person_id) WHERE (person_id IS NOT NULL);
CREATE INDEX moderation_actions_v1_actor_idx ON private.moderation_actions_v1 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE INDEX moderation_actions_v1_case_idx ON private.moderation_actions_v1 USING btree (case_id);
CREATE INDEX moderation_cases_v1_actor_idx ON private.moderation_cases_v1 USING btree (opened_by_actor_id) WHERE (opened_by_actor_id IS NOT NULL);
CREATE INDEX moderation_cases_v1_company_status_idx ON private.moderation_cases_v1 USING btree (company_id, status);
CREATE INDEX official_statements_v2_draft_idx ON private.official_statements_v2 USING btree (company_id, current_draft_revision_id) WHERE (current_draft_revision_id IS NOT NULL);
CREATE INDEX official_statements_v2_published_idx ON private.official_statements_v2 USING btree (company_id, current_published_revision_id) WHERE (current_published_revision_id IS NOT NULL);
CREATE INDEX official_statements_v2_question_idx ON private.official_statements_v2 USING btree (company_id, question_id) WHERE (question_id IS NOT NULL);
CREATE UNIQUE INDEX official_statements_v2_review_target_uq ON private.official_statements_v2 USING btree (company_id, review_id) WHERE (review_id IS NOT NULL);
CREATE INDEX outbox_events_v1_actor_idx ON private.outbox_events_v1 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE INDEX outbox_events_v1_company_idx ON private.outbox_events_v1 USING btree (company_id, occurred_at);
CREATE INDEX outbox_events_v1_unpublished_idx ON private.outbox_events_v1 USING btree (occurred_at, event_id) WHERE (published_at IS NULL);
CREATE INDEX own_review_rate_limits_lookup_idx ON private.own_review_rate_limits USING btree (company_id, source_ip_hash, created_at DESC);
CREATE INDEX own_review_submissions_company_email_created_idx ON private.own_review_submissions USING btree (company_id, lower(author_email), created_at DESC);
CREATE INDEX own_review_submissions_company_status_created_idx ON private.own_review_submissions USING btree (company_id, status, created_at DESC);
CREATE INDEX own_review_submissions_email_created_idx ON private.own_review_submissions USING btree (lower(author_email), created_at DESC);
CREATE INDEX own_review_submissions_ip_created_idx ON private.own_review_submissions USING btree (source_ip_hash, created_at DESC) WHERE (source_ip_hash IS NOT NULL);
CREATE INDEX own_review_submissions_location_id_idx ON private.own_review_submissions USING btree (location_id) WHERE (location_id IS NOT NULL);
CREATE INDEX own_review_submissions_published_review_id_idx ON private.own_review_submissions USING btree (published_review_id) WHERE (published_review_id IS NOT NULL);
CREATE INDEX projection_receipts_v1_event_idx ON private.projection_receipts_v1 USING btree (event_id);
CREATE INDEX public_author_person_links_person_idx ON private.public_author_person_links USING btree (person_id);
CREATE INDEX question_messages_v1_actor_idx ON private.question_messages_v1 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE INDEX question_messages_v1_thread_idx ON private.question_messages_v1 USING btree (company_id, question_id, created_at);
CREATE INDEX question_revisions_v1_actor_idx ON private.question_revisions_v1 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE INDEX questions_v1_author_idx ON private.questions_v1 USING btree (public_author_id) WHERE (public_author_id IS NOT NULL);
CREATE INDEX questions_v1_current_revision_idx ON private.questions_v1 USING btree (company_id, current_revision_id) WHERE (current_revision_id IS NOT NULL);
CREATE UNIQUE INDEX questions_v1_legacy_qna_identity_uq ON private.questions_v1 USING btree (company_id, legacy_qna_id) WHERE (legacy_qna_id IS NOT NULL);
CREATE INDEX review_revisions_v1_actor_idx ON private.review_revisions_v1 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE INDEX review_revisions_v1_review_idx ON private.review_revisions_v1 USING btree (company_id, review_id, version DESC);
CREATE INDEX review_source_sync_jobs_result_snapshot_idx ON private.review_source_sync_jobs USING btree (result_snapshot_id) WHERE (result_snapshot_id IS NOT NULL);
CREATE INDEX review_source_sync_jobs_source_idx ON private.review_source_sync_jobs USING btree (source_id, requested_at DESC);
CREATE INDEX review_source_sync_jobs_status_requested_idx ON private.review_source_sync_jobs USING btree (status, requested_at);
CREATE UNIQUE INDEX review_source_sync_jobs_one_open_per_source_idx ON private.review_source_sync_jobs USING btree (source_id) WHERE (status = ANY (ARRAY['pending'::text, 'running'::text]));
CREATE INDEX statement_revisions_v2_actor_idx ON private.statement_revisions_v2 USING btree (actor_id) WHERE (actor_id IS NOT NULL);
CREATE INDEX statement_revisions_v2_approved_idx ON private.statement_revisions_v2 USING btree (approved_by_actor_id) WHERE (approved_by_actor_id IS NOT NULL);
CREATE INDEX statement_revisions_v2_on_behalf_idx ON private.statement_revisions_v2 USING btree (on_behalf_of_actor_id) WHERE (on_behalf_of_actor_id IS NOT NULL);
CREATE INDEX statement_revisions_v2_review_revision_idx ON private.statement_revisions_v2 USING btree (company_id, responds_to_review_revision_id) WHERE (responds_to_review_revision_id IS NOT NULL);
CREATE UNIQUE INDEX statement_revisions_v2_one_published_uq ON private.statement_revisions_v2 USING btree (company_id, official_statement_id) WHERE (status = 'published'::text);
CREATE INDEX verification_evidence_author_idx ON private.verification_evidence USING btree (public_author_id) WHERE (public_author_id IS NOT NULL);
CREATE INDEX verification_evidence_company_idx ON private.verification_evidence USING btree (company_id) WHERE (company_id IS NOT NULL);
CREATE INDEX company_questions_answers_public_idx ON public.company_questions_answers USING btree (company_id, published_at DESC) WHERE (status = 'published'::text);
CREATE INDEX company_statements_review_id_idx ON public.company_statements USING btree (review_id);
CREATE INDEX company_statements_review_uuid_idx ON public.company_statements USING btree (((review_id)::uuid));
CREATE INDEX idx_company_statements_company_id ON public.company_statements USING btree (company_id);
CREATE INDEX idx_company_statements_user_id ON public.company_statements USING btree (user_id);
CREATE UNIQUE INDEX company_statements_one_active_per_review ON public.company_statements USING btree (company_id, review_id) WHERE (status = ANY (ARRAY['submitted'::text, 'under_review'::text, 'published'::text]));
CREATE INDEX review_service_links_service_id_idx ON public.review_service_links USING btree (service_id);
CREATE INDEX review_sources_company_status_idx ON public.review_sources USING btree (company_id, status);
CREATE INDEX review_sources_location_id_idx ON public.review_sources USING btree (location_id);
CREATE INDEX reviews_company_location_idx ON public.reviews USING btree (company_id, location_id) WHERE (location_id IS NOT NULL);
CREATE INDEX reviews_company_published_idx ON public.reviews USING btree (company_id, published_at DESC) WHERE (status = 'published'::text);
CREATE INDEX reviews_company_status_published_idx ON public.reviews USING btree (company_id, status, published_at DESC);
CREATE INDEX reviews_location_id_idx ON public.reviews USING btree (location_id);
CREATE UNIQUE INDEX reviews_company_id_id_uq ON public.reviews USING btree (company_id, id);
CREATE INDEX source_ratings_source_checked_idx ON public.source_ratings USING btree (source_id, checked_at DESC);
ALTER TABLE "private"."actors" ADD CONSTRAINT "actors_person_id_fkey" FOREIGN KEY (person_id) REFERENCES private.persons(id) ON DELETE SET NULL;
ALTER TABLE "private"."embedding_projection_refs_v1" ADD CONSTRAINT "embedding_projection_refs_v1_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."erasure_projection_receipts_v1" ADD CONSTRAINT "erasure_projection_receipts_v1_consumer_key_fkey" FOREIGN KEY (consumer_key) REFERENCES private.projection_consumers_v1(consumer_key) ON DELETE RESTRICT;
ALTER TABLE "private"."erasure_projection_receipts_v1" ADD CONSTRAINT "erasure_projection_receipts_v1_erasure_request_id_fkey" FOREIGN KEY (erasure_request_id) REFERENCES private.erasure_requests(id) ON DELETE CASCADE;
ALTER TABLE "private"."erasure_requests" ADD CONSTRAINT "erasure_requests_person_id_fkey" FOREIGN KEY (person_id) REFERENCES private.persons(id) ON DELETE CASCADE;
ALTER TABLE "private"."external_sources_v1" ADD CONSTRAINT "external_sources_v1_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."external_sync_runs_v1" ADD CONSTRAINT "external_sync_runs_v1_company_id_external_source_id_fkey" FOREIGN KEY (company_id, external_source_id) REFERENCES private.external_sources_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."knowledge_change_proposals_v1" ADD CONSTRAINT "knowledge_change_proposals_v1_company_id_concept_id_fkey" FOREIGN KEY (company_id, concept_id) REFERENCES private.knowledge_concepts_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."knowledge_change_proposals_v1" ADD CONSTRAINT "knowledge_change_proposals_v1_proposed_by_actor_id_fkey" FOREIGN KEY (proposed_by_actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_company_id_branch_id_fkey" FOREIGN KEY (company_id, branch_id) REFERENCES company_locations(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_company_id_external_source_id_fkey" FOREIGN KEY (company_id, external_source_id) REFERENCES private.external_sources_v1(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_company_id_replaces_concept_id_fkey" FOREIGN KEY (company_id, replaces_concept_id) REFERENCES private.knowledge_concepts_v1(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_company_id_service_id_fkey" FOREIGN KEY (company_id, service_id) REFERENCES company_services(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."knowledge_concepts_v1" ADD CONSTRAINT "knowledge_concepts_v1_created_by_actor_id_fkey" FOREIGN KEY (created_by_actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."knowledge_publications_v1" ADD CONSTRAINT "knowledge_publications_v1_company_id_concept_id_fkey" FOREIGN KEY (company_id, concept_id) REFERENCES private.knowledge_concepts_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."knowledge_publications_v1" ADD CONSTRAINT "knowledge_publications_v1_company_id_variant_id_fkey" FOREIGN KEY (company_id, variant_id) REFERENCES private.knowledge_variants_v1(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."knowledge_publications_v1" ADD CONSTRAINT "knowledge_publications_v1_published_by_actor_id_fkey" FOREIGN KEY (published_by_actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."knowledge_source_links_v1" ADD CONSTRAINT "knowledge_source_links_v1_company_id_external_source_id_fkey" FOREIGN KEY (company_id, external_source_id) REFERENCES private.external_sources_v1(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."knowledge_source_links_v1" ADD CONSTRAINT "knowledge_source_links_v1_company_id_knowledge_version_id_fkey" FOREIGN KEY (company_id, knowledge_version_id) REFERENCES private.knowledge_versions_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."knowledge_source_links_v1" ADD CONSTRAINT "knowledge_source_links_v1_company_id_statement_revision_id_fkey" FOREIGN KEY (company_id, statement_revision_id) REFERENCES private.statement_revisions_v2(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_company_id_version_id_fkey" FOREIGN KEY (company_id, version_id) REFERENCES private.knowledge_versions_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."knowledge_variants_v1" ADD CONSTRAINT "knowledge_variants_v1_verified_by_actor_id_fkey" FOREIGN KEY (verified_by_actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."knowledge_versions_v1" ADD CONSTRAINT "knowledge_versions_v1_company_id_concept_id_fkey" FOREIGN KEY (company_id, concept_id) REFERENCES private.knowledge_concepts_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."legal_holds" ADD CONSTRAINT "legal_holds_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."legal_holds" ADD CONSTRAINT "legal_holds_person_id_fkey" FOREIGN KEY (person_id) REFERENCES private.persons(id) ON DELETE CASCADE;
ALTER TABLE "private"."moderation_actions_v1" ADD CONSTRAINT "moderation_actions_v1_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."moderation_actions_v1" ADD CONSTRAINT "moderation_actions_v1_case_id_fkey" FOREIGN KEY (case_id) REFERENCES private.moderation_cases_v1(id) ON DELETE CASCADE;
ALTER TABLE "private"."moderation_cases_v1" ADD CONSTRAINT "moderation_cases_v1_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."moderation_cases_v1" ADD CONSTRAINT "moderation_cases_v1_opened_by_actor_id_fkey" FOREIGN KEY (opened_by_actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."moderation_operators" ADD CONSTRAINT "moderation_operators_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_company_id_review_id_fkey" FOREIGN KEY (company_id, review_id) REFERENCES reviews(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_current_draft_fk" FOREIGN KEY (company_id, current_draft_revision_id) REFERENCES private.statement_revisions_v2(company_id, id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_current_published_fk" FOREIGN KEY (company_id, current_published_revision_id) REFERENCES private.statement_revisions_v2(company_id, id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "private"."official_statements_v2" ADD CONSTRAINT "official_statements_v2_question_tenant_fk" FOREIGN KEY (company_id, question_id) REFERENCES private.questions_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."outbox_events_v1" ADD CONSTRAINT "outbox_events_v1_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."own_review_rate_limits" ADD CONSTRAINT "own_review_rate_limits_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT;
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_location_id_fkey" FOREIGN KEY (location_id) REFERENCES company_locations(id) ON DELETE SET NULL;
ALTER TABLE "private"."own_review_submissions" ADD CONSTRAINT "own_review_submissions_published_review_id_fkey" FOREIGN KEY (published_review_id) REFERENCES reviews(id) ON DELETE SET NULL;
ALTER TABLE "private"."persons" ADD CONSTRAINT "persons_auth_user_id_fkey" FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE "private"."projection_receipts_v1" ADD CONSTRAINT "projection_receipts_v1_consumer_key_fkey" FOREIGN KEY (consumer_key) REFERENCES private.projection_consumers_v1(consumer_key) ON DELETE CASCADE;
ALTER TABLE "private"."projection_receipts_v1" ADD CONSTRAINT "projection_receipts_v1_event_id_fkey" FOREIGN KEY (event_id) REFERENCES private.outbox_events_v1(event_id) ON DELETE CASCADE;
ALTER TABLE "private"."public_author_person_links" ADD CONSTRAINT "public_author_person_links_person_id_fkey" FOREIGN KEY (person_id) REFERENCES private.persons(id) ON DELETE CASCADE;
ALTER TABLE "private"."public_author_person_links" ADD CONSTRAINT "public_author_person_links_public_author_id_fkey" FOREIGN KEY (public_author_id) REFERENCES public_authors(id) ON DELETE CASCADE;
ALTER TABLE "private"."question_messages_v1" ADD CONSTRAINT "question_messages_v1_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."question_messages_v1" ADD CONSTRAINT "question_messages_v1_company_id_question_id_fkey" FOREIGN KEY (company_id, question_id) REFERENCES private.questions_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."question_revisions_v1" ADD CONSTRAINT "question_revisions_v1_company_id_question_id_fkey" FOREIGN KEY (company_id, question_id) REFERENCES private.questions_v1(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."questions_v1" ADD CONSTRAINT "questions_v1_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."questions_v1" ADD CONSTRAINT "questions_v1_current_revision_fk" FOREIGN KEY (company_id, current_revision_id) REFERENCES private.question_revisions_v1(company_id, id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE "private"."questions_v1" ADD CONSTRAINT "questions_v1_legacy_qna_id_fkey" FOREIGN KEY (legacy_qna_id) REFERENCES company_questions_answers(id) ON DELETE SET NULL;
ALTER TABLE "private"."questions_v1" ADD CONSTRAINT "questions_v1_public_author_id_fkey" FOREIGN KEY (public_author_id) REFERENCES public_authors(id) ON DELETE SET NULL;
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."review_revisions_v1" ADD CONSTRAINT "review_revisions_v1_company_id_review_id_fkey" FOREIGN KEY (company_id, review_id) REFERENCES reviews(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."review_source_sync_jobs" ADD CONSTRAINT "review_source_sync_jobs_result_snapshot_id_fkey" FOREIGN KEY (result_snapshot_id) REFERENCES source_ratings(id) ON DELETE SET NULL;
ALTER TABLE "private"."review_source_sync_jobs" ADD CONSTRAINT "review_source_sync_jobs_source_id_fkey" FOREIGN KEY (source_id) REFERENCES review_sources(id) ON DELETE CASCADE;
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_approved_by_actor_id_fkey" FOREIGN KEY (approved_by_actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_company_id_official_statement_id_fkey" FOREIGN KEY (company_id, official_statement_id) REFERENCES private.official_statements_v2(company_id, id) ON DELETE CASCADE;
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_company_id_responds_to_review_revis_fkey" FOREIGN KEY (company_id, responds_to_review_revision_id) REFERENCES private.review_revisions_v1(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "private"."statement_revisions_v2" ADD CONSTRAINT "statement_revisions_v2_on_behalf_of_actor_id_fkey" FOREIGN KEY (on_behalf_of_actor_id) REFERENCES private.actors(id) ON DELETE SET NULL;
ALTER TABLE "private"."verification_evidence" ADD CONSTRAINT "verification_evidence_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "private"."verification_evidence" ADD CONSTRAINT "verification_evidence_public_author_id_fkey" FOREIGN KEY (public_author_id) REFERENCES public_authors(id) ON DELETE SET NULL;
ALTER TABLE "public"."company_profile_public_access" ADD CONSTRAINT "company_profile_public_access_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "public"."company_profile_publications" ADD CONSTRAINT "company_profile_publications_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "public"."company_questions_answers" ADD CONSTRAINT "company_questions_answers_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "public"."company_statements" ADD CONSTRAINT "company_statements_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "public"."company_statements" ADD CONSTRAINT "company_statements_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;
ALTER TABLE "public"."review_service_links" ADD CONSTRAINT "review_service_links_review_id_fkey" FOREIGN KEY (review_id) REFERENCES reviews(id) ON DELETE CASCADE;
ALTER TABLE "public"."review_service_links" ADD CONSTRAINT "review_service_links_service_id_fkey" FOREIGN KEY (service_id) REFERENCES company_services(id) ON DELETE CASCADE;
ALTER TABLE "public"."review_sources" ADD CONSTRAINT "review_sources_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "public"."review_sources" ADD CONSTRAINT "review_sources_location_id_fkey" FOREIGN KEY (location_id) REFERENCES company_locations(id) ON DELETE SET NULL;
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_company_location_tenant_fk" FOREIGN KEY (company_id, location_id) REFERENCES company_locations(company_id, id) ON DELETE RESTRICT;
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_location_id_fkey" FOREIGN KEY (location_id) REFERENCES company_locations(id) ON DELETE SET NULL;
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_source_id_fkey" FOREIGN KEY (source_id) REFERENCES review_sources(id) ON DELETE RESTRICT;
ALTER TABLE "public"."source_ratings" ADD CONSTRAINT "source_ratings_source_id_fkey" FOREIGN KEY (source_id) REFERENCES review_sources(id) ON DELETE CASCADE;
ALTER TABLE "private"."actors" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."actors" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."actors" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."compatibility_flags_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."compatibility_flags_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."compatibility_flags_v1" FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON "private"."compatibility_flags_v1" TO "service_role";
ALTER TABLE "private"."embedding_projection_refs_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."embedding_projection_refs_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."embedding_projection_refs_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."erasure_projection_receipts_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."erasure_projection_receipts_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."erasure_projection_receipts_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."erasure_requests" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."erasure_requests" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."erasure_requests" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."external_sources_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."external_sources_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."external_sources_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."external_sync_runs_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."external_sync_runs_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."external_sync_runs_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."knowledge_change_proposals_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."knowledge_change_proposals_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."knowledge_change_proposals_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."knowledge_concepts_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."knowledge_concepts_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."knowledge_concepts_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."knowledge_publications_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."knowledge_publications_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."knowledge_publications_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."knowledge_source_links_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."knowledge_source_links_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."knowledge_source_links_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."knowledge_variants_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."knowledge_variants_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."knowledge_variants_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."knowledge_versions_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."knowledge_versions_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."knowledge_versions_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."legal_holds" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."legal_holds" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."legal_holds" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."moderation_actions_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."moderation_actions_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."moderation_actions_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."moderation_cases_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."moderation_cases_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."moderation_cases_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."moderation_operators" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."moderation_operators" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."moderation_operators" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."official_statements_v2" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."official_statements_v2" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."official_statements_v2" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."outbox_events_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."outbox_events_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."outbox_events_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."own_review_rate_limits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."own_review_rate_limits" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."own_review_rate_limits" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "private"."own_review_rate_limits" TO "service_role";
GRANT SELECT ON "private"."own_review_rate_limits" TO "service_role";
GRANT DELETE ON "private"."own_review_rate_limits" TO "service_role";
ALTER TABLE "private"."own_review_submissions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."own_review_submissions" FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."own_review_submissions" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."persons" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."persons" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."persons" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."projection_consumers_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."projection_consumers_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."projection_consumers_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."projection_receipts_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."projection_receipts_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."projection_receipts_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."public_author_person_links" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."public_author_person_links" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."public_author_person_links" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."question_messages_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."question_messages_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."question_messages_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."question_revisions_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."question_revisions_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."question_revisions_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."questions_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."questions_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."questions_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."review_revisions_v1" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."review_revisions_v1" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."review_revisions_v1" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."review_source_sync_jobs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."review_source_sync_jobs" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."review_source_sync_jobs" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "private"."review_source_sync_jobs" TO "service_role";
GRANT SELECT ON "private"."review_source_sync_jobs" TO "service_role";
GRANT UPDATE ON "private"."review_source_sync_jobs" TO "service_role";
ALTER TABLE "private"."statement_revisions_v2" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."statement_revisions_v2" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."statement_revisions_v2" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "private"."verification_evidence" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "private"."verification_evidence" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "private"."verification_evidence" FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE "public"."company_profile_public_access" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."company_profile_public_access" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."company_profile_public_access" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."company_profile_public_access" TO "service_role";
GRANT SELECT ON "public"."company_profile_public_access" TO "service_role";
GRANT UPDATE ON "public"."company_profile_public_access" TO "service_role";
GRANT DELETE ON "public"."company_profile_public_access" TO "service_role";
ALTER TABLE "public"."company_profile_publications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."company_profile_publications" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."company_profile_publications" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."company_profile_publications" TO "service_role";
GRANT SELECT ON "public"."company_profile_publications" TO "service_role";
GRANT UPDATE ON "public"."company_profile_publications" TO "service_role";
GRANT DELETE ON "public"."company_profile_publications" TO "service_role";
GRANT TRUNCATE ON "public"."company_profile_publications" TO "service_role";
GRANT REFERENCES ON "public"."company_profile_publications" TO "service_role";
GRANT TRIGGER ON "public"."company_profile_publications" TO "service_role";
GRANT MAINTAIN ON "public"."company_profile_publications" TO "service_role";
GRANT SELECT ON "public"."company_profile_publications" TO "authenticated";
ALTER TABLE "public"."company_questions_answers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."company_questions_answers" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."company_questions_answers" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."company_questions_answers" TO "service_role";
GRANT SELECT ON "public"."company_questions_answers" TO "service_role";
GRANT UPDATE ON "public"."company_questions_answers" TO "service_role";
GRANT DELETE ON "public"."company_questions_answers" TO "service_role";
GRANT TRUNCATE ON "public"."company_questions_answers" TO "service_role";
GRANT REFERENCES ON "public"."company_questions_answers" TO "service_role";
GRANT TRIGGER ON "public"."company_questions_answers" TO "service_role";
GRANT MAINTAIN ON "public"."company_questions_answers" TO "service_role";
ALTER TABLE "public"."company_statements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."company_statements" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."company_statements" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."company_statements" TO "authenticated";
GRANT SELECT ON "public"."company_statements" TO "authenticated";
GRANT UPDATE ON "public"."company_statements" TO "authenticated";
GRANT MAINTAIN ON "public"."company_statements" TO "authenticated";
GRANT INSERT ON "public"."company_statements" TO "service_role";
GRANT SELECT ON "public"."company_statements" TO "service_role";
GRANT UPDATE ON "public"."company_statements" TO "service_role";
GRANT DELETE ON "public"."company_statements" TO "service_role";
GRANT TRUNCATE ON "public"."company_statements" TO "service_role";
GRANT REFERENCES ON "public"."company_statements" TO "service_role";
GRANT TRIGGER ON "public"."company_statements" TO "service_role";
GRANT MAINTAIN ON "public"."company_statements" TO "service_role";
ALTER TABLE "public"."review_service_links" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."review_service_links" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."review_service_links" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."review_service_links" TO "service_role";
GRANT SELECT ON "public"."review_service_links" TO "service_role";
GRANT UPDATE ON "public"."review_service_links" TO "service_role";
GRANT DELETE ON "public"."review_service_links" TO "service_role";
GRANT TRUNCATE ON "public"."review_service_links" TO "service_role";
GRANT REFERENCES ON "public"."review_service_links" TO "service_role";
GRANT TRIGGER ON "public"."review_service_links" TO "service_role";
GRANT MAINTAIN ON "public"."review_service_links" TO "service_role";
ALTER TABLE "public"."review_sources" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."review_sources" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."review_sources" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."review_sources" TO "service_role";
GRANT SELECT ON "public"."review_sources" TO "service_role";
GRANT UPDATE ON "public"."review_sources" TO "service_role";
GRANT DELETE ON "public"."review_sources" TO "service_role";
GRANT TRUNCATE ON "public"."review_sources" TO "service_role";
GRANT REFERENCES ON "public"."review_sources" TO "service_role";
GRANT TRIGGER ON "public"."review_sources" TO "service_role";
GRANT MAINTAIN ON "public"."review_sources" TO "service_role";
GRANT SELECT ON "public"."review_sources" TO "authenticated";
ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."reviews" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."reviews" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."reviews" TO "service_role";
GRANT SELECT ON "public"."reviews" TO "service_role";
GRANT UPDATE ON "public"."reviews" TO "service_role";
GRANT DELETE ON "public"."reviews" TO "service_role";
GRANT TRUNCATE ON "public"."reviews" TO "service_role";
GRANT REFERENCES ON "public"."reviews" TO "service_role";
GRANT TRIGGER ON "public"."reviews" TO "service_role";
GRANT MAINTAIN ON "public"."reviews" TO "service_role";
ALTER TABLE "public"."source_ratings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."source_ratings" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."source_ratings" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."source_ratings" TO "service_role";
GRANT SELECT ON "public"."source_ratings" TO "service_role";
GRANT UPDATE ON "public"."source_ratings" TO "service_role";
GRANT DELETE ON "public"."source_ratings" TO "service_role";
GRANT TRUNCATE ON "public"."source_ratings" TO "service_role";
GRANT REFERENCES ON "public"."source_ratings" TO "service_role";
GRANT TRIGGER ON "public"."source_ratings" TO "service_role";
GRANT MAINTAIN ON "public"."source_ratings" TO "service_role";
GRANT SELECT ON "public"."source_ratings" TO "authenticated";
ALTER TABLE "public"."public_authors" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."public_authors" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON "public"."public_authors" FROM PUBLIC,anon,authenticated,service_role;
GRANT INSERT ON "public"."public_authors" TO "service_role";
GRANT SELECT ON "public"."public_authors" TO "service_role";
GRANT UPDATE ON "public"."public_authors" TO "service_role";
GRANT DELETE ON "public"."public_authors" TO "service_role";
GRANT TRUNCATE ON "public"."public_authors" TO "service_role";
GRANT REFERENCES ON "public"."public_authors" TO "service_role";
GRANT TRIGGER ON "public"."public_authors" TO "service_role";
GRANT MAINTAIN ON "public"."public_authors" TO "service_role";
SET LOCAL check_function_bodies=off;
CREATE FUNCTION private.outbox_payload_refs_guard_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
begin
  perform private.assert_outbox_payload_refs_safe_v1(new.payload_refs);
  return new;
end $function$;
REVOKE ALL ON FUNCTION "private"."outbox_payload_refs_guard_v1"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."outbox_payload_refs_guard_v1"() TO PUBLIC;
CREATE FUNCTION private.seed_erasure_projection_receipts_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'private'
AS $function$
begin
  insert into private.erasure_projection_receipts_v1(erasure_request_id,consumer_key)
  select new.id,c.consumer_key
  from private.projection_consumers_v1 c
  where c.active and c.erasure_required
  on conflict do nothing;
  return new;
end $function$;
REVOKE ALL ON FUNCTION "private"."seed_erasure_projection_receipts_v1"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."seed_erasure_projection_receipts_v1"() TO PUBLIC;
CREATE FUNCTION private.sync_legacy_qna_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_q uuid; v_qr uuid; v_os uuid; v_sr uuid; v_qver integer; v_sver integer;
begin
 if current_setting('otzovik.native_mirror',true)='on' then return new; end if;
 if new.status not in ('draft','published','archived') then return new; end if;
 select id into v_q from private.questions_v1 where company_id=new.company_id and legacy_qna_id=new.id limit 1;
 if v_q is null then insert into private.questions_v1(company_id,status,created_at,updated_at,answered_at,legacy_qna_id,category,program_label) values(new.company_id,case when new.status='published' then 'answered' when new.status='archived' then 'archived' else 'pending' end,new.created_at,new.updated_at,new.answered_at,new.id,new.category,new.program_label) returning id into v_q; end if;
 if new.status='archived' then update private.questions_v1 set status='archived',updated_at=new.updated_at where id=v_q and company_id=new.company_id; return new; end if;
 select id into v_qr from private.question_revisions_v1 where company_id=new.company_id and question_id=v_q and body_public=new.question order by version desc limit 1;
 if v_qr is null then select coalesce(max(version),0)+1 into v_qver from private.question_revisions_v1 where company_id=new.company_id and question_id=v_q; insert into private.question_revisions_v1(company_id,question_id,version,body_original,body_public,language,content_hash,provenance,created_at) values(new.company_id,v_q,v_qver,new.question,new.question,'ru',encode(extensions.digest(new.question,'sha256'),'hex'),jsonb_build_object('legacy_qna_id',new.id::text,'source','legacy_qna_sync'),new.updated_at) returning id into v_qr; end if;
 update private.questions_v1 set current_revision_id=v_qr,status=case when new.status='published' then 'answered' else 'pending' end,answered_at=new.answered_at,category=coalesce(category,new.category),program_label=coalesce(program_label,new.program_label),updated_at=new.updated_at where id=v_q;
 select id into v_os from private.official_statements_v2 where company_id=new.company_id and question_id=v_q; if v_os is null then insert into private.official_statements_v2(company_id,question_id) values(new.company_id,v_q) returning id into v_os; end if;
 select id into v_sr from private.statement_revisions_v2 where company_id=new.company_id and official_statement_id=v_os and body=new.answer and status=case when new.status='published' then 'published' else 'draft' end order by version desc limit 1;
 if v_sr is null then select coalesce(max(version),0)+1 into v_sver from private.statement_revisions_v2 where company_id=new.company_id and official_statement_id=v_os; if new.status='published' then update private.statement_revisions_v2 set status='superseded' where company_id=new.company_id and official_statement_id=v_os and status='published'; end if; insert into private.statement_revisions_v2(company_id,official_statement_id,version,body,status,provenance,created_at,published_at) values(new.company_id,v_os,v_sver,new.answer,case when new.status='published' then 'published' else 'draft' end,jsonb_build_object('legacy_qna_id',new.id::text,'source','legacy_qna_sync'),new.updated_at,case when new.status='published' then coalesce(new.published_at,new.updated_at) else null end) returning id into v_sr; end if;
 update private.official_statements_v2 set current_draft_revision_id=case when new.status='draft' then v_sr else current_draft_revision_id end,current_published_revision_id=case when new.status='published' then v_sr else current_published_revision_id end,updated_at=new.updated_at where id=v_os;
 return new;
end $function$;
REVOKE ALL ON FUNCTION "private"."sync_legacy_qna_v1"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."sync_legacy_qna_v1"() TO "service_role";
CREATE FUNCTION private.sync_statement_v2_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare v_review uuid;v_os uuid;v_rr uuid;v_sr uuid;v_version integer;v_review_row public.reviews%rowtype;
begin
 if new.status <> 'published' then return new; end if;
 v_review:=new.review_id::uuid;
 select * into v_review_row from public.reviews where company_id=new.company_id and id=v_review;
 if not found then return new; end if;
 select id into v_rr from private.review_revisions_v1 where company_id=new.company_id and review_id=v_review order by version desc limit 1;
 if v_rr is null then
   insert into private.review_revisions_v1(company_id,review_id,version,body_original,body_public,language,content_hash,provenance)
   values(new.company_id,v_review,1,v_review_row.body,v_review_row.body,v_review_row.language,
          encode(extensions.digest(v_review_row.body,'sha256'),'hex'),
          jsonb_build_object('source','legacy_review_compat','review_id',v_review::text))
   returning id into v_rr;
 end if;
 select id into v_os from private.official_statements_v2 where company_id=new.company_id and review_id=v_review;
 if v_os is null then insert into private.official_statements_v2(company_id,review_id) values(new.company_id,v_review) returning id into v_os; end if;
 select id into v_sr from private.statement_revisions_v2 where company_id=new.company_id and official_statement_id=v_os and provenance->>'legacy_id'=new.id::text limit 1;
 if v_sr is null then
   select coalesce(max(version),0)+1 into v_version from private.statement_revisions_v2 where company_id=new.company_id and official_statement_id=v_os;
   update private.statement_revisions_v2 set status='superseded' where company_id=new.company_id and official_statement_id=v_os and status='published';
   insert into private.statement_revisions_v2(company_id,official_statement_id,version,body,status,responds_to_review_revision_id,provenance,published_at)
   values(new.company_id,v_os,v_version,new.statement,'published',v_rr,jsonb_build_object('legacy_id',new.id::text,'source','legacy_company_statement'),new.updated_at) returning id into v_sr;
 else
   update private.statement_revisions_v2 set body=new.statement,published_at=new.updated_at,responds_to_review_revision_id=v_rr where id=v_sr;
 end if;
 update private.official_statements_v2 set current_published_revision_id=v_sr,updated_at=now() where id=v_os;
 return new;
end $function$;
REVOKE ALL ON FUNCTION "private"."sync_statement_v2_v1"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."sync_statement_v2_v1"() TO "service_role";
CREATE FUNCTION public.add_my_company_review_source(p_company_id uuid, p_name text, p_profile_url text, p_location_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_name text := nullif(btrim(p_name),'');
  v_url text := nullif(btrim(p_profile_url),'');
  v_source_type text;
  v_external_key text;
  v_row public.review_sources%rowtype;
begin
  if v_uid is null then raise exception 'unauthorized' using errcode='42501'; end if;
  if not exists (
    select 1 from public.company_memberships cm
    where cm.company_id=p_company_id and cm.user_id=v_uid
      and cm.verification_status='verified' and cm.role in ('owner','admin')
  ) then raise exception 'forbidden' using errcode='42501'; end if;
  if v_name is null or length(v_name)>80 then raise exception 'invalid_source_name' using errcode='22023'; end if;
  if v_url is null or length(v_url)>2048 or v_url !~* '^https://[^[:space:]]+$' then raise exception 'invalid_profile_url' using errcode='22023'; end if;
  if p_location_id is not null and not exists (
    select 1 from public.company_locations cl where cl.id=p_location_id and cl.company_id=p_company_id
  ) then raise exception 'invalid_location' using errcode='22023'; end if;

  v_source_type := case
    when v_url ~* '^https://([^/]+\.)?2gis\.' then '2gis'
    when v_url ~* '^https://([^/]+\.)?(yandex\.|ya\.ru)' then 'yandex'
    when v_url ~* '^https://([^/]+\.)?(google\.|goo\.gl|maps\.app\.goo\.gl)' then 'google'
    else 'other'
  end;

  v_external_key := case
    when v_source_type='2gis' then (regexp_match(v_url, '/firm/([0-9]+)', 'i'))[1]
    when v_source_type='yandex' then (regexp_match(v_url, '/org/(?:[^/?#]+/)?([0-9]+)(?:[/?#]|$)', 'i'))[1]
    else null
  end;

  select * into v_row from public.review_sources
   where company_id=p_company_id and profile_url=v_url limit 1 for update;

  if found and v_row.status <> 'archived' then
    return jsonb_build_object('id',v_row.id,'company_id',v_row.company_id,'location_id',v_row.location_id,'name',v_row.name,'source_type',v_row.source_type,'profile_url',v_row.profile_url,'status',v_row.status,'checked_at',v_row.checked_at,'updated_at',v_row.updated_at,'duplicate',true,'duplicate_kind','exact_url','reactivated',false);
  elsif found then
    update public.review_sources
       set location_id=p_location_id,name=v_name,source_type=v_source_type,
           collection_method='owner_submitted',terms_notes=null,status='draft',
           checked_at=null,updated_at=now()
     where id=v_row.id returning * into v_row;
    return jsonb_build_object('id',v_row.id,'company_id',v_row.company_id,'location_id',v_row.location_id,'name',v_row.name,'source_type',v_row.source_type,'profile_url',v_row.profile_url,'status',v_row.status,'checked_at',v_row.checked_at,'updated_at',v_row.updated_at,'duplicate',false,'duplicate_kind',null,'reactivated',true);
  end if;

  if v_external_key is not null then
    select rs.* into v_row from public.review_sources rs
    where rs.company_id=p_company_id and rs.status <> 'archived'
      and rs.location_id is not distinct from p_location_id
      and (case when rs.profile_url ~* '^https://([^/]+\.)?2gis\.' then '2gis' when rs.profile_url ~* '^https://([^/]+\.)?(yandex\.|ya\.ru)' then 'yandex' else rs.source_type end)=v_source_type
      and (case when v_source_type='2gis' then (regexp_match(rs.profile_url, '/firm/([0-9]+)', 'i'))[1] when v_source_type='yandex' then (regexp_match(rs.profile_url, '/org/(?:[^/?#]+/)?([0-9]+)(?:[/?#]|$)', 'i'))[1] else null end)=v_external_key
    order by rs.created_at limit 1 for update;
    if found then
      return jsonb_build_object('id',v_row.id,'company_id',v_row.company_id,'location_id',v_row.location_id,'name',v_row.name,'source_type',v_row.source_type,'profile_url',v_row.profile_url,'status',v_row.status,'checked_at',v_row.checked_at,'updated_at',v_row.updated_at,'duplicate',true,'duplicate_kind','listing_id','reactivated',false,'external_key',v_external_key);
    end if;
  end if;

  insert into public.review_sources(company_id,location_id,name,source_type,profile_url,collection_method,terms_notes,status,checked_at,updated_at)
  values(p_company_id,p_location_id,v_name,v_source_type,v_url,'owner_submitted',null,'draft',null,now())
  returning * into v_row;

  return jsonb_build_object('id',v_row.id,'company_id',v_row.company_id,'location_id',v_row.location_id,'name',v_row.name,'source_type',v_row.source_type,'profile_url',v_row.profile_url,'status',v_row.status,'checked_at',v_row.checked_at,'updated_at',v_row.updated_at,'duplicate',false,'duplicate_kind',null,'reactivated',false,'external_key',v_external_key);
end;
$function$;
REVOKE ALL ON FUNCTION "public"."add_my_company_review_source"(uuid, text, text, uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."add_my_company_review_source"(uuid, text, text, uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."add_my_company_review_source"(uuid, text, text, uuid) TO "service_role";
CREATE FUNCTION public.archive_my_company_review_source(p_company_id uuid, p_source_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid := (select auth.uid()); v_row public.review_sources%rowtype; v_cancelled int:=0;
begin
 if v_uid is null then raise exception 'unauthorized' using errcode='42501'; end if;
 if not exists(select 1 from public.company_memberships cm where cm.company_id=p_company_id and cm.user_id=v_uid and cm.verification_status='verified' and cm.role in ('owner','admin')) then raise exception 'forbidden' using errcode='42501'; end if;
 select * into v_row from public.review_sources where id=p_source_id and company_id=p_company_id for update;
 if not found then raise exception 'source_not_found' using errcode='P0002'; end if;
 update public.review_sources set status='archived',updated_at=now() where id=v_row.id;
 update private.review_source_sync_jobs set status='failed',finished_at=now(),updated_at=now(),error_code='source_archived',error_message='Source archived by owner before sync completion'
 where source_id=v_row.id and status in ('pending','running');
 get diagnostics v_cancelled = row_count;
 return jsonb_build_object('id',v_row.id,'company_id',v_row.company_id,'status','archived','cancelled_sync_jobs',v_cancelled);
end;$function$;
REVOKE ALL ON FUNCTION "public"."archive_my_company_review_source"(uuid, uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."archive_my_company_review_source"(uuid, uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."archive_my_company_review_source"(uuid, uuid) TO "service_role";
CREATE FUNCTION public.check_own_review_rate_limit_internal(p_company_slug text, p_source_ip_hash text, p_limit integer DEFAULT 5, p_window_seconds integer DEFAULT 3600)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_company_id uuid;
  v_count integer;
begin
  if p_limit < 1 or p_limit > 100 or p_window_seconds < 60 or p_window_seconds > 86400 then
    raise exception 'invalid rate limit policy';
  end if;
  if p_source_ip_hash is null or p_source_ip_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid source hash';
  end if;
  select c.id into v_company_id
  from public.companies c
  join public.company_profile_public_access a on a.company_id=c.id
  where c.slug=p_company_slug
    and c.status='active'
    and c.profile_status='ready'
    and a.state='active'
    and a.review_intake_enabled is true;
  if v_company_id is null then return false; end if;

  delete from private.own_review_rate_limits
   where created_at < now() - interval '2 days';

  perform pg_advisory_xact_lock(hashtextextended(v_company_id::text || ':' || p_source_ip_hash, 0));
  select count(*) into v_count
    from private.own_review_rate_limits
   where company_id=v_company_id
     and source_ip_hash=p_source_ip_hash
     and created_at >= now() - make_interval(secs => p_window_seconds);
  if v_count >= p_limit then return false; end if;
  insert into private.own_review_rate_limits(company_id,source_ip_hash)
  values(v_company_id,p_source_ip_hash);
  return true;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."check_own_review_rate_limit_internal"(text, text, integer, integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."check_own_review_rate_limit_internal"(text, text, integer, integer) TO "service_role";
CREATE FUNCTION public.claim_next_review_source_sync()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_job private.review_source_sync_jobs%rowtype;
  v_source public.review_sources%rowtype;
begin
  select j.* into v_job
  from private.review_source_sync_jobs j
  join public.review_sources rs on rs.id = j.source_id and rs.status <> 'archived'
  where j.status = 'pending'
  order by j.requested_at
  for update of j skip locked
  limit 1;

  if not found then return null; end if;

  update private.review_source_sync_jobs
     set status='running', started_at=now(), attempt_count=attempt_count+1, updated_at=now(), error_code=null, error_message=null
   where id=v_job.id
   returning * into v_job;

  select * into v_source from public.review_sources where id=v_job.source_id;

  return jsonb_build_object(
    'job_id',v_job.id,
    'source_id',v_source.id,
    'company_id',v_source.company_id,
    'location_id',v_source.location_id,
    'name',v_source.name,
    'source_type',v_source.source_type,
    'profile_url',v_source.profile_url,
    'attempt_count',v_job.attempt_count,
    'requested_at',v_job.requested_at
  );
end;
$function$;
REVOKE ALL ON FUNCTION "public"."claim_next_review_source_sync"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."claim_next_review_source_sync"() TO "service_role";
CREATE FUNCTION public.enqueue_review_source_sync(p_source_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_source public.review_sources%rowtype; v_job private.review_source_sync_jobs%rowtype;
begin
 select * into v_source from public.review_sources where id=p_source_id;
 if not found then raise exception 'source_not_found' using errcode='22023'; end if;
 if v_source.status='archived' then raise exception 'source_archived' using errcode='22023'; end if;
 begin
   insert into private.review_source_sync_jobs(source_id) values(p_source_id) returning * into v_job;
 exception when unique_violation then
   select * into v_job from private.review_source_sync_jobs
   where source_id=p_source_id and status in ('pending','running')
   order by requested_at desc limit 1;
   if not found then raise; end if;
   return jsonb_build_object('id',v_job.id,'source_id',v_job.source_id,'status',v_job.status,'duplicate',true,'requested_at',v_job.requested_at);
 end;
 return jsonb_build_object('id',v_job.id,'source_id',v_job.source_id,'status',v_job.status,'duplicate',false,'requested_at',v_job.requested_at);
end;$function$;
REVOKE ALL ON FUNCTION "public"."enqueue_review_source_sync"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."enqueue_review_source_sync"(uuid) TO "service_role";
CREATE FUNCTION public.finish_review_source_sync(p_job_id uuid, p_success boolean, p_result_snapshot_id uuid DEFAULT NULL::uuid, p_error_code text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_job private.review_source_sync_jobs%rowtype;
begin
 select * into v_job from private.review_source_sync_jobs where id=p_job_id for update;
 if not found then raise exception 'job_not_found' using errcode='22023'; end if;
 if v_job.status<>'running' then raise exception 'job_not_running' using errcode='22023'; end if;
 if p_success then
   if p_result_snapshot_id is null or not exists(select 1 from public.source_ratings sr where sr.id=p_result_snapshot_id and sr.source_id=v_job.source_id and sr.status='published' and sr.checked_at>=coalesce(v_job.started_at,v_job.requested_at)-interval '5 minutes') then
     raise exception 'invalid_result_snapshot' using errcode='22023';
   end if;
   update private.review_source_sync_jobs set status='succeeded',result_snapshot_id=p_result_snapshot_id,finished_at=now(),updated_at=now(),error_code=null,error_message=null where id=v_job.id returning * into v_job;
 else
   if p_result_snapshot_id is not null then raise exception 'failed_job_cannot_have_snapshot' using errcode='22023'; end if;
   update private.review_source_sync_jobs set status='failed',result_snapshot_id=null,finished_at=now(),updated_at=now(),error_code=left(nullif(btrim(p_error_code),''),120),error_message=left(nullif(btrim(p_error_message),''),1000) where id=v_job.id returning * into v_job;
 end if;
 return jsonb_build_object('id',v_job.id,'source_id',v_job.source_id,'status',v_job.status,'attempt_count',v_job.attempt_count,'result_snapshot_id',v_job.result_snapshot_id,'error_code',v_job.error_code,'finished_at',v_job.finished_at);
end;$function$;
REVOKE ALL ON FUNCTION "public"."finish_review_source_sync"(uuid, boolean, uuid, text, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."finish_review_source_sync"(uuid, boolean, uuid, text, text) TO "service_role";
CREATE FUNCTION public.get_company_profile_for_worker(p_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.companies%rowtype; st text; intake boolean;
begin
 if p_slug is null or length(trim(p_slug)) not between 1 and 80 or trim(p_slug)!~'^[A-Za-z0-9-]+$' then return null; end if;
 select * into v from public.companies c where c.status='active' and lower(c.slug)=lower(trim(p_slug)) limit 1; if not found then return null; end if;
 select state,review_intake_enabled into st,intake from public.company_profile_public_access where company_id=v.id; if not found then return null; end if;
 return jsonb_build_object(
 'id',v.id,'slug',v.slug,'name',v.name,'description',v.description,'legal_name',v.legal_name,'website',v.website,'phone',v.phone,'city',v.city,'profile_status',v.profile_status,'updated_at',v.updated_at,
 'public_access',jsonb_build_object('state',st,'indexable',st='active','machine_exports',st='active','review_intake',st='active' and intake),
 'locations',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'relationship_type',l.relationship_type,'address',l.canonical_address,'city',l.city,'phone',l.phone,'hours',l.hours,'official_url',l.official_url,'source_url',l.source_url,'verified_at',l.verified_at)) from public.company_locations l where l.company_id=v.id and l.status='published'),'[]'::jsonb),
 'services',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'category',s.category,'description',s.description,'official_url',s.official_url,'source_url',s.source_url,'verified_at',s.verified_at)) from public.company_services s where s.company_id=v.id and s.status='published'),'[]'::jsonb),
 'media',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'type',m.media_type,'object_name',m.storage_object_name,'sort_order',m.sort_order,'alt',m.alt_text,'caption',m.caption,'updated_at',m.updated_at)) from public.company_media m where m.company_id=v.id and m.status='published'),'[]'::jsonb),
 'sources',coalesce((select jsonb_agg(jsonb_build_object('id',rs.id,'name',rs.name,'source_type',rs.source_type,'profile_url',rs.profile_url,'collection_method',rs.collection_method,'checked_at',rs.checked_at,'latest_rating',(select jsonb_build_object('rating',sr.rating,'rating_scale',sr.rating_scale,'rating_count',sr.rating_count,'review_count',sr.review_count,'checked_at',sr.checked_at) from public.source_ratings sr where sr.source_id=rs.id and sr.status='published' order by sr.checked_at desc limit 1))) from public.review_sources rs where rs.company_id=v.id and rs.status='published'),'[]'::jsonb),
 'native_rating',(select case when count(*)=0 then null else jsonb_build_object('source','otzyv_com','rating',round(avg(r.rating)::numeric,2),'scale',5,'published_review_count',count(*)) end from public.reviews r join public.review_sources rs on rs.id=r.source_id and rs.company_id=r.company_id and rs.status='published' and rs.source_type='first_party_reviews' where r.company_id=v.id and r.status='published' and r.rating between 1 and 5 and r.rating_scale=5),
 'own_reviews',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'source','otzyv_com','author_display_name',r.author_display_name,'rating',r.rating,'rating_scale',r.rating_scale,'text',coalesce(r.body,r.excerpt),'published_at',r.published_at,'location',case when l.id is null then null else jsonb_build_object('id',l.id,'name',l.name) end,'service',null,'company_response',(select jsonb_build_object('text',sr.body,'published_at',sr.published_at) from private.official_statements_v2 os join private.statement_revisions_v2 sr on sr.id=os.current_published_revision_id and sr.company_id=os.company_id where os.company_id=r.company_id and os.review_id=r.id and sr.status='published' limit 1)) order by r.published_at desc) from public.reviews r join public.review_sources rs on rs.id=r.source_id and rs.company_id=r.company_id and rs.status='published' and rs.source_type='first_party_reviews' left join public.company_locations l on l.id=r.location_id and l.company_id=r.company_id and l.status='published' where r.company_id=v.id and r.status='published'),'[]'::jsonb));
end; $function$;
REVOKE ALL ON FUNCTION "public"."get_company_profile_for_worker"(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_company_profile_for_worker"(text) TO "service_role";
CREATE FUNCTION public.get_my_company_client_content(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select role into v_role from public.company_memberships
 where company_id=p_company_id and user_id=v_uid and verification_status='verified'
 and role in ('owner','admin','manager','analyst') limit 1;
 if v_role is null then raise exception 'company_access_required' using errcode='42501'; end if;
 return jsonb_build_object(
  'role',v_role,
  'reviews',coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',r.id,'author',r.author_display_name,'rating',r.rating,'body',r.body,'published_at',r.published_at,
      'company_response',(
        select sr.body
        from private.official_statements_v2 os
        join private.statement_revisions_v2 sr
          on sr.company_id=os.company_id and sr.id=os.current_published_revision_id
        where os.company_id=p_company_id and os.review_id=r.id and sr.status='published'
        limit 1
      )
    ) order by r.published_at desc)
    from public.reviews r where r.company_id=p_company_id and r.status='published'
  ),'[]'::jsonb),
  'questions_answers',coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',coalesce(q.legacy_qna_id,q.id),'question_id',q.id,'question',qr.body_public,'answer',sr.body,
      'status',case when sr.status='published' and q.status='answered' then 'published' else 'draft' end,
      'category',q.category,'program',q.program_label,'updated_at',q.updated_at
    ) order by q.updated_at desc)
    from private.questions_v1 q
    join private.question_revisions_v1 qr on qr.company_id=q.company_id and qr.id=q.current_revision_id
    join private.official_statements_v2 os on os.company_id=q.company_id and os.question_id=q.id
    join private.statement_revisions_v2 sr on sr.company_id=os.company_id and sr.id=coalesce(os.current_published_revision_id,os.current_draft_revision_id)
    where q.company_id=p_company_id and q.status not in ('hidden','rejected','merged','archived') and qr.erased_at is null
  ),'[]'::jsonb),
  'knowledge',public.get_my_company_knowledge(p_company_id)
 );
end $function$;
REVOKE ALL ON FUNCTION "public"."get_my_company_client_content"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_my_company_client_content"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_my_company_client_content"(uuid) TO "service_role";
CREATE FUNCTION public.get_my_company_knowledge(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select role into v_role from public.company_memberships
 where company_id=p_company_id and user_id=v_uid and verification_status='verified' limit 1;
 if v_role is null then raise exception 'company_read_access_required' using errcode='42501'; end if;
 return coalesce((
   select jsonb_agg(jsonb_build_object(
    'concept_id',kc.id,'concept_type',kc.concept_type,'scope_type',kc.scope_type,
    'branch_id',kc.branch_id,'service_id',kc.service_id,'authority',kc.authority,'status',kc.status,
    'version_id',kvn.id,'version',kvn.version,'version_status',kvn.status,
    'variant_id',kv.id,'language',kv.language,'title',kv.title,'body',kv.body,'origin',kv.origin,
    'verification_status',kv.verification_status,'verified_at',kv.verified_at,'review_due_at',kv.review_due_at,
    'public_published',exists(select 1 from private.knowledge_publications_v1 kp where kp.company_id=kc.company_id and kp.concept_id=kc.id and kp.variant_id=kv.id and kp.audience='public' and kp.status='published'),
    'updated_at',kv.updated_at
   ) order by kc.updated_at desc,kv.updated_at desc)
   from private.knowledge_concepts_v1 kc
   join private.knowledge_versions_v1 kvn on kvn.company_id=kc.company_id and kvn.concept_id=kc.id
   join private.knowledge_variants_v1 kv on kv.company_id=kvn.company_id and kv.version_id=kvn.id
   where kc.company_id=p_company_id and kc.status<>'retired'
 ),'[]'::jsonb);
end $function$;
REVOKE ALL ON FUNCTION "public"."get_my_company_knowledge"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_my_company_knowledge"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_my_company_knowledge"(uuid) TO "service_role";
CREATE FUNCTION public.get_my_company_publication_status(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(
    (select jsonb_build_object(
      'company_id',p.company_id,'slug',p.slug,'status',p.status,
      'requested_at',p.requested_at,'started_at',p.started_at,'completed_at',p.completed_at,
      'artifact_revision',p.artifact_revision,'workflow_run_id',p.workflow_run_id,
      'error_code',p.error_code,'updated_at',p.updated_at
    ) from public.company_profile_publications p
      join public.company_memberships m on m.company_id=p.company_id
     where p.company_id=p_company_id and m.user_id=auth.uid() and m.verification_status='verified'
     limit 1),
    jsonb_build_object('company_id',p_company_id,'status','unknown')
  )
$function$;
REVOKE ALL ON FUNCTION "public"."get_my_company_publication_status"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_my_company_publication_status"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_my_company_publication_status"(uuid) TO "service_role";
CREATE FUNCTION public.get_my_company_review_sources(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_result jsonb;
begin
  if v_uid is null then raise exception 'unauthorized' using errcode='42501'; end if;
  if not exists (
    select 1 from public.company_memberships cm
    where cm.company_id=p_company_id and cm.user_id=v_uid
      and cm.verification_status='verified' and cm.role in ('owner','admin')
  ) then raise exception 'forbidden' using errcode='42501'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',rs.id,'company_id',rs.company_id,'location_id',rs.location_id,
    'name',rs.name,'source_type',rs.source_type,'profile_url',rs.profile_url,
    'collection_method',rs.collection_method,'status',rs.status,
    'checked_at',rs.checked_at,'updated_at',rs.updated_at,
    'latest_rating',case when sr.id is null then null else jsonb_build_object(
      'rating',sr.rating,'scale',sr.rating_scale,'rating_count',sr.rating_count,
      'review_count',sr.review_count,'checked_at',sr.checked_at,'status',sr.status) end
  ) order by rs.created_at), '[]'::jsonb) into v_result
  from public.review_sources rs
  left join lateral (
    select x.* from public.source_ratings x
    where x.source_id=rs.id and x.status='published'
    order by x.checked_at desc limit 1
  ) sr on true
  where rs.company_id=p_company_id and rs.status <> 'archived';
  return v_result;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."get_my_company_review_sources"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_my_company_review_sources"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_my_company_review_sources"(uuid) TO "service_role";
CREATE FUNCTION public.get_own_review_moderation_queue(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_limit integer := greatest(1, least(coalesce(p_limit,50),100));
  v_result jsonb;
begin
  if v_uid is null then raise exception 'unauthorized' using errcode='42501'; end if;
  if not exists (
    select 1 from private.moderation_operators mo
    where mo.user_id=v_uid and mo.active
  ) then raise exception 'forbidden' using errcode='42501'; end if;

  select coalesce(jsonb_agg(x.item order by x.created_at), '[]'::jsonb)
    into v_result
  from (
    select s.created_at,
      jsonb_build_object(
        'id',s.id,
        'company_id',s.company_id,
        'company_name',c.name,
        'company_slug',c.slug,
        'location_id',s.location_id,
        'location_name',l.name,
        'author_display_name',s.author_display_name,
        'rating',s.rating,
        'body',s.body,
        'language',s.language,
        'status',s.status,
        'ai_moderation_status',s.ai_moderation_status,
        'ai_risk_score',s.ai_risk_score,
        'ai_flags',s.ai_flags,
        'ai_summary',s.ai_summary,
        'ai_moderated_at',s.ai_moderated_at,
        'created_at',s.created_at
      ) as item
    from private.own_review_submissions s
    join public.companies c on c.id=s.company_id
    left join public.company_locations l on l.id=s.location_id
    where s.status in ('draft','verified','disputed')
    order by
      case s.ai_moderation_status when 'flagged' then 0 when 'failed' then 1 when 'pending' then 2 else 3 end,
      s.created_at
    limit v_limit
  ) x;
  return v_result;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."get_own_review_moderation_queue"(integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_own_review_moderation_queue"(integer) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_own_review_moderation_queue"(integer) TO "service_role";
CREATE FUNCTION public.get_public_company_access_state(p_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid; v_state text; v_intake boolean;
begin
  if p_slug is null or length(trim(p_slug)) not between 1 and 80 or trim(p_slug)!~'^[A-Za-z0-9-]+$' then return null; end if;
  select c.id into v_id from public.companies c where lower(c.slug)=lower(trim(p_slug)) limit 1;
  if not found then return null; end if;
  select a.state,a.review_intake_enabled into v_state,v_intake from public.company_profile_public_access a where a.company_id=v_id;
  if not found then return null; end if;
  return jsonb_build_object('state',v_state,'indexable',v_state='active','machine_exports',v_state='active','review_intake',v_state='active' and v_intake);
end; $function$;
REVOKE ALL ON FUNCTION "public"."get_public_company_access_state"(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_public_company_access_state"(text) TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_access_state"(text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_access_state"(text) TO "service_role";
CREATE FUNCTION public.get_public_company_content_v1(p_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_company_id uuid;
begin
 if p_slug is null or length(trim(p_slug))<1 or length(trim(p_slug))>80 or trim(p_slug)!~'^[A-Za-z0-9-]+$' then return null; end if;
 select c.id into v_company_id from public.companies c where c.status='active' and lower(c.slug)=lower(trim(p_slug)) limit 1;
 if not found then return null; end if;
 return jsonb_build_object(
   'reviews',private.get_public_reviews_v1(v_company_id),
   'official_qna',private.get_public_official_qna_v1(v_company_id),
   'knowledge',private.get_public_knowledge_v1(v_company_id)
 );
end $function$;
REVOKE ALL ON FUNCTION "public"."get_public_company_content_v1"(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_public_company_content_v1"(text) TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_content_v1"(text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_content_v1"(text) TO "service_role";
CREATE FUNCTION public.get_public_company_profile_v2(p_slug text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
 select public.get_public_company_profile_v3_candidate(p_slug)
$function$;
REVOKE ALL ON FUNCTION "public"."get_public_company_profile_v2"(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_public_company_profile_v2"(text) TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_profile_v2"(text) TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_profile_v2"(text) TO "authenticated";
CREATE FUNCTION public.get_public_company_profile_v3_candidate(p_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare v_base jsonb;v_content jsonb;
begin
 v_base:=private.get_public_company_profile_v2_legacy(p_slug);
 if v_base is null then return null; end if;
 v_content:=public.get_public_company_content_v1(p_slug);
 return jsonb_set(jsonb_set(v_base,'{reviews}',coalesce(v_content->'reviews','[]'::jsonb),true),'{questions_answers}',coalesce(v_content->'official_qna','[]'::jsonb),true)
 || jsonb_build_object('knowledge',coalesce(v_content->'knowledge','[]'::jsonb));
end $function$;
REVOKE ALL ON FUNCTION "public"."get_public_company_profile_v3_candidate"(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."get_public_company_profile_v3_candidate"(text) TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_profile_v3_candidate"(text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_public_company_profile_v3_candidate"(text) TO "service_role";
CREATE FUNCTION public.moderate_own_review(p_submission_id uuid, p_action text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_review_id uuid;
  v_role text;
begin
  if v_uid is null then raise exception 'unauthorized' using errcode='42501'; end if;
  select mo.role into v_role from private.moderation_operators mo where mo.user_id=v_uid and mo.active;
  if v_role is null then raise exception 'forbidden' using errcode='42501'; end if;
  if p_note is not null and char_length(p_note)>2000 then raise exception 'note_too_long'; end if;

  if p_action='publish' then
    v_review_id := public.publish_own_review_internal(p_submission_id, 'operator:'||v_uid::text, 'approved', p_note);
    return jsonb_build_object('status','published','review_id',v_review_id);
  elsif p_action='reject' then
    perform public.moderate_own_review_internal(p_submission_id,'rejected','operator:'||v_uid::text,'policy_reject',p_note);
    return jsonb_build_object('status','rejected');
  elsif p_action='dispute' then
    perform public.moderate_own_review_internal(p_submission_id,'disputed','operator:'||v_uid::text,'needs_manual_review',p_note);
    return jsonb_build_object('status','disputed');
  else
    raise exception 'invalid_action' using errcode='22023';
  end if;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."moderate_own_review"(uuid, text, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."moderate_own_review"(uuid, text, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."moderate_own_review"(uuid, text, text) TO "service_role";
CREATE FUNCTION public.moderate_own_review_internal(p_submission_id uuid, p_next_status text, p_actor_ref text, p_reason_code text, p_moderator_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_submission private.own_review_submissions%rowtype;
begin
  if p_actor_ref is null or char_length(btrim(p_actor_ref)) not between 3 and 120 then
    raise exception 'invalid actor reference';
  end if;

  if p_reason_code is null or char_length(btrim(p_reason_code)) not between 3 and 80
     or p_reason_code ~ '[^a-z0-9_]' then
    raise exception 'invalid reason code';
  end if;

  if p_moderator_note is not null and char_length(p_moderator_note) > 2000 then
    raise exception 'moderator note too long';
  end if;

  select s.* into v_submission
    from private.own_review_submissions s
   where s.id = p_submission_id
   for update;

  if not found then raise exception 'submission not found'; end if;
  if p_next_status not in ('verified', 'rejected', 'disputed') then
    raise exception 'invalid moderation status';
  end if;
  if v_submission.status = p_next_status then return v_submission.id; end if;

  if not (
    (v_submission.status = 'draft' and p_next_status in ('verified', 'rejected', 'disputed'))
    or (v_submission.status = 'verified' and p_next_status in ('rejected', 'disputed'))
    or (v_submission.status = 'disputed' and p_next_status in ('verified', 'rejected'))
  ) then
    raise exception 'invalid status transition from % to %', v_submission.status, p_next_status;
  end if;

  update private.own_review_submissions
     set status = p_next_status, moderator_notes = p_moderator_note,
         moderated_at = now(), updated_at = now()
   where id = v_submission.id;

  insert into public.audit_log (company_id, user_id, action, target_type, target_id, metadata)
  values (v_submission.company_id, null, 'own_review.moderated',
    'own_review_submission', v_submission.id::text,
    jsonb_build_object('previous_status', v_submission.status, 'next_status', p_next_status,
      'reason_code', btrim(p_reason_code), 'actor_ref', btrim(p_actor_ref)));

  return v_submission.id;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."moderate_own_review_internal"(uuid, text, text, text, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."moderate_own_review_internal"(uuid, text, text, text, text) TO "service_role";
CREATE FUNCTION public.owner_remove_company_member(p_company_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_owner uuid := auth.uid();
begin
  if v_owner is null then raise exception using errcode='42501',message='Authentication required'; end if;
  if not exists(select 1 from public.company_memberships where company_id=p_company_id and user_id=v_owner and role='owner' and verification_status='verified')
    then raise exception using errcode='42501',message='Verified owner required'; end if;
  if p_user_id=v_owner then raise exception using errcode='22023',message='Owner cannot remove self'; end if;
  delete from public.company_memberships where company_id=p_company_id and user_id=p_user_id and role<>'owner';
  return found;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."owner_remove_company_member"(uuid, uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."owner_remove_company_member"(uuid, uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."owner_remove_company_member"(uuid, uuid) TO "service_role";
CREATE FUNCTION public.owner_update_company_member_role(p_company_id uuid, p_user_id uuid, p_role text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_role not in ('admin','manager','analyst') then raise exception 'Invalid role'; end if;
  if not exists(select 1 from public.company_memberships where company_id=p_company_id and user_id=auth.uid() and role='owner' and verification_status='verified') then raise exception 'Owner required'; end if;
  if p_user_id=auth.uid() then raise exception 'Owner role cannot be changed here'; end if;
  update public.company_memberships set role=p_role where company_id=p_company_id and user_id=p_user_id and role<>'owner';
  return found;
end $function$;
REVOKE ALL ON FUNCTION "public"."owner_update_company_member_role"(uuid, uuid, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."owner_update_company_member_role"(uuid, uuid, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."owner_update_company_member_role"(uuid, uuid, text) TO "service_role";
CREATE FUNCTION public.publish_my_company_knowledge(p_company_id uuid, p_variant_id uuid, p_audience text DEFAULT 'public'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text; v_concept uuid; v_lang text; v_verification text; v_pub uuid;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select cm.role into v_role from public.company_memberships cm join public.role_permissions rp on rp.role=cm.role and rp.permission_code='knowledge.publish'
 where cm.company_id=p_company_id and cm.user_id=v_uid and cm.verification_status='verified' limit 1;
 if v_role is null then raise exception 'knowledge_publish_access_required' using errcode='42501'; end if;
 if p_audience not in ('public','company_ai','internal') then raise exception 'invalid_audience' using errcode='22023'; end if;
 select kvn.concept_id,kv.language,kv.verification_status into v_concept,v_lang,v_verification
 from private.knowledge_variants_v1 kv join private.knowledge_versions_v1 kvn on kvn.company_id=kv.company_id and kvn.id=kv.version_id
 where kv.company_id=p_company_id and kv.id=p_variant_id;
 if v_concept is null then raise exception 'knowledge_variant_not_found' using errcode='P0002'; end if;
 if v_verification<>'verified' then raise exception 'knowledge_variant_not_verified' using errcode='42501'; end if;
 update private.knowledge_publications_v1 set status='withdrawn',withdrawn_at=now()
 where company_id=p_company_id and concept_id=v_concept and audience=p_audience and language=v_lang and status='published';
 insert into private.knowledge_publications_v1(company_id,concept_id,variant_id,audience,language,status)
 values(p_company_id,v_concept,p_variant_id,p_audience,v_lang,'published') returning id into v_pub;
 return jsonb_build_object('publication_id',v_pub,'concept_id',v_concept,'variant_id',p_variant_id,'audience',p_audience,'status','published');
end $function$;
REVOKE ALL ON FUNCTION "public"."publish_my_company_knowledge"(uuid, uuid, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."publish_my_company_knowledge"(uuid, uuid, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."publish_my_company_knowledge"(uuid, uuid, text) TO "service_role";
CREATE FUNCTION public.publish_own_review_internal(p_submission_id uuid, p_actor_ref text, p_reason_code text DEFAULT 'approved'::text, p_moderator_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'extensions'
AS $function$
declare
  v_submission private.own_review_submissions%rowtype;
  v_source_id uuid; v_review_id uuid; v_company_slug text; v_profile_url text; v_content_hash text;
begin
  if p_actor_ref is null or char_length(btrim(p_actor_ref)) not between 3 and 120 then raise exception 'invalid actor reference'; end if;
  if p_reason_code <> 'approved' then raise exception 'invalid publication reason'; end if;
  if p_moderator_note is not null and char_length(p_moderator_note)>2000 then raise exception 'moderator note too long'; end if;
  select s.* into v_submission from private.own_review_submissions s where s.id=p_submission_id for update;
  if not found then raise exception 'submission not found'; end if;
  if v_submission.status='published' then if v_submission.published_review_id is null then raise exception 'published submission has no review link'; end if; return v_submission.published_review_id; end if;
  if v_submission.status not in ('draft','verified') then raise exception 'submission cannot be published from status %',v_submission.status; end if;
  select c.slug into v_company_slug from public.companies c where c.id=v_submission.company_id and c.status='active' and c.profile_status='ready';
  if v_company_slug is null then raise exception 'company unavailable'; end if;
  if v_submission.location_id is not null and not exists(select 1 from public.company_locations l where l.id=v_submission.location_id and l.company_id=v_submission.company_id and l.status='published') then raise exception 'location unavailable'; end if;
  v_profile_url:='https://'||v_company_slug||'.xn--b1ajuq0c.com/';
  insert into public.review_sources(company_id,location_id,name,source_type,profile_url,collection_method,terms_notes,status,checked_at)
  values(v_submission.company_id,null,'Отзыв.com','first_party_reviews',v_profile_url,'direct_user_submission','Опубликовано после ручной модерации оператором Отзыв.com','published',now())
  on conflict(company_id,profile_url) do update set name=excluded.name,source_type=excluded.source_type,collection_method=excluded.collection_method,terms_notes=excluded.terms_notes,status='published',checked_at=excluded.checked_at,updated_at=now()
  returning id into v_source_id;
  v_content_hash:=encode(extensions.digest(convert_to(v_submission.company_id::text||E'\n'||v_submission.id::text||E'\n'||v_submission.rating::text||E'\n'||v_submission.author_display_name||E'\n'||v_submission.body,'UTF8'),'sha256'),'hex');
  insert into public.reviews(company_id,source_id,location_id,source_review_id,source_url,author_display_name,published_at,source_updated_at,collected_at,rating,rating_scale,body,excerpt,language,content_hash,provenance,status)
  values(v_submission.company_id,v_source_id,v_submission.location_id,v_submission.id::text,v_profile_url||'#review-'||v_submission.id::text,v_submission.author_display_name,now(),now(),v_submission.created_at,v_submission.rating,5,v_submission.body,v_submission.body,v_submission.language,v_content_hash,jsonb_build_object('source','Отзыв.com','source_type','first_party_reviews','collection_method','direct_user_submission','moderation','manual','submission_id',v_submission.id,'published_at',now()),'published')
  on conflict(source_id,source_review_id) do update set location_id=excluded.location_id,source_url=excluded.source_url,author_display_name=excluded.author_display_name,source_updated_at=excluded.source_updated_at,rating=excluded.rating,rating_scale=excluded.rating_scale,body=excluded.body,excerpt=excluded.excerpt,language=excluded.language,content_hash=excluded.content_hash,provenance=excluded.provenance,status='published',updated_at=now()
  returning id into v_review_id;
  update private.own_review_submissions set status='published',moderator_notes=p_moderator_note,moderated_at=now(),published_review_id=v_review_id,updated_at=now() where id=v_submission.id;
  insert into public.audit_log(company_id,user_id,action,target_type,target_id,metadata)
  values(v_submission.company_id,null,'own_review.published','review',v_review_id::text,
    jsonb_build_object('submission_id',v_submission.id,'previous_status',v_submission.status,'next_status','published','reason_code',p_reason_code,'actor_ref',btrim(p_actor_ref),'content_hash',v_content_hash,
      'ai_moderation_status',v_submission.ai_moderation_status,'ai_risk_score',v_submission.ai_risk_score,'ai_flags',coalesce(v_submission.ai_moderation_flags,'[]'::jsonb)));
  return v_review_id;
end;$function$;
REVOKE ALL ON FUNCTION "public"."publish_own_review_internal"(uuid, text, text, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."publish_own_review_internal"(uuid, text, text, text) TO "service_role";
CREATE FUNCTION public.record_own_review_ai_assessment_internal(p_submission_id uuid, p_status text, p_risk_score numeric DEFAULT NULL::numeric, p_flags jsonb DEFAULT '[]'::jsonb, p_summary text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_submission private.own_review_submissions%rowtype;
begin
  if p_status not in ('passed','flagged','failed') then raise exception 'invalid_ai_status'; end if;
  if p_risk_score is not null and (p_risk_score < 0 or p_risk_score > 1) then raise exception 'invalid_risk_score'; end if;
  if p_flags is null or jsonb_typeof(p_flags) <> 'array' then raise exception 'invalid_flags'; end if;
  if p_summary is not null and char_length(p_summary) > 2000 then raise exception 'summary_too_long'; end if;

  select s.* into v_submission
  from private.own_review_submissions s
  where s.id=p_submission_id
  for update;
  if not found then raise exception 'submission_not_found' using errcode='P0002'; end if;

  if v_submission.status in ('published','rejected','removed') then
    raise exception 'submission_lifecycle_closed' using errcode='55000';
  end if;

  update private.own_review_submissions
     set ai_moderation_status=p_status,
         ai_risk_score=p_risk_score,
         ai_flags=p_flags,
         ai_summary=p_summary,
         ai_moderated_at=now(),
         updated_at=now()
   where id=p_submission_id;

  insert into public.audit_log(company_id,user_id,action,target_type,target_id,metadata)
  values(v_submission.company_id,null,'own_review.ai_assessed','own_review_submission',p_submission_id::text,
    jsonb_build_object('ai_status',p_status,'risk_score',p_risk_score,'flags',p_flags));

  return p_submission_id;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."record_own_review_ai_assessment_internal"(uuid, text, numeric, jsonb, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."record_own_review_ai_assessment_internal"(uuid, text, numeric, jsonb, text) TO "service_role";
CREATE FUNCTION public.record_review_source_rating_snapshot(p_source_id uuid, p_rating numeric, p_rating_scale numeric, p_rating_count integer DEFAULT NULL::integer, p_review_count integer DEFAULT NULL::integer, p_checked_at timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_source public.review_sources%rowtype;
  v_rating public.source_ratings%rowtype;
begin
  if p_source_id is null then
    raise exception 'source_id_required' using errcode='22023';
  end if;
  if p_rating is null or p_rating_scale is null or p_rating_scale <= 0 or p_rating < 0 or p_rating > p_rating_scale then
    raise exception 'invalid_rating' using errcode='22023';
  end if;
  if p_rating_count is not null and p_rating_count < 0 then
    raise exception 'invalid_rating_count' using errcode='22023';
  end if;
  if p_review_count is not null and p_review_count < 0 then
    raise exception 'invalid_review_count' using errcode='22023';
  end if;
  if p_checked_at is null or p_checked_at > now() + interval '5 minutes' then
    raise exception 'invalid_checked_at' using errcode='22023';
  end if;

  select * into v_source
  from public.review_sources
  where id = p_source_id
  for update;

  if not found then
    raise exception 'review_source_not_found' using errcode='P0002';
  end if;
  if v_source.status = 'archived' then
    raise exception 'review_source_archived' using errcode='55000';
  end if;

  insert into public.source_ratings(
    source_id, rating, rating_scale, rating_count, review_count, checked_at, status
  ) values (
    p_source_id, p_rating, p_rating_scale, p_rating_count, p_review_count, p_checked_at, 'published'
  )
  returning * into v_rating;

  update public.review_sources
  set status = 'published',
      checked_at = p_checked_at,
      updated_at = now()
  where id = p_source_id;

  return jsonb_build_object(
    'source_id', p_source_id,
    'source_status', 'published',
    'rating_id', v_rating.id,
    'rating', v_rating.rating,
    'rating_scale', v_rating.rating_scale,
    'rating_count', v_rating.rating_count,
    'review_count', v_rating.review_count,
    'checked_at', v_rating.checked_at,
    'status', v_rating.status
  );
end;
$function$;
REVOKE ALL ON FUNCTION "public"."record_review_source_rating_snapshot"(uuid, numeric, numeric, integer, integer, timestamp with time zone) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."record_review_source_rating_snapshot"(uuid, numeric, numeric, integer, integer, timestamp with time zone) TO "service_role";
CREATE FUNCTION public.recover_stale_review_source_sync_jobs(p_stale_after interval DEFAULT '00:15:00'::interval, p_max_attempts integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_requeued int:=0; v_failed int:=0;
begin
 if p_stale_after < interval '1 minute' or p_stale_after > interval '24 hours' then raise exception 'invalid_stale_after' using errcode='22023'; end if;
 if p_max_attempts < 1 or p_max_attempts > 20 then raise exception 'invalid_max_attempts' using errcode='22023'; end if;
 update private.review_source_sync_jobs j
 set status='failed',finished_at=now(),updated_at=now(),error_code='max_attempts_exceeded',error_message='Stale running job exceeded retry limit'
 where j.status='running' and j.started_at < now()-p_stale_after and j.attempt_count>=p_max_attempts;
 get diagnostics v_failed=row_count;
 update private.review_source_sync_jobs j
 set status='pending',started_at=null,finished_at=null,updated_at=now(),error_code='stale_requeued',error_message='Stale running job returned to queue'
 where j.status='running' and j.started_at < now()-p_stale_after and j.attempt_count<p_max_attempts
 and exists(select 1 from public.review_sources rs where rs.id=j.source_id and rs.status<>'archived');
 get diagnostics v_requeued=row_count;
 return jsonb_build_object('requeued',v_requeued,'failed',v_failed);
end;$function$;
REVOKE ALL ON FUNCTION "public"."recover_stale_review_source_sync_jobs"(interval, integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."recover_stale_review_source_sync_jobs"(interval, integer) TO "service_role";
CREATE FUNCTION public.remove_own_review_internal(p_submission_id uuid, p_actor_ref text, p_reason_code text, p_moderator_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_submission private.own_review_submissions%rowtype;
  v_review public.reviews%rowtype;
begin
  if p_actor_ref is null or char_length(btrim(p_actor_ref)) not between 3 and 120 then
    raise exception 'invalid actor reference';
  end if;

  if p_reason_code is null or char_length(btrim(p_reason_code)) not between 3 and 80
     or p_reason_code ~ '[^a-z0-9_]' then
    raise exception 'invalid reason code';
  end if;

  if p_moderator_note is not null and char_length(p_moderator_note) > 2000 then
    raise exception 'moderator note too long';
  end if;

  select s.* into v_submission
    from private.own_review_submissions s
   where s.id = p_submission_id
   for update;

  if not found then raise exception 'submission not found'; end if;

  if v_submission.status = 'removed' then
    return v_submission.published_review_id;
  end if;

  if v_submission.status <> 'published' or v_submission.published_review_id is null then
    raise exception 'only a published submission can be removed';
  end if;

  select r.* into v_review
    from public.reviews r
   where r.id = v_submission.published_review_id
     and r.company_id = v_submission.company_id
   for update;

  if not found then raise exception 'published review not found'; end if;

  update public.reviews
     set status = 'removed',
         source_updated_at = now(),
         updated_at = now()
   where id = v_review.id;

  update private.own_review_submissions
     set status = 'removed',
         moderator_notes = p_moderator_note,
         moderated_at = now(),
         updated_at = now()
   where id = v_submission.id;

  insert into public.audit_log (
    company_id, user_id, action, target_type, target_id, metadata
  )
  values (
    v_submission.company_id,
    null,
    'own_review.removed',
    'review',
    v_review.id::text,
    jsonb_build_object(
      'submission_id', v_submission.id,
      'previous_status', v_submission.status,
      'next_status', 'removed',
      'reason_code', btrim(p_reason_code),
      'actor_ref', btrim(p_actor_ref),
      'content_hash', v_review.content_hash
    )
  );

  return v_review.id;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."remove_own_review_internal"(uuid, text, text, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."remove_own_review_internal"(uuid, text, text, text) TO "service_role";
CREATE FUNCTION public.respond_to_my_company_review(p_company_id uuid, p_review_id uuid, p_statement text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text; v_native jsonb; v_legacy uuid; v_external uuid; v_mirror boolean:=private.native_to_legacy_mirror_enabled_v1();
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select role into v_role from public.company_memberships where company_id=p_company_id and user_id=v_uid and verification_status='verified' and role in ('owner','admin','manager') limit 1;
 if v_role is null then raise exception 'company_write_access_required' using errcode='42501'; end if;
 v_native:=private.write_native_review_response_v1(p_company_id,p_review_id,p_statement,v_uid,v_role);
 if v_mirror then v_legacy:=private.mirror_native_review_response_to_legacy_v1(p_company_id,p_review_id,p_statement,v_uid); end if;
 v_external:=coalesce(v_legacy,(v_native->>'official_statement_id')::uuid);
 insert into public.audit_log(company_id,user_id,action,target_type,target_id,metadata) values(p_company_id,v_uid,'company_review.response_updated','review',p_review_id::text,jsonb_build_object('role',v_role,'statement_id',v_external,'legacy_statement_id',v_legacy,'native_statement_revision_id',v_native->>'statement_revision_id','write_model',case when v_mirror then 'native_first_legacy_mirror' else 'native_only' end));
 return jsonb_build_object('id',v_external,'review_id',p_review_id,'status','published','role',v_role);
end $function$;
REVOKE ALL ON FUNCTION "public"."respond_to_my_company_review"(uuid, uuid, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."respond_to_my_company_review"(uuid, uuid, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."respond_to_my_company_review"(uuid, uuid, text) TO "service_role";
CREATE FUNCTION public.set_company_profile_public_access_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ begin new.updated_at:=now(); return new; end; $function$;
REVOKE ALL ON FUNCTION "public"."set_company_profile_public_access_updated_at"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."set_company_profile_public_access_updated_at"() TO "service_role";
CREATE FUNCTION public.submit_own_review_internal(p_request_id uuid, p_company_slug text, p_location_id uuid, p_author_display_name text, p_author_email text, p_rating integer, p_body text, p_language text, p_terms_version text, p_privacy_version text, p_source_ip_hash text, p_user_agent text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_company_id uuid;
  v_submission_id uuid;
begin
  if p_company_slug is null
     or p_company_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     or char_length(p_company_slug) > 63 then
    raise exception 'invalid company';
  end if;

  select c.id
    into v_company_id
    from public.companies c
    join public.company_profile_public_access a on a.company_id = c.id
   where c.slug = p_company_slug
     and c.status = 'active'
     and c.profile_status = 'ready'
     and a.state = 'active'
     and a.review_intake_enabled is true;

  if v_company_id is null then
    raise exception 'review intake unavailable';
  end if;

  if p_location_id is not null and not exists (
    select 1
      from public.company_locations l
     where l.id = p_location_id
       and l.company_id = v_company_id
       and l.status = 'published'
  ) then
    raise exception 'invalid location';
  end if;

  insert into private.own_review_submissions (
    request_id, company_id, location_id, author_display_name, author_email,
    rating, body, language, experience_confirmed_at, terms_accepted_at,
    terms_version, privacy_accepted_at, privacy_version, source_ip_hash,
    user_agent, status
  )
  values (
    p_request_id, v_company_id, p_location_id, btrim(p_author_display_name),
    lower(btrim(p_author_email)), p_rating, btrim(p_body),
    coalesce(nullif(p_language, ''), 'ru'), now(), now(), p_terms_version,
    now(), p_privacy_version, p_source_ip_hash, left(p_user_agent, 500), 'draft'
  )
  on conflict (request_id) do nothing
  returning id into v_submission_id;

  if v_submission_id is null then
    select s.id into v_submission_id
      from private.own_review_submissions s
     where s.request_id = p_request_id;
  end if;

  return v_submission_id;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."submit_own_review_internal"(uuid, text, uuid, text, text, integer, text, text, text, text, text, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."submit_own_review_internal"(uuid, text, uuid, text, text, integer, text, text, text, text, text, text) TO "service_role";
CREATE FUNCTION public.upsert_my_company_knowledge(p_company_id uuid, p_concept_id uuid, p_concept_type text, p_scope_type text, p_branch_id uuid, p_service_id uuid, p_language text, p_title text, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text; v_concept uuid:=p_concept_id; v_ver uuid; v_variant uuid; v_n int;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select cm.role into v_role from public.company_memberships cm join public.role_permissions rp on rp.role=cm.role and rp.permission_code='knowledge.create'
 where cm.company_id=p_company_id and cm.user_id=v_uid and cm.verification_status='verified' limit 1;
 if v_role is null then raise exception 'knowledge_create_access_required' using errcode='42501'; end if;
 if length(btrim(coalesce(p_body,'')))<1 then raise exception 'invalid_body' using errcode='22023'; end if;
 if p_scope_type not in ('company','branch','service') then raise exception 'invalid_scope' using errcode='22023'; end if;
 if (p_scope_type='company' and (p_branch_id is not null or p_service_id is not null))
 or (p_scope_type='branch' and (p_branch_id is null or p_service_id is not null))
 or (p_scope_type='service' and (p_service_id is null or p_branch_id is not null)) then raise exception 'invalid_scope_target' using errcode='22023'; end if;

 if v_concept is null then
   insert into private.knowledge_concepts_v1(company_id,concept_type,scope_type,branch_id,service_id,authority,status)
   values(p_company_id,coalesce(nullif(btrim(p_concept_type),''),'faq'),p_scope_type,p_branch_id,p_service_id,'native','active')
   returning id into v_concept;
 else
   perform 1 from private.knowledge_concepts_v1 where id=v_concept and company_id=p_company_id and authority='native';
   if not found then raise exception 'knowledge_concept_not_found' using errcode='P0002'; end if;
 end if;

 select coalesce(max(version),0)+1 into v_n from private.knowledge_versions_v1 where company_id=p_company_id and concept_id=v_concept;
 update private.knowledge_versions_v1 set status='superseded' where company_id=p_company_id and concept_id=v_concept and status='current';
 insert into private.knowledge_versions_v1(company_id,concept_id,version,source_language,source_title,source_body,content_checksum,status,provenance)
 values(p_company_id,v_concept,v_n,coalesce(nullif(btrim(p_language),''),'ru'),nullif(btrim(p_title),''),btrim(p_body),
 encode(extensions.digest(btrim(p_body),'sha256'),'hex'),'current',jsonb_build_object('source','cabinet','actor_user_id',v_uid::text,'actor_role',v_role))
 returning id into v_ver;
 insert into private.knowledge_variants_v1(company_id,version_id,language,title,body,origin,source_checksum,verification_status,provenance)
 values(p_company_id,v_ver,coalesce(nullif(btrim(p_language),''),'ru'),nullif(btrim(p_title),''),btrim(p_body),'human',
 encode(extensions.digest(btrim(p_body),'sha256'),'hex'),'unverified',jsonb_build_object('source','cabinet','actor_user_id',v_uid::text))
 returning id into v_variant;
 return jsonb_build_object('concept_id',v_concept,'version_id',v_ver,'variant_id',v_variant,'verification_status','unverified','published',false);
end $function$;
REVOKE ALL ON FUNCTION "public"."upsert_my_company_knowledge"(uuid, uuid, text, text, uuid, uuid, text, text, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."upsert_my_company_knowledge"(uuid, uuid, text, text, uuid, uuid, text, text, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."upsert_my_company_knowledge"(uuid, uuid, text, text, uuid, uuid, text, text, text) TO "service_role";
CREATE FUNCTION public.upsert_my_company_question_answer(p_company_id uuid, p_id uuid, p_question text, p_answer text, p_category text DEFAULT NULL::text, p_program_label text DEFAULT NULL::text, p_publish boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text; v_qid uuid; v_native jsonb; v_legacy uuid; v_external uuid; v_mirror boolean:=private.native_to_legacy_mirror_enabled_v1(); v_status text:=case when p_publish then 'published' else 'draft' end;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select role into v_role from public.company_memberships where company_id=p_company_id and user_id=v_uid and verification_status='verified' and role in ('owner','admin','manager') limit 1;
 if v_role is null then raise exception 'company_write_access_required' using errcode='42501'; end if;
 if p_id is not null then select q.id into v_qid from private.questions_v1 q where q.company_id=p_company_id and (q.id=p_id or q.legacy_qna_id=p_id) limit 1; if v_qid is null then raise exception 'question_answer_not_found' using errcode='P0002'; end if; end if;
 v_native:=private.write_native_qna_v1(p_company_id,v_qid,p_question,p_answer,p_category,p_program_label,p_publish,v_uid,v_role); v_qid:=(v_native->>'question_id')::uuid;
 if v_mirror then v_legacy:=private.mirror_native_qna_to_legacy_v1(p_company_id,v_qid,p_question,p_answer,p_category,p_program_label,p_publish,v_uid,v_role); end if;
 v_external:=coalesce(v_legacy,v_qid);
 insert into public.audit_log(company_id,user_id,action,target_type,target_id,metadata) values(p_company_id,v_uid,'company_question_answer.upserted','question_answer',v_external::text,jsonb_build_object('role',v_role,'status',v_status,'question_id',v_qid,'legacy_id',v_legacy,'write_model',case when v_mirror then 'native_first_legacy_mirror' else 'native_only' end));
 return jsonb_build_object('id',v_external,'status',v_status,'role',v_role);
end $function$;
REVOKE ALL ON FUNCTION "public"."upsert_my_company_question_answer"(uuid, uuid, text, text, text, text, boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."upsert_my_company_question_answer"(uuid, uuid, text, text, text, text, boolean) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."upsert_my_company_question_answer"(uuid, uuid, text, text, text, text, boolean) TO "service_role";
CREATE FUNCTION public.validate_company_statement_review_tenant()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (
    select 1 from public.reviews r
    where r.id = new.review_id::uuid
      and r.company_id = new.company_id
      and r.status = 'published'
  ) then
    raise exception 'review unavailable or belongs to another company' using errcode='23503';
  end if;
  return new;
end;
$function$;
REVOKE ALL ON FUNCTION "public"."validate_company_statement_review_tenant"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."validate_company_statement_review_tenant"() TO "service_role";
CREATE FUNCTION public.verify_my_company_knowledge(p_company_id uuid, p_variant_id uuid, p_decision text, p_review_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare v_uid uuid:=auth.uid(); v_role text; v_status text; v_actor uuid;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select cm.role into v_role from public.company_memberships cm join public.role_permissions rp on rp.role=cm.role and rp.permission_code='knowledge.publish'
 where cm.company_id=p_company_id and cm.user_id=v_uid and cm.verification_status='verified' limit 1;
 if v_role is null then raise exception 'knowledge_verify_access_required' using errcode='42501'; end if;
 v_status:=case p_decision when 'verify' then 'verified' when 'reject' then 'rejected' else null end;
 if v_status is null then raise exception 'invalid_decision' using errcode='22023'; end if;
 if v_status='verified' then
   v_actor:=private.resolve_human_actor_v1(v_uid);
   if v_actor is null then raise exception 'human_actor_required_for_verification' using errcode='42501'; end if;
 end if;
 update private.knowledge_variants_v1 set verification_status=v_status,
 verified_by_actor_id=case when v_status='verified' then v_actor else null end,
 verified_at=case when v_status='verified' then now() else null end,
 review_due_at=case when v_status='verified' then p_review_due_at else null end,updated_at=now()
 where id=p_variant_id and company_id=p_company_id;
 if not found then raise exception 'knowledge_variant_not_found' using errcode='P0002'; end if;
 return jsonb_build_object('variant_id',p_variant_id,'verification_status',v_status);
end $function$;
REVOKE ALL ON FUNCTION "public"."verify_my_company_knowledge"(uuid, uuid, text, timestamp with time zone) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "public"."verify_my_company_knowledge"(uuid, uuid, text, timestamp with time zone) TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."verify_my_company_knowledge"(uuid, uuid, text, timestamp with time zone) TO "service_role";
CREATE FUNCTION private.assert_outbox_payload_refs_safe_v1(p_payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
declare k text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'outbox payload_refs must be a JSON object';
  end if;
  for k in select jsonb_object_keys(p_payload)
  loop
    if lower(k) ~ '(body|text|content|message|email|phone|name|address|title|question|answer|statement|quote|prompt)' then
      raise exception 'outbox payload_refs key "%" may contain content/PII; only identifiers, versions, hashes and flags are allowed', k;
    end if;
  end loop;
end $function$;
REVOKE ALL ON FUNCTION "private"."assert_outbox_payload_refs_safe_v1"(jsonb) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION private.get_public_company_profile_v2_legacy(p_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_company public.companies%rowtype;
begin
 if p_slug is null or length(trim(p_slug))<1 or length(trim(p_slug))>80 or trim(p_slug)!~'^[A-Za-z0-9-]+$' then return null; end if;
 select * into v_company from public.companies c where c.status='active' and lower(c.slug)=lower(trim(p_slug)) limit 1;
 if not found then return null; end if;
 return jsonb_build_object(
'id',v_company.id,'slug',v_company.slug,'name',v_company.name,'description',v_company.description,'legal_name',v_company.legal_name,'website',v_company.website,'phone',v_company.phone,'city',v_company.city,'profile_status',v_company.profile_status,'updated_at',v_company.updated_at,
'locations',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'relationship_type',l.relationship_type,'address',l.canonical_address,'city',l.city,'phone',l.phone,'hours',l.hours,'official_url',l.official_url,'source_url',l.source_url,'verified_at',l.verified_at) order by l.relationship_type,l.name) from public.company_locations l where l.company_id=v_company.id and l.status='published'),'[]'::jsonb),
'services',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'category',s.category,'description',s.description,'official_url',s.official_url,'source_url',s.source_url,'verified_at',s.verified_at) order by s.category,s.name) from public.company_services s where s.company_id=v_company.id and s.status='published'),'[]'::jsonb),
'media',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'type',m.media_type,'object_name',m.storage_object_name,'sort_order',m.sort_order,'alt',m.alt_text,'caption',m.caption,'updated_at',m.updated_at) order by case m.media_type when 'logo' then 0 when 'cover' then 1 else 2 end,m.sort_order,m.created_at) from public.company_media m where m.company_id=v_company.id and m.status='published'),'[]'::jsonb),
'sources',coalesce((select jsonb_agg(jsonb_build_object('id',rs.id,'name',rs.name,'source_type',rs.source_type,'profile_url',rs.profile_url,'collection_method',rs.collection_method,'checked_at',rs.checked_at,'latest_rating',(select jsonb_build_object('rating',sr.rating,'rating_scale',sr.rating_scale,'rating_count',sr.rating_count,'review_count',sr.review_count,'checked_at',sr.checked_at) from public.source_ratings sr where sr.source_id=rs.id and sr.status='published' order by sr.checked_at desc limit 1)) order by rs.name) from public.review_sources rs where rs.company_id=v_company.id and rs.status='published'),'[]'::jsonb),
'native_rating',coalesce((select jsonb_build_object('rating',round(avg(r.rating)::numeric,2),'rating_scale',5,'review_count',count(*)) from public.reviews r join public.review_sources rs on rs.id=r.source_id where r.company_id=v_company.id and r.status='published' and rs.source_type='first_party_reviews' and r.rating is not null),jsonb_build_object('rating',null,'rating_scale',5,'review_count',0)),
'reviews',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'source_id',r.source_id,'location_id',r.location_id,'source_review_id',r.source_review_id,'source_url',r.source_url,'author',r.author_display_name,'published_at',r.published_at,'collected_at',r.collected_at,'rating',r.rating,'rating_scale',r.rating_scale,'body',r.body,'excerpt',r.excerpt,'language',r.language,'provenance',r.provenance,'company_response',(select jsonb_build_object('statement',cs.statement,'published_at',cs.updated_at) from public.company_statements cs where cs.company_id=v_company.id and cs.review_id=r.id::text and cs.status='published' order by cs.updated_at desc limit 1)) order by r.published_at desc nulls last) from public.reviews r join public.review_sources rs on rs.id=r.source_id where r.company_id=v_company.id and r.status='published' and rs.source_type='first_party_reviews'),'[]'::jsonb),
'questions_answers',coalesce((select jsonb_agg(jsonb_build_object('id',qa.id,'question',qa.question,'answer',qa.answer,'scope_type',qa.scope_type,'category',qa.category,'program',qa.program_label,'source_system',qa.source_system,'source_ref',qa.source_ref,'provenance',qa.provenance,'answered_at',qa.answered_at,'published_at',qa.published_at,'updated_at',qa.updated_at) order by qa.published_at desc nulls last,qa.created_at desc) from public.company_questions_answers qa where qa.company_id=v_company.id and qa.status='published'),'[]'::jsonb));
end $function$;
REVOKE ALL ON FUNCTION "private"."get_public_company_profile_v2_legacy"(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."get_public_company_profile_v2_legacy"(text) TO "service_role";
CREATE FUNCTION private.get_public_knowledge_v1(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'private', 'public'
AS $function$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'concept_id',kc.id,
      'type',kc.concept_type,
      'scope_type',kc.scope_type,
      'branch_id',kc.branch_id,
      'service_id',kc.service_id,
      'authority',kc.authority,
      'language',kv.language,
      'title',kv.title,
      'body',kv.body,
      'verified_at',kv.verified_at,
      'review_due_at',kv.review_due_at,
      'published_at',kp.published_at
    ) order by kp.published_at desc,kc.id
  ),'[]'::jsonb)
  from private.knowledge_publications_v1 kp
  join private.knowledge_concepts_v1 kc
    on kc.company_id=kp.company_id and kc.id=kp.concept_id and kc.status='active'
  join private.knowledge_variants_v1 kv
    on kv.company_id=kp.company_id and kv.id=kp.variant_id
  join private.knowledge_versions_v1 kver
    on kver.company_id=kv.company_id and kver.id=kv.version_id and kver.concept_id=kc.id
  where kp.company_id=p_company_id
    and kp.audience='public'
    and kp.status='published'
    and kv.verification_status='verified'
    and (kv.review_due_at is null or kv.review_due_at>=now())
$function$;
REVOKE ALL ON FUNCTION "private"."get_public_knowledge_v1"(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION private.get_public_official_qna_v1(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'private', 'public'
AS $function$
select coalesce(jsonb_agg(jsonb_build_object(
'id',coalesce(q.legacy_qna_id,q.id),'question_id',q.id,'question',qr.body_public,'answer',sr.body,'language',qr.language,'answered_at',q.answered_at,'published_at',sr.published_at,'updated_at',greatest(q.updated_at,sr.created_at),'category',q.category,'program_label',q.program_label
) order by sr.published_at desc nulls last,q.created_at desc),'[]'::jsonb)
from private.questions_v1 q
join private.question_revisions_v1 qr on qr.company_id=q.company_id and qr.id=q.current_revision_id
join private.official_statements_v2 os on os.company_id=q.company_id and os.question_id=q.id
join private.statement_revisions_v2 sr on sr.company_id=os.company_id and sr.id=os.current_published_revision_id and sr.status='published'
where q.company_id=p_company_id and q.status not in ('pending','needs_clarification','rejected','merged','hidden','archived') and q.answered_at is not null and qr.erased_at is null and qr.body_public is not null
$function$;
REVOKE ALL ON FUNCTION "private"."get_public_official_qna_v1"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."get_public_official_qna_v1"(uuid) TO "service_role";
CREATE FUNCTION private.get_public_reviews_v1(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'private', 'public'
AS $function$
select coalesce(jsonb_agg(jsonb_build_object(
'id',r.id,'source_id',r.source_id,'location_id',r.location_id,'source_review_id',r.source_review_id,'source_url',r.source_url,'author',r.author_display_name,'published_at',r.published_at,'collected_at',r.collected_at,'rating',r.rating,'rating_scale',r.rating_scale,'body',coalesce(rr.body_public,r.body),'excerpt',r.excerpt,'language',coalesce(rr.language,r.language),'provenance',r.provenance,
'company_response',(select jsonb_build_object('statement',sr.body,'published_at',sr.published_at) from private.official_statements_v2 os join private.statement_revisions_v2 sr on sr.company_id=os.company_id and sr.id=os.current_published_revision_id where os.company_id=r.company_id and os.review_id=r.id and sr.status='published' limit 1)
) order by r.published_at desc nulls last),'[]'::jsonb)
from public.reviews r join public.review_sources rs on rs.id=r.source_id
left join lateral (select x.body_public,x.language from private.review_revisions_v1 x where x.company_id=r.company_id and x.review_id=r.id and x.erased_at is null and x.redaction_status<>'erased' order by x.version desc limit 1) rr on true
where r.company_id=p_company_id and r.status='published' and rs.source_type='first_party_reviews'
$function$;
REVOKE ALL ON FUNCTION "private"."get_public_reviews_v1"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."get_public_reviews_v1"(uuid) TO "service_role";
CREATE FUNCTION private.mirror_native_qna_to_legacy_v1(p_company_id uuid, p_question_id uuid, p_question text, p_answer text, p_category text, p_program_label text, p_publish boolean, p_user_id uuid, p_role text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_legacy uuid; v_now timestamptz:=now();
begin
 select legacy_qna_id into v_legacy from private.questions_v1 where id=p_question_id and company_id=p_company_id for update;
 perform set_config('otzovik.native_mirror','on',true);
 if v_legacy is null then
   insert into public.company_questions_answers(company_id,question,answer,category,program_label,source_system,provenance,status,answered_at,published_at)
   values(p_company_id,btrim(p_question),btrim(p_answer),nullif(btrim(p_category),''),nullif(btrim(p_program_label),''),'otzovik',jsonb_build_object('source','phase9b_native_mirror','actor_user_id',p_user_id,'actor_role',p_role),case when p_publish then 'published' else 'draft' end,v_now,case when p_publish then v_now else null end) returning id into v_legacy;
   update private.questions_v1 set legacy_qna_id=v_legacy where id=p_question_id and company_id=p_company_id;
 else
   update public.company_questions_answers set question=btrim(p_question),answer=btrim(p_answer),category=nullif(btrim(p_category),''),program_label=nullif(btrim(p_program_label),''),status=case when p_publish then 'published' else 'draft' end,answered_at=v_now,published_at=case when p_publish then coalesce(published_at,v_now) else null end,updated_at=v_now,provenance=coalesce(provenance,'{}'::jsonb)||jsonb_build_object('source','phase9b_native_mirror','last_actor_user_id',p_user_id,'last_actor_role',p_role) where id=v_legacy and company_id=p_company_id;
 end if;
 perform set_config('otzovik.native_mirror','off',true);
 return v_legacy;
exception when others then perform set_config('otzovik.native_mirror','off',true); raise;
end $function$;
REVOKE ALL ON FUNCTION "private"."mirror_native_qna_to_legacy_v1"(uuid, uuid, text, text, text, text, boolean, uuid, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."mirror_native_qna_to_legacy_v1"(uuid, uuid, text, text, text, text, boolean, uuid, text) TO "service_role";
CREATE FUNCTION private.mirror_native_review_response_to_legacy_v1(p_company_id uuid, p_review_id uuid, p_statement text, p_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;
begin
 perform set_config('otzovik.native_mirror','on',true);
 select id into v_id from public.company_statements where company_id=p_company_id and review_id=p_review_id::text and status='published' order by updated_at desc limit 1 for update;
 if v_id is null then
   insert into public.company_statements(company_id,user_id,review_id,statement,status) values(p_company_id,p_user_id,p_review_id::text,btrim(p_statement),'published') returning id into v_id;
 else
   update public.company_statements set user_id=p_user_id,statement=btrim(p_statement),updated_at=now() where id=v_id;
 end if;
 perform set_config('otzovik.native_mirror','off',true);
 return v_id;
exception when others then perform set_config('otzovik.native_mirror','off',true); raise;
end $function$;
REVOKE ALL ON FUNCTION "private"."mirror_native_review_response_to_legacy_v1"(uuid, uuid, text, uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."mirror_native_review_response_to_legacy_v1"(uuid, uuid, text, uuid) TO "service_role";
CREATE FUNCTION private.native_to_legacy_mirror_enabled_v1()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select coalesce((select enabled from private.compatibility_flags_v1 where key='native_to_legacy_mirror'),true) $function$;
REVOKE ALL ON FUNCTION "private"."native_to_legacy_mirror_enabled_v1"() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."native_to_legacy_mirror_enabled_v1"() TO "service_role";
CREATE FUNCTION private.resolve_human_actor_v1(p_user_id uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'private'
AS $function$
 select a.id from private.persons p join private.actors a on a.person_id=p.id
 where p.auth_user_id=p_user_id and p.erased_at is null and a.actor_type='human' and a.active=true
 order by a.created_at limit 1
$function$;
REVOKE ALL ON FUNCTION "private"."resolve_human_actor_v1"(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."resolve_human_actor_v1"(uuid) TO "service_role";
CREATE FUNCTION private.write_native_qna_v1(p_company_id uuid, p_question_id uuid, p_question text, p_answer text, p_category text, p_program_label text, p_publish boolean, p_user_id uuid, p_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_q uuid:=p_question_id; v_qr uuid; v_os uuid; v_sr uuid; v_qver int; v_sver int; v_status text:=case when p_publish then 'answered' else 'pending' end;
begin
 if char_length(btrim(coalesce(p_question,''))) not between 3 and 2000 then raise exception 'invalid_question' using errcode='22023'; end if;
 if char_length(btrim(coalesce(p_answer,''))) not between 1 and 10000 then raise exception 'invalid_answer' using errcode='22023'; end if;
 if v_q is null then
   insert into private.questions_v1(company_id,status,category,program_label,answered_at)
   values(p_company_id,v_status,nullif(btrim(p_category),''),nullif(btrim(p_program_label),''),case when p_publish then now() else null end) returning id into v_q;
 else
   if not exists(select 1 from private.questions_v1 where id=v_q and company_id=p_company_id) then raise exception 'question_not_found' using errcode='P0002'; end if;
   update private.questions_v1 set status=v_status,category=nullif(btrim(p_category),''),program_label=nullif(btrim(p_program_label),''),answered_at=case when p_publish then coalesce(answered_at,now()) else null end,updated_at=now() where id=v_q and company_id=p_company_id;
 end if;
 select coalesce(max(version),0)+1 into v_qver from private.question_revisions_v1 where company_id=p_company_id and question_id=v_q;
 insert into private.question_revisions_v1(company_id,question_id,version,body_original,body_public,language,content_hash,provenance)
 values(p_company_id,v_q,v_qver,btrim(p_question),btrim(p_question),'ru',encode(extensions.digest(btrim(p_question),'sha256'),'hex'),jsonb_build_object('source','phase9a_native_writer','actor_user_id',p_user_id,'actor_role',p_role)) returning id into v_qr;
 update private.questions_v1 set current_revision_id=v_qr,updated_at=now() where id=v_q and company_id=p_company_id;
 select id into v_os from private.official_statements_v2 where company_id=p_company_id and question_id=v_q limit 1 for update;
 if v_os is null then insert into private.official_statements_v2(company_id,question_id) values(p_company_id,v_q) returning id into v_os; end if;
 select coalesce(max(version),0)+1 into v_sver from private.statement_revisions_v2 where company_id=p_company_id and official_statement_id=v_os;
 if p_publish then update private.statement_revisions_v2 set status='superseded' where company_id=p_company_id and official_statement_id=v_os and status='published';
 else update private.statement_revisions_v2 set status='superseded' where company_id=p_company_id and official_statement_id=v_os and status='draft'; end if;
 insert into private.statement_revisions_v2(company_id,official_statement_id,version,body,status,provenance,published_at)
 values(p_company_id,v_os,v_sver,btrim(p_answer),case when p_publish then 'published' else 'draft' end,jsonb_build_object('source','phase9a_native_writer','actor_user_id',p_user_id,'actor_role',p_role),case when p_publish then now() else null end) returning id into v_sr;
 update private.official_statements_v2 set current_published_revision_id=case when p_publish then v_sr else current_published_revision_id end,current_draft_revision_id=case when p_publish then null else v_sr end,updated_at=now() where id=v_os and company_id=p_company_id;
 return jsonb_build_object('question_id',v_q,'question_revision_id',v_qr,'statement_revision_id',v_sr,'status',case when p_publish then 'published' else 'draft' end);
end $function$;
REVOKE ALL ON FUNCTION "private"."write_native_qna_v1"(uuid, uuid, text, text, text, text, boolean, uuid, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."write_native_qna_v1"(uuid, uuid, text, text, text, text, boolean, uuid, text) TO "service_role";
CREATE FUNCTION private.write_native_review_response_v1(p_company_id uuid, p_review_id uuid, p_body text, p_user_id uuid, p_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_os uuid; v_rr uuid; v_sr uuid; v_ver int;
begin
 if char_length(btrim(coalesce(p_body,''))) not between 1 and 5000 then raise exception 'invalid_statement' using errcode='22023'; end if;
 if not exists(select 1 from public.reviews r where r.id=p_review_id and r.company_id=p_company_id and r.status='published') then raise exception 'review_not_found' using errcode='P0002'; end if;
 select rr.id into v_rr from private.review_revisions_v1 rr where rr.company_id=p_company_id and rr.review_id=p_review_id and rr.erased_at is null order by rr.version desc limit 1;
 if v_rr is null then
   insert into private.review_revisions_v1(company_id,review_id,version,body_original,body_public,language,content_hash,provenance)
   select r.company_id,r.id,1,r.body,r.body,coalesce(r.language,'ru'),encode(extensions.digest(coalesce(r.body,''),'sha256'),'hex'),jsonb_build_object('source','phase9a_review_compat')
   from public.reviews r where r.id=p_review_id and r.company_id=p_company_id returning id into v_rr;
 end if;
 select id into v_os from private.official_statements_v2 where company_id=p_company_id and review_id=p_review_id limit 1 for update;
 if v_os is null then insert into private.official_statements_v2(company_id,review_id) values(p_company_id,p_review_id) returning id into v_os; end if;
 select coalesce(max(version),0)+1 into v_ver from private.statement_revisions_v2 where company_id=p_company_id and official_statement_id=v_os;
 update private.statement_revisions_v2 set status='superseded' where company_id=p_company_id and official_statement_id=v_os and status='published';
 insert into private.statement_revisions_v2(company_id,official_statement_id,version,body,status,responds_to_review_revision_id,provenance,published_at)
 values(p_company_id,v_os,v_ver,btrim(p_body),'published',v_rr,jsonb_build_object('source','phase9a_native_writer','actor_user_id',p_user_id,'actor_role',p_role),now()) returning id into v_sr;
 update private.official_statements_v2 set current_published_revision_id=v_sr,current_draft_revision_id=null,updated_at=now() where id=v_os and company_id=p_company_id;
 return jsonb_build_object('official_statement_id',v_os,'statement_revision_id',v_sr,'version',v_ver,'status','published');
end $function$;
REVOKE ALL ON FUNCTION "private"."write_native_review_response_v1"(uuid, uuid, text, uuid, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION "private"."write_native_review_response_v1"(uuid, uuid, text, uuid, text) TO "service_role";
CREATE POLICY "source_ratings_owner_admin_select" ON "public"."source_ratings" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM (review_sources rs
     JOIN company_memberships cm ON ((cm.company_id = rs.company_id)))
  WHERE ((rs.id = source_ratings.source_id) AND (cm.user_id = ( SELECT auth.uid() AS uid)) AND (cm.verification_status = 'verified'::text) AND (cm.role = ANY (ARRAY['owner'::text, 'admin'::text]))))));
CREATE POLICY "review_sources_owner_admin_insert" ON "public"."review_sources" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((status = 'draft'::text) AND (collection_method = 'owner_submitted'::text) AND (EXISTS ( SELECT 1
   FROM company_memberships cm
  WHERE ((cm.company_id = review_sources.company_id) AND (cm.user_id = ( SELECT auth.uid() AS uid)) AND (cm.verification_status = 'verified'::text) AND (cm.role = ANY (ARRAY['owner'::text, 'admin'::text])))))));
CREATE POLICY "review_sources_owner_admin_select" ON "public"."review_sources" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM company_memberships cm
  WHERE ((cm.company_id = review_sources.company_id) AND (cm.user_id = ( SELECT auth.uid() AS uid)) AND (cm.verification_status = 'verified'::text) AND (cm.role = ANY (ARRAY['owner'::text, 'admin'::text]))))));
CREATE POLICY "review_sources_owner_admin_update" ON "public"."review_sources" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM company_memberships cm
  WHERE ((cm.company_id = review_sources.company_id) AND (cm.user_id = ( SELECT auth.uid() AS uid)) AND (cm.verification_status = 'verified'::text) AND (cm.role = ANY (ARRAY['owner'::text, 'admin'::text])))))) WITH CHECK (((status = ANY (ARRAY['draft'::text, 'archived'::text])) AND (EXISTS ( SELECT 1
   FROM company_memberships cm
  WHERE ((cm.company_id = review_sources.company_id) AND (cm.user_id = ( SELECT auth.uid() AS uid)) AND (cm.verification_status = 'verified'::text) AND (cm.role = ANY (ARRAY['owner'::text, 'admin'::text])))))));
CREATE POLICY "statements_member_insert" ON "public"."company_statements" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((( SELECT auth.uid() AS uid) = user_id) AND (EXISTS ( SELECT 1
   FROM company_memberships m
  WHERE ((m.company_id = company_statements.company_id) AND (m.user_id = ( SELECT auth.uid() AS uid)) AND (m.verification_status = 'verified'::text) AND (m.role = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text])))))));
CREATE POLICY "statements_member_read" ON "public"."company_statements" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM company_memberships m
  WHERE ((m.company_id = company_statements.company_id) AND (m.user_id = ( SELECT auth.uid() AS uid)) AND (m.verification_status = 'verified'::text)))));
CREATE POLICY "statements_member_update" ON "public"."company_statements" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((( SELECT auth.uid() AS uid) = user_id) AND (EXISTS ( SELECT 1
   FROM company_memberships m
  WHERE ((m.company_id = company_statements.company_id) AND (m.user_id = ( SELECT auth.uid() AS uid)) AND (m.verification_status = 'verified'::text) AND (m.role = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text]))))))) WITH CHECK (((( SELECT auth.uid() AS uid) = user_id) AND (EXISTS ( SELECT 1
   FROM company_memberships m
  WHERE ((m.company_id = company_statements.company_id) AND (m.user_id = ( SELECT auth.uid() AS uid)) AND (m.verification_status = 'verified'::text) AND (m.role = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text])))))));
CREATE POLICY "company_profile_publications_member_read" ON "public"."company_profile_publications" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM company_memberships m
  WHERE ((m.company_id = company_profile_publications.company_id) AND (m.user_id = auth.uid()) AND (m.verification_status = 'verified'::text)))));
CREATE TRIGGER company_profile_public_access_updated_at BEFORE UPDATE ON company_profile_public_access FOR EACH ROW EXECUTE FUNCTION set_company_profile_public_access_updated_at();
CREATE TRIGGER company_statements_review_tenant_guard BEFORE INSERT OR UPDATE OF company_id, review_id ON company_statements FOR EACH ROW EXECUTE FUNCTION validate_company_statement_review_tenant();
CREATE TRIGGER phase8a_statement_sync_v1 AFTER INSERT OR UPDATE OF statement, status ON company_statements FOR EACH ROW EXECUTE FUNCTION private.sync_statement_v2_v1();
CREATE TRIGGER phase8b_qna_sync_v1 AFTER INSERT OR UPDATE OF question, answer, status ON company_questions_answers FOR EACH ROW EXECUTE FUNCTION private.sync_legacy_qna_v1();
CREATE TRIGGER erasure_requests_seed_projection_receipts_v1 AFTER INSERT ON private.erasure_requests FOR EACH ROW EXECUTE FUNCTION private.seed_erasure_projection_receipts_v1();
CREATE TRIGGER outbox_events_v1_payload_guard BEFORE INSERT OR UPDATE OF payload_refs ON private.outbox_events_v1 FOR EACH ROW EXECUTE FUNCTION private.outbox_payload_refs_guard_v1();
COMMIT;
