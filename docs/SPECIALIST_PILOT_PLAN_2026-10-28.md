# Specialist pilot plan and operator hardening — 2026-10-28
Delta from PR39 ad6101ef34812cce85f35c94ab0aa8fd0a8f0e99, REQUEST cbb5c7ca, Claude audit1e239ab7. Candidate only. **GO isolated tests; NO-GO hosted pilot/production.**

## Scope and compatibility
Continue existing editor/shared company architecture. No second cabinet, new navigation, company changes, production/main/DNS/NS/Worker changes or publication. Phase66 sits after65 and before70 in the existing reviewed server package. No supabase/migrations directory or automatic SQL application. PR35/36 remain excluded.

Q3 adds operator-only audited cleanup for a sealed tombstone after profile/Auth deletion: only a known request_id, deleted state, null active FK, profile absent and historical audit qualify. No caller-supplied Storage path; begin returns the existing sealed path, Storage API removes bytes/metadata, finish checks absence and records the verified executor. Unknown/foreign/unrecorded paths and live profiles fail closed.

Q2 uses a new owner-authenticated confirmation RPC, an operator authorization and a distinct executor. Ready media refuses quarantine_retire mode; confirmed_erasure mode must reference the database-verified authorization. Proof of stopped writers remains independently required for unknown work. Old p_actor argument is retained for signature compatibility but ignored for attribution: the recorded actor is auth.uid() after registry and authorization checks.

Q1 mitigation: specialist_operator is a dedicated NOLOGIN/NOINHERIT/NOBYPASSRLS role; Edge service_role cannot call authorize/force-retire/inventory/orphan cleanup or mutate/read raw operator tables. Registry initially empty; no hosted identity provisioning included. PostgREST must authenticate a separately issued, scoped, short-lived operator JWT with a real Auth subject. MFA, issuer lifecycle/revocation and actual hosted role provisioning are release gates, NOT implemented by a browser. Do not give the JWT signing key or operator credentials to Edge.

Operator Storage uses the operator JWT and narrow permissive+restrictive SELECT/DELETE policies opened only for that executor's audited begin path. No INSERT/UPDATE, no other bucket/company path, no raw operator-table grants. On finish the path permission closes; registry disable also closes it. Underlying privileged service_role still bypasses Storage RLS: protecting against a stolen service/admin key is outside this protocol; rotate/respond as documented, do not pretend role separation eliminates that root trust.

Q4 retries ONLY idempotent reject bookkeeping after an observed definite4xx: at most3attempts,3s RPC wait each and100/200ms backoff. Network/HTTP5xx retry; authorization/validation/conflict errors stop. Storage POST is NEVER retried. A lost response after committed reject returns the same tombstone, with one audit entry. Exhaustion leaves unknown reservation and reports failure; replay never re-uploads. 408/409/network upload outcomes do not enter reject retry. These client bounds do not establish a remote drain deadline.

Severity: none / warning for expired quarantine / critical for late orphan or combined object+unrepresented-reservation over-quota. Counts include orphan objects and reserved slots. No auto-release, sweep deletion, or deployed alert delivery.

## Explicit two-phase operator flow
1. Authenticate owner; they explicitly call confirm_my_specialist_erasure(profile,confirmation_id). The database verifies current ownership/draft. This is a backend candidate; no production owner-consent screen is added or claimed.
2. Registered approver authorizes profile_erasure with confirmation_id and reviewed OTZ ticket. A different registered executor is required. Candidate authorizations expire with the15minute confirmation; retention remains undecided.
3. Close upload admission. Obtain ACTUAL writer-drain evidence under the separate SOP. No evidence → stop/quarantine.
4. planSpecialistErasure calls specialist_operator_plan_erasure. It takes the profile lock, validates scope/approval, materializes stable reservation IDs for valid untracked legacy object paths and returns a plan. It does NOT delete bytes/media or retire reservations, does not mark existing ready media deleting, and works when owner deletion switch is off. Repeated planning retains the same IDs. Unexpected legacy naming requires review.
5. Inspect all IDs and build per-request proof only AFTER planning. Use mode confirmed_erasure and authorization_id; no invented evidence. prepareSpecialistErasure requires the explicit plan, rejects changed inventories and verifies all proofs before retirement. There is no implicit planning hidden in the execution function.
6. Execute audited begin → operator Storage.remove → finish. On partial success, re-inventory/re-plan for the remaining IDs; do not silently discard earlier results. Individual in-progress operations can finish with the same audited proof after authorization expiry; new operations need fresh approval. Keep registry access until approved cleanup finishes, then revoke.
7. For a deleted profile with a late tombstone object, approver issues purpose orphan_cleanup for exactly that request; distinct executor calls cleanupSpecialistOrphan with mode orphan_cleanup and real drain proof. This requires no live owner profile, but does require historical audit and both operator identities. Finish is idempotent and does not reconstruct or publish a profile.
8. Verify inventory and actual Storage absence, then separately perform authorized draft/Auth deletion as applicable. Other company/owned data require their own procedures; no blanket account-erasure claim.

## Pilot phases (not executed)
| Phase | Environment / data | Entry requirement | Success / stop |
| --- | --- | --- | --- |
| P0 current | Local PG17 and disposable full Supabase CI; synthetic accounts | Existing authorization for isolated tests | SQL/RPC/ACL/role separation, quota races, Q2/Q3/Q4, erasure/Auth, browser/company tests PASS |
| P1 hosted envelope | Separately approved disposable hosted project; synthetic data only; no production connection | Explicit project/SHA/SQL/Edge/issuer permission; fresh baseline; independent delta audit; no personal data | Actual5MiB/base64 body, memory/CPU/wall limits, denied/foreign paths, alert delivery, Auth/SMTP/MFA and drain evidence tests; any unknown → stop |
| P2 closed pilot | New private bucket generation; opt-in test specialists; no public publisher | Owner decisions below; proven drain D1–D4; backup and erasure SLA; separate exact deployment/SQL permission | Small fixed opt-in cohort selected by owner; strict20, privacy/erasure/alerts/rollback proven; critical alert disables admission |
| P3 production consideration | Existing main site | Independent audit, separate server and frontend GO, exact approved artifacts/config and verified rollback | Not authorized by this task or this document |

No numerical cohort size, production quota change, paid feature or retention period is silently approved. Owner chooses pilot bounds. Enabling a test page does not prove backend readiness.

## Fresh bucket / cutover options
A. Fresh isolated hosted project and never-before-exposed private bucket with no legacy signed/TUS/service capabilities. Recommended first technical validation, subject to permission; no data copied from staging/production.
B. New generation in an existing project: new bucket identifier/config and scoped issuer would require a separate reviewed code/config delta because current package pins specialist-media and requires it absent at preflight. Do not rename or reuse silently.
C. Existing populated bucket: NO-GO under fresh preflight. Inventory all old capabilities, data, active writers and policies, propose a separately reviewed migration/drain plan. Waiting for signed URLs to expire or deleting/recreating a bucket does not prove all privileged/TUS writers dead.
For any cutover, artifact references must point ONLY to the approved test project. Never use real production tokens/data for previews.

## Deployment checklist for future approval
- Exact branch SHA, canonical SQL/source hashes, immutable frontend/Edge artifacts and known base; main/PR39/company33 unchanged.
- Read-only preflight catalog/definition/ACL/policy/role and bucket snapshot; backup/restore rehearsal without copying personal data into Hub. Existing specialist_operator role or phase replay fails closed, requires review.
- Reviewed fresh baseline order00→05→10→20→StorageAPI create bucket→30→40→50→60→65→66→70. Phase66 creates three FORCE-RLS operator/consent tables, six functions and four narrowly scoped Storage policies (permissive+restrictive read/delete); total33functions/12private tables.33 function definition pins and operator membership/ACL checks compile against PG17. No operator auto-registration or issuer activation.
- Independently provision dedicated operator issuer and real verified Auth subjects outside Edge; register reviewed operators through approved administrative procedure; demonstrate Edge credential denial and operator JWT revocation/registry disable. Local fixture minting is NOT a production issuer implementation.
- Owner confirmation/authorization UI or an approved secure support procedure must be ready before real erasure requests; two-person approval, ticket access and evidence retention reviewed.
- Run70 and owner/foreign/anon/operator/company smoke BEFORE80 enable/frontend. Keep normal writes closed on any drift. Existing80 enables normal upload/delete only; it does not register operators.
- Auth Site URL/redirect allowlist/recovery route and SMTP delivery/confirmation/rate limits checked with synthetic accounts. Gateway currently rejects anonymous users, not unconfirmed email: decide confirmation enforcement separately.
- Rate limits per user/profile/IP and operator misuse; audit/trace sampling, quotas, idempotency, operational on-call ownership.
- Route warnings to ticket queue; route critical orphan/over-quota to immediate on-call escalation and admission freeze. Demonstrate delivery and acknowledgement; aggregate JSON is not delivered monitoring.
- Execute hosted drain SOP with evidence D1–D4; without it P2 is BLOCKED regardless of local test pass.
- No publisher exposure, public contacts, tenant cookies or wildcard-domain changes.

## Required owner decisions (proposals, no implied approval)
| Topic | Options to review | Current state |
| --- | --- | --- |
| Storage model | Strict20+quarantine+trusted writer and verified operator drain; or separately reviewed generation/fencing architecture | Strict existing model preserved; decision pending |
| Bucket/cutover | Fresh disposable project first; new generation with reviewed config; separately reviewed populated-bucket migration | No cutover chosen/applied |
| Auth | Confirm email+SMTP/recovery/rate limits; alternatively explicitly accept current autoconfirm risk for a bounded synthetic-only phase | Real-user pilot blocked |
| Operator trust | Dedicated issuer, two-person registered operators, MFA/revocation, verified subject confirmation/support procedure, provider drain attestation | Isolated mechanism tested; hosted issuer/procedure pending |
| Retention | Define minimum replay-protection and audit/legal retention; pseudonymization and deletion rules after all-writer proof; explicit retention owner | No automatic purge, no lifetime compliance claim |
| Pilot limits | Cohort, duration, data class, stop thresholds, named on-call/erasure SLA | Not approved |
15minute confirmation/authorization windows are proposed candidate security TTLs only; they do not choose audit retention or authorize hosted use.

## Rollback / incident plan
Close admission first. Preserve private read and approved deletion; keep restrictive barriers, reservations, tombstones, FK and audit. UI rollback is one complete prior approved artifact; company routes remain intact. Leave safer phase66 guards and narrow role/policies while data/pending operations exist; do not restore service-role force-retire access to make an old operator script work. Old scripts fail closed and need the new two-phase operator client.

Disable registry identities/revoke operator issuer only after handling authorized in-progress cleanup or appointing a new approved operator. Old JWTs must fail actual RPC/Storage checks. A leaked Edge service key still requires approved key rotation and provider drain; do not treat issuer revocation as cancellation of already admitted remote operations.

No destructive DOWN, DROP/CASCADE, manual Storage metadata deletion or FK bypass is supplied. An empty disposable stack may be destroyed; hosted rollback requires separate reviewed data-state/credential/drain plan and permission. On critical late orphan, quarantine incident, preserve evidence and use scoped Q3 cleanup only after fresh proof; do not claim already deleted personal data is absent until verified.

## Test interpretation
Native SQL fixtures are synthetic Auth/Storage, with actual PG17 transactions and role/RLS checks. Full-stack tests create real local Auth sessions; a LOCAL fixture issuer signs custom operator-role JWTs using only the disposable local signing secret and existing real session. Actual PostgREST and Storage enforce them. No tokens or signing secret are printed. This proves local role/policy behavior, not a deployed hosted issuer, MFA, provider drain or alert delivery.

HTTP failure/response-loss injection is deliberate. Real local Storage API is used for legacy upload, approved operator deletion and post-profile-deletion late orphan cleanup. Any hosted tests remain NOT RUN until separate permission.
