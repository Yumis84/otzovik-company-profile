# Stage 2B hosted activation — 23 October 2026

This supersedes the earlier “SQL not applied / hosted save blocked” status for staging only. Production is NOT approved.

## Authorization and exact deployment
Owner explicitly answered “Продолжай” to applying the prepared candidate only to test Supabase, after preflight/recovery and hosted acceptance. Recorded Hub DECISION c2edfa8c-a57a-4e69-8ecf-077eff6b96fc.
Target: salmcnhexlftrgtiryyo. Migration: 20261023093542_specialist_contact_channels_stage2b.
Exact SQL source: docs/specialist-contact-channels-candidate.sql at 6902bb79fe4e0056b0d1dcdc51283be99b00cfa6.
SHA256: 2606f4ae0e75a5b46fdc06fa129ea2a34c98819b8ca592e0735da0a7aef8cdb6.
The candidate filename/header are retained as historical reviewed input; this file is never an automatic production migration.

Preflight confirmed postgres trusted BYPASSRLS/superuser, profile owner_user_id/profile_status columns, no collisions with either new table or three new functions. Snapshot of existing function definitions/ACL metadata and fingerprints of all12 existing public tables was saved privately with exact SQL and a recovery script. This is a scoped pre-change snapshot, not a complete database backup; the migration only adds new objects and does not mutate existing rows. It runs transactionally. One MCP request returned expired requestState; read-only lookup proved no objects existed before the confirmed successful application.

## Recovery
To disable contacts while retaining new data, revoke EXECUTE on list_my_specialist_channels(uuid) and save_my_specialist_channels(uuid,integer,jsonb) from PUBLIC,anon,authenticated, then reload PostgREST schema. Old settings/phone/email remain available; UI already has an unavailable-RPC path. Do not DROP tables or cascade-delete data. Recovery is prepared, not executed. Re-enabling requires deliberate authenticated-only grants and acceptance.

## Database verification
All12 old public table counts and content fingerprints matched both immediately after migration and after hosted tests. All26 old public function definition hashes/owners/search_path/ACL metadata matched after migration. New tables have ENABLE+FORCE RLS, no client table privileges. New list/save RPCs are owned by postgres, SECURITY DEFINER with fixed empty search_path, no anonymous EXECUTE; internal normalize helper is not executable by authenticated/anon.

Advisors were checked before/after. Two new INFO no-policy notices are intentional RPC-only fail-closed tables. Two new WARN authenticated SECURITY DEFINER notices are the intended authenticated API, covered by owner/draft/auth checks and hosted foreign-user tests; no public/anon grant. Existing company mutable search_path and Auth password-protection warnings predate this work and were not modified. Advisor references: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy and https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable .

## Real hosted acceptance
Manual reproducible runner: tests/stage2b-hosted.mjs. Requires private OTZOVIK_TEST_CONFIG with synthetic users, explicit OTZOVIK_TEST_PREVIEW and private OTZOVIK_TEST_OUTPUT; strictly guards approved staging URL/preview hostname. No migration/schema mutation in the runner. No credentials in repo, artifact or logs.

On actual staging Auth/PostgREST and preview (no response mocks):
- Seven kinds save/reopen with canonical links, ordered data and private=false-publicity contract.
- Foreign/anonymous read/write, direct table/helper and cross-profile ID theft denied.
- Hostile URLs, duplicates, quota, multi-preferred and is_public=true reject atomically.
- Two overlapping HTTP writes produce exactly one success and one HTTP409; stale browser tab cannot overwrite.
- Browser Add contact, save, reload, reorder, label edit, removal, safe named links and inert XSS pass.
- Fresh authenticated browser session reopens saved contacts.
- 320/390/1440 without horizontal overflow; existing five navigation links; no redundant type chooser.
- Legacy settings unchanged, zero page errors or company/publication writes.
- Original channel values restored after tests; synthetic links are not left in the user's form.

## Empty section usability
A successfully loaded empty collection now displays one blank editable contact row immediately, without auto-focusing or scrolling. The row is an unsaved form value; nothing is inserted until Save. Removing all rows and saving still clears the collection. Missing/denied RPC does not create a fake editable form. Local SQL-backed browser acceptance checks the initial blank row and real hosted acceptance verifies cleanup/reopen readiness.

No company source, production database, main or working-site deployment changed. PR32 remains Draft and dependent on PR31. All contacts stay private; publication, account ownership verification and broader URL formats remain separate gates.
