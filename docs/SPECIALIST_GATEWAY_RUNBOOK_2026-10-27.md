# Specialist server release hardening — PR38

REQUEST22e598f6, task0197ad53-9f26-4b18-a7bf-ecc5a32d954c. Addresses Claude audit1065193a.
Separate branch work/specialist-storage-gateway-20261027, stacked on unchanged PR37 c6f71384.
No PR35/36/pricing/public publisher, no hosted writes, no merge/deployment/DNS changes.
This document replaces the PR37 server-package instructions. All hosted activation requires separate explicit permission.

## Decision and strict guarantee

PROPOSED architecture, implemented/tested only in isolation: app-owned reservations + authenticated Edge gateway.
No managed Storage trigger is part of the new package. The old emitter refuses by default; legacyFixture=true is used only inside loopback/in-memory SQL tests.
Storage policy changes use the documented RLS surface. The service key stays exclusively inside Edge.
Gateway validates every user JWT through Auth getUser; p_owner from the request is ignored. CORS uses an exact Origin allowlist, never as authentication.

A profile lock serializes slot reservation. Capacity = all Storage objects for the profile + active reservations without an object.
At most20 counted slots, including avatar/orphans/uncertain work. Exactly one worker may POST a new object for each reservation UUID.
No signed upload URL is issued. Same UUID/payload reuses the result, changed payload conflicts; deleted UUIDs are tombstoned.
Service-role functions are not executable by anon/authenticated. Direct INSERT/UPDATE/DELETE on this bucket are blocked by restrictive policies, even under an accidental permissive grant.
Copy/move, signed-upload creation and ordinary direct writes were exercised through the actual Storage API in disposable CI.
The service credential is a privileged trust boundary: other privileged backends/admin tools must not write into this bucket outside the protocol. No system can enforce this quota against an unrestricted leaked service key.

Active reservation references use an app-owned RESTRICT foreign key, protecting direct parent/Auth cascades too. Confirmed deletion detaches its FK and clears caption/fingerprint while retaining a minimal tombstone; normal empty-profile deletion still works.

Unknown/timeout uploads NEVER automatically free their slot. Expiry marks an operation stale, not absent.
A late Storage request may still commit after a caller timeout. Freeing on TTL or a single absence probe would reintroduce the race.
Replay never launches another POST. If the object is authoritatively present with matching size/MIME, recover registers it.
Unknown absent operations remain quarantined and visible in the UI. No unsafe Delete/release button is offered.
Operational limitation: automatic reclamation of these unknown slots is NOT implemented. A future decision must specify a proof of quiescence/provider tracing or fresh bucket generation; otherwise retain the slot. This is a liveness tradeoff for the strict safety guarantee, not a soft limit.

Fresh-bucket prerequisite matters. A pre-existing signed upload/TUS capability may outlive an RLS change.
The production preflight requires that this bucket and the advanced schema are absent. Restrictive barriers are installed BEFORE bucket creation, so no old unreserved capability can exist.
The current staging bucket already exists: this package intentionally refuses that baseline. A separate cutover review must handle old tokens/in-flight uploads or choose a fresh bucket generation without automatically moving private data.
Signed DOWNLOAD URLs are different: authorized owner links remain bearer-readable until expiry; tested with60seconds locally. This does not publish profiles.

## P1/P2 acceptance matrix

| Audit | Response | Evidence / remaining gate |
| --- | --- | --- |
| P1-1 unsupported managed trigger | Replaced in active package by app tables/Edge; no trigger needed | Native SQL + real Edge/Storage; new architecture still requires independent review |
| P1-2 strict quota | Atomic reservation, one-shot worker, no direct write path | Three real races at19objects: one success, total20; native concurrent sessions |
| P1-3 production create drift | Exact preflight MD5/ACL/schema pins; before/after definitions and pinned restore | Original00 executed READ ONLY against production; no replacement applied |
| P1-4 rollback/kill | Per-capability switches, upload gate, core-create restore; old read preserved | Enable→disable→enable and data preservation in native/real stack |
| P2 UPDATE/move/copy | Restrictive UPDATE USING + WITH CHECK and INSERT barrier | Real API move/copy/signed-upload denied; privileged root outside trust boundary |
| P2 orphan/GC | Storage-first deletion, deleting state, authoritative finalizer, dry-run and retry | Injected failure returns409; metadata/slot retained until confirmed deletion |
| P2 image contents | Server checks byte size and file signature; no user-supplied URL/path | NOT a full image decoder, AV scanner or EXIF removal; private-editor scope only |
| P2 profile core CAS | Existing last-write-wins unchanged | Explicit acceptance needed; no invented CAS |
| P2 Auth/domain | Fresh read-only config and DNS facts, separate plan below | Hosted recovery/delivery/router NOT VERIFIED |
| P2 partial install/retry | Independent fail-closed phases, advanced RPCs initially disabled, read-only postcheck | Production-baseline fixture assembly; never auto-retry partial install |
| P2 SQL locations | Channels moved to sql/ | Active phase/hash manifest; no auto-migration directory |

No independent acceptance of PR38 is claimed from Claude's PR37 GO. New review is required.

## Read-only production findings

Three existing core functions, exact MD5:
- create_my_specialist_draft(text,text,text,text,text,text):64f33fb6fd83f891363c2035f39ca73c.
- get_my_specialists():82a3057d27c450b18cbb00edc393db78.
- update_my_specialist_draft(uuid,text,text,text,text,text):630a01e05cb0f65cbef110ef4a695e79.

00_PREFLIGHT_CANDIDATE.sql uses BEGIN READ ONLY; no NOTIFY/DDL/CRUD. It passed on production during this task.
It pins definitions, exact effective core ACL sets, FORCE RLS/no browser table grants, profile column/constraint hashes, all Storage-policy hash, and absence of the new objects/bucket.
The baseline JSON contains code/catalog only, no personal rows or credentials.
Core create diff is exactly two added statements: per-user advisory lock and quota10. Candidate canonical MD5 e455f988848cfdbb2d4f2552aaea679e.
RESTORE_CORE_CREATE pins that candidate MD5 before restoring the exact original body; native rollback/data-preservation test passes.
This changes a live core function in any future application and requires explicit review, even though it is only hardening.

A fresh privilege read found postgres is not superuser, has BYPASSRLS, storage.objects owner=supabase_storage_admin, delegated Storage-policy grant=true, TRIGGER privilege=true.
This updates the audit's unverified privilege hypothesis; it does NOT establish managed-trigger support/compatibility. No hosted CREATE TRIGGER or CREATE POLICY was attempted.
The gateway architecture avoids needing the trigger regardless.

Production still lacks the previous five advanced tables,14functions and bucket/policies. Gateway additionally needs two app-owned tables, six new functions (five service-only + one owner capability), restrictive policies and the Edge adapter.
70_POSTCHECK pins23 exact function definitions, private helpers/writers' ACL, FORCE RLS of8tables, private bucket settings and restrictive policy expressions/roles/commands.
Candidate expected catalog is from isolated PostgreSQL17, not a claim that those objects exist hosted.
Stage get/update/create hashes and config were re-read; gateway is not installed in staging.

## Ordered server package — NOT APPLIED HOSTED

scripts/specialist-server-package.mjs is an ordered manifest, not an executor.
Each SQL phase has its own bounded transaction. Stop on the FIRST error; do not repair, overwrite or rerun automatically.

1. Freeze exact PR HEAD and canonical LF hashes, independent audit and approval scope. Take database/definition/ACL/policy backup and retain old frontend artifact.
2. 00 read-only preflight. Any drift or existing advanced objects/bucket aborts this fresh-baseline plan.
3. 05 restrictive Storage barriers. A policy-privilege failure occurs before bucket creation or advanced tables; never change managed ownership/grants to bypass.
4. 10 services,20 settings. New browser RPCs remain revoked.
5. Create private specialist-media bucket THROUGH STORAGE API, not object-table DML:5MiB, JPEG/PNG/WebP only. Requires separate approved operation after barriers.
6. 30 media schema/read policy. No permissive INSERT/DELETE policy is created.
7. 40 core/lifecycle, including the reviewed create replacement. 50 channels (SQL now under sql/).
8. 60 gateway reservations/control and FK/active-reservation-safe profile deletion. Control starts disabled; metadata mutation is service-only.
9. 70 read-only postcheck of exact definitions, ACL/security, bucket and barriers.
10. After a separate Edge-deploy approval, deploy only the reviewed Edge adapter with server credentials and exact central-cabinet Origins. No client secrets. Validate Auth and signed-in HTTP while uploads remain off.
11. After explicit activation approval and smoke readiness: individual ENABLE_SERVICES/SETTINGS/CHANNELS +80_ENABLE_MEDIA. Never restore direct Storage writes.
12. Only after server/Edge checks, separate frontend permission: deploy61-file allowlist artifact. No SQL/server/docs/tests are copied to public output.
13. Smoke owner/foreign/anon, create/Home Edit/reopen, services/settings/channels CAS, photo upload/read/delete, 19→20 concurrency, stale/retry and company regression. No private publication.

A phase failure can leave earlier private schema/barriers installed, but advanced browser interfaces remain off and old UI is not replaced.
If phase40 already ran before a later failure, restore create only through its pinned candidate after permission; otherwise keep data and investigate.
Every candidate is non-idempotent/fail-closed where creation is involved. On retry obtain fresh catalog and a new explicit plan. Do not run db push/repair/include-all.

The real local stack starts from production core definitions/schema/ACL. Its company Storage policy hash is explicitly fixture-bound; the exact original00 separately passed the real production read-only check.
It assembles the whole phase sequence, creates the bucket through the real API and never installs a managed trigger.

## Rollback and reconciliation

Frontend: restore the prior complete artifact; company source bytes unchanged. For temporary disable, show unavailable only on specialist routes and link Home.
Server: DISABLE_MEDIA flips upload/delete admission off, retains authenticated read and all restrictive barriers. Already admitted work may finalize within its reserved slot; turning off is not retroactive cancellation.
Keep the bucket, bytes, metadata, reservations and tombstones. Disable Edge deployment only after admission is off; do not free unknown slots.
ENABLE_MEDIA verifies the barrier/private service boundary before restoring admission; run70 and actual Edge/Auth smoke first.
SERVICES/SETTINGS/CHANNELS have separate enable/disable candidates; core-create has its own pair without touching company or specialist read/edit.
RESTORE_CORE_CREATE restores only the exact old core body. It does not DROP tables or reverse user data. Never downgrade the strengthened profile-delete path while active reservations exist.
DISABLE_LEGACY_GUARD is a reference-only DROP TRIGGER, no DROP FUNCTION/CASCADE; it is not an active gateway step and must not reopen direct writes.

Delete flow: mark deleting under lock → Storage API remove → SQL confirms actual object absence → remove metadata/mark deleted.
On failure keep metadata/state/slot; repeat the SAME operation. Old orphan files are counted and may be explicitly removed through gateway.
Reconcile is read-only; reports object/media presence and expiry. It never trusts a client-provided absent flag and never performs SQL DML on storage.objects.
No cron GC or hosted cleanup was activated. Unknown in-flight reservations cannot be safely reclaimed from absence alone.
Before any later destructive recovery: backup, independent proof of no possible late writer and explicit owner decision; otherwise keep quarantine.

## Auth and domain decisions

Fresh read-only Auth:
production email on/signup on/autoconfirm=true; staging signup disabled/autoconfirm=false.
Both Site URL=http://localhost:3000, redirect allowlist empty, JWT3600, anonymous accounts disabled.
Shared login has signup emailRedirectTo but no reset-password/PASSWORD_RECOVERY UI. Do not silently enable a broken recovery journey or edit company/login files in this PR.
Owner decision needed: stable CENTRAL cabinet origin, exact login/confirmation callback paths, recovery UI/route, SMTP/delivery and confirmation policy. Use exact production redirect paths, not arbitrary tenant wildcard origins.
No Auth setting/template was changed. Mailpit CI proves local delivery only. Hosted Edge environment/legacy service JWT availability remains to verify securely before deployment.

Public read-only DNS on2026-10-27: authoritative NS gail.ns.cloudflare.com / memphis.ns.cloudflare.com.
A random subdomain resolved to Cloudflare A records and HTTPS returned404. This is not evidence of correct public profile routing or Jino readiness.
Approved future direction: <slug>.отзыв.com for company/specialist, shared unique slug registry. Jino NS migration remains separate and was not performed.
Future rollout needs wildcard DNS, TLS covering apex and one-level wildcard, strict Host validation, published-only slug lookup, reserved platform names, NXDOMAIN/unknown-slug behavior and rollback.
Jino documentation describes wildcard routing, but actual Jino account/SSL/routing capability is NOT VERIFIED.
Keep authentication on the central cabinet; do not share account credentials/cookies across arbitrary tenant subdomains. No wildcard Auth allowlist for all tenant hosts.
Current reserved set/ASCII slug contract is unchanged; proposed expanded infrastructure names need separate review. Aggregate-only checks found0collisions for the proposed additional names in specialist profiles and shared registry, no row data copied.
DNS cutover/public subdomains are NOT prerequisites for isolated editor or a future private editor on an existing approved central origin. They do not authorize public publisher work.

## Evidence and remaining gates

Source6d9f2a0: CI40469093644 seven jobs SUCCESS,22 real Supabase/Edge/browser groups, actual server_version_num170011.
Native PostgreSQL17.11: gateway7 concurrent/security groups, package5 including rollback, UX10, Pages61 PASS. Existing15draft/9editor/9channels SQL also run in independent CI jobs.
Final fresh-package/postcheck documentation HEAD has a separate CI run recorded in Hub; earlier source-head results must not be relabeled as final-head results.
Real HTTP mapping observed:40001→500; PT409→409. UI handles both codes; no silent mutation retry/fallback was introduced.
Company33 committed blobs and working bytes are compared against main. Browser sizes320/390/768/1440, Home Edit/menu ids, focus/keyboard and company create/edit/service/photo regression.
Publisher remains a local SQL sentinel, not the real production publisher. Hosted email/CDN/production Worker and existing-token staging cutover are NOT VERIFIED.

GO for isolated prototype testing only. CONDITIONAL GO for a future fresh-bucket server pilot after independent audit and explicit approval.
Production NO-GO now: no hosted package/Edge applied, new architecture/recovery/quarantine/cutover decisions and release permissions outstanding.
Next actions: Claude review exact new HEAD → concrete owner decisions → fresh preflight/backup → separately approved server/Edge pilot → separately approved frontend.
Do not infer migration, deploy, DNS or publication permission from this document.

## Primary references

- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/guides/storage/schema/design
- https://supabase.com/docs/reference/javascript/storage-from-createsigneduploadurl
- https://supabase.com/docs/guides/functions/auth
- https://supabase.com/docs/guides/auth/redirect-urls
- https://o.jino.ru/help/faq/domains-general/wildcard-subdomains/

Changelog fetched and reviewed on2026-10-27; no dependency upgrade. SDK2.115.0/CLI2.121.0 remain pinned.
