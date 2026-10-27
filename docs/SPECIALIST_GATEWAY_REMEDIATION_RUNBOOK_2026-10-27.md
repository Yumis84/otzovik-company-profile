# PR38 remediation: isolated acceptance and operator runbook — 2026-10-27

This is a stacked delta from PR38 b6626a3169836be534a61aa1befecd26a5a55d43. PR37, PR38, main and all hosted systems remain unchanged. REQUEST46b1e18c; Claude audit c875e31c. This document supersedes the PR38 runbook ONLY for failure retirement, erasure, switches and package postconditions. Other deployment/backup/core/Auth/domain gates still apply.

## Decision and release status

GO for disposable tests only. Hosted pilot and production remain NO-GO until independent delta audit and separate owner decisions/permission. No migration directory, automatic deployment, paid provider, DNS change or profile publication. Strict20/quarantine/trusted-writer model, fresh-bucket cutover, Auth confirmation and audit/tombstone retention remain owner decisions. This prototype does not approve them.

## Change map

| Finding | Implemented delta | Evidence |
| --- | --- | --- |
| P1-1 terminal failed uploads consume all20 slots | Completed JSON Storage4xx other than408/409 retire under existing profile lock, only if state uploading and no object. Legacy embedded status500/408/409, timeout/internal/duplicate codes, malformed replies and all network/5xx stay uncertain. Retired request_id is never uploaded again. | HTTP unit3; SQL remediation7; actual PostgREST plus injected terminal Storage response20 times; next genuine Storage upload succeeds |
| P1-1 unknown outcome | No TTL release. Audited service-only operator begin/finish requires upload admission OFF and reviewed external no-late-writer evidence bound to request_id. Unknown missing/mismatched evidence fails closed. | SQL proof/tenant/expiry tests; actual delayed Storage request held, then allowed to finish and explicitly awaited before cleanup |
| P1-2 Auth FK23503 | Keep RESTRICT until safe cleanup. Operator preparation retires known reservations, removes bytes through Storage API, checks object absence, clears FK into tombstone; only then owner/admin deletes draft/account. No raw reservation removal, FK weakening, managed trigger or SQL Storage-object deletion. | Actual Auth admin deletion first fails with quarantine, then succeeds after audited operator preparation, with Storage download absent and old JWT rejected by real Auth |
| P2 upload off prevents deletion | Admission enabled and deletions_enabled are separate; DISABLE_MEDIA only closes admission. Existing media owner delete and pending recovery remain available. UI disables upload form but keeps permitted deletion buttons. | SQL; actual Edge delete while upload off; browser state checks |
| Observability | service-only aggregate RPC exposes pending/quarantined/deleting/rejections/operator retirements/late orphans/over-quota. readGatewayAlerts returns machine-readable alert. | SQL metrics and ACL tests. Alert scheduling/delivery is NOT installed or claimed |
| Cross-OS pins | SQL files have LF checkout via .gitattributes. Company web source bytes unchanged. | Native Windows PostgreSQL17.11 and Linux CI pins |

## Safety model and late writers

One new request_id permits ONE Storage POST with x-upsert=false and a unique name. A terminal Storage rejection is a trusted assertion by the Storage response; SQL independently refuses retirement if an object already exists. The gateway does not retry POST. Replaying a retired ticket returns409 and cannot resurrect the object.

408,409,5xx, thrown fetch errors, lost response, expiry or a missing object alone DO NOT establish a completed writer. In-flight work that was admitted before disabling admission can still finish within its reserved slot.

**No timeout proof is used.** An AbortSignal timeout25s only bounds the caller's wait; it does not bound remote commit, a paused Edge execution, network proxies or future resumption before POST. Edge wall-clock and TTL are insufficient to free an unknown reservation safely. Do not accept an invented elapsed-time ceiling.

Operator proof must establish, outside this database, that ALL potential writers for this exact request are unable to write later: either authoritative provider terminal trace and all gateway executions joined/completed, or revoked old write credentials with all existing executions/remote writes drained and verified. Merely rotating credentials, stopping new admission, restarting Edge, waiting25s or checking Storage absence is NOT sufficient. Record provider/deployment incident reference, request_id and reviewer identity. If this cannot be established, keep quarantine, escalate and retain NO-GO; no unsafe force flag is provided.

The service-only RPC validates evidence shape and records the privileged assertion; **it cannot verify provider operational truth**. These assertions are trusted operator inputs, not independent cryptographic proof. No browser or ordinary gateway action can call force_retire. A service_role compromise remains outside the quota proof and can fabricate assertions/write directly; do not claim protection from a leaked administrator key.

If a privileged writer violates terminal/quiescence evidence and writes after retirement, that object remains counted by normal quota queries and is reported as late_orphan_objects. It is not automatically deleted. An arbitrary privileged late writer can exceed strict20 if other slots were already reused; metrics are detection, not proof of prevention. Tests deliberately inject this trust violation to verify visibility/counting. Genuine unknown writers remain reserved until proven stopped, preserving strict20 inside the trusted protocol.

## SQL candidate order and preflight

Fresh installation uses scripts/specialist-server-package.mjs: 00 READONLY preflight,05 barriers,10services,20settings, Storage API creates private specialist-media bucket,30media,40core,50channels,60gateway, **65remediation**,70 READONLY postcheck. Phase65 verifies exact PR38 begin_delete/capability definitions before replacement; duplicate execution fails before mutation. Adds one private FORCE-RLS audit table and four service-only functions (reject,force_retire,metrics,erasure_inventory); total9 private specialist tables and27 functions. Default-off admission and deletion. Then operator explicitly runs approved80 enable after Edge smoke. Never run this package through hosted migration automation.

An existing isolated PR38 database can use65 only after exact source/catalog/ACL snapshot comparison;70 postcheck then explicit approved activation. No blanket reapply, no best-effort ignored SQL errors. Existing staged bucket/tokens do not satisfy fresh preflight and remain a separate cutover decision.

00 preflight is unchanged and still pins production core/schema/ACL/Storage policy hash. A platform policy change triggers safe refusal, not permission to update pins blindly. Read-only re-snapshot catalog/function definitions/policies, diff intended changes, review new baseline separately, then compile and retest in a fresh disposable stack. Never copy user rows, service keys or Auth secrets into evidence.

70 pins actual PostgreSQL-compiled function definitions, browser ACLs, audit mutation denial,9 FORCE RLS tables, private bucket, three restrictive barriers and27 function count. No private RPC granted to browser. Baseline hosted production preflight was performed in PR38; this task makes no hosted calls or fresh production-state claim.

## Operator erasure: reviewable, resumable, never automatic

server/specialist-media-operator.js exports prepareSpecialistErasure and readGatewayAlerts; it has NO CLI, environment/key discovery, scheduler or implicit execution. The ordinary Edge adapter does not import it.

1. Authenticate the erasure request using the approved account procedure; obtain a specific operator identity and incident/ticket reference. Snapshot nonpersonal technical audit facts and approved backups. Do not retain user photos in an unapproved backup.
2. Close upload admission using separately approved DISABLE_MEDIA; preserve owner deletion/read and Storage restrictive barriers. Quiesce and prove termination of ALL old writers, including paused gateway executions and possible remote commits. No evidence means stop.
3. Inventory EVERY specialist draft of the account (operator read-only catalog review), not just the currently displayed profile. Also inventory company/media ownership and other product data. The specialist helper does not erase company data or assert whole-account completion.
4. For each draft call service-only erasure_inventory with owner+profile, verify ownership and private draft status. It returns only that profile's active reservations and objects. Unregistered legacy objects are made explicit by owner/path-checked begin_delete; if a new request_id requires proof, inspect returned inventory and supply reviewed proof before continuing.
5. Supply actor, reason and per-request proof: kind provider_terminal_no_late_writer OR credentials_revoked_all_writers_drained; evidence_ref referencing reviewed external trace; matching request_id; all_writers_stopped:true. No credentials, personal contacts or photo contents in proof. The boolean alone is insufficient: evidence_ref must identify actual reviewed trace.
6. prepareSpecialistErasure validates all retirement proofs, calls audited force_retire(begin), Storage.remove for bytes/metadata, then force_retire(finish). Failures retain FK/reservation and are safe to retry with the same proof. Finish refuses an existing object. No SQL DELETE on storage.objects. New requests remain disabled.
7. Re-inventory: objects=[], reservations=[], no other profile/Storage ownership remains. Only then invoke authorized owner draft delete or Auth Admin hard-delete. An earlier raw Auth hard-delete may still return23503 by design: it is not the supported erasure procedure. Other company Storage/FK blockers require their separate existing procedure; do not drop constraints.
8. Verify Auth absence, all specialist profiles/objects gone, old JWT denied by gateway Auth lookup, audit begin/finish present, no direct browser Storage mutation. Check late-orphan/over-quota alerts. Decide restoration of upload admission separately.

SQL tiny-fixture tests use synthetic Storage rows to isolate locks/state. Real integration uses actual Auth Admin and Storage API; never present the former as the latter. In the delayed-writer test, the test owns and joins every injected writer before asserting terminal proof. It does not demonstrate an operational hosted provider drain capability.

## Monitoring and retention

Poll specialist_gateway_metrics ONLY from an approved server/operator with service-only RPC privilege. Alert when alert=true OR over_quota_profiles>0; inspect pending growth/deleting age and terminal rejection rate. No IDs/contact data in aggregate response. Persist/send alerts through separately approved infrastructure; this PR does not install production monitoring.

Audit is append-only through granted RPCs; even service_role has no direct INSERT/UPDATE/DELETE grant. Database administrator can still alter it. Minimal request_id/profile_id/object path tombstones and incident evidence are retained to prevent replay and support review. Retention/pseudonymization/deletion policy is pending owner approval, not silently indefinite compliance approval. Do not purge replay tombstones while late writers/replay are possible; do not put PII in evidence.

## Credential rotation and incident response

Keep service_role only in server secret store; never frontend, Hub, logs, screenshot or repo. On suspected leak, close admission, disable affected Edge ingress, inventory active work, rotate/revoke using the approved Supabase key procedure for the project's actual key type. Do not guess that rotating JWT secret has no Auth impact: legacy service keys and user JWTs can share signing configuration. Review effect on company/runtime/Auth before any hosted change. Revoke old access and establish real request drain; rotation alone is not proof. Deploy approved secret to trusted backend, verify old credentials fail, new private RPC ACLs and owner/foreign/anon/company regression, audit actions, then separately approve reopen. No rotation executed here.

## Rollback

Close admission; preserve deletion and private reads, restrictive barriers, active reservations, FK and audit. Roll frontend back as one complete reviewed artifact; specialist routes can be disabled without changing company routes. Never restore direct browser Storage writers or remove tombstones/audit/RESTRICT to make rollback convenient. Keep phase65 safety functions while any data or pending request exists. Destructive DOWN is deliberately absent. Empty disposable fixture can be discarded; hosted rollback requires reviewed state snapshot, writer drain and a separate plan/permission. PR38 code alone cannot classify/retire new terminal failures, so reverting handler can restore the old liveness bug; document and leave admission closed.

## Known limits / next audit

Independent Claude delta audit is pending. No hosted Edge size/CPU/memory/time test, hosted SMTP/recovery, real publisher/CDN/Worker, old signed/TUS token cutover or provider request-drain procedure verified. No media decode/AV/EXIF stripping added; private-only scope remains. Auth confirmation/rate-limiting, core last-write-wins and default localhost redirects remain separate decisions. No claim of complete personal-data erasure for companies/other subsystems. Final exact HEAD/CI and remaining blockers are published in Hub HANDOFF.
