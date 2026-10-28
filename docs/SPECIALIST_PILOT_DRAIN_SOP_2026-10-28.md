# Hosted writer-drain SOP — 2026-10-28
REQUEST cbb5c7ca / Claude audit1e239ab7. Proposal only; **BLOCKED / NOT EXECUTED** on hosted infrastructure.

## Current conclusion
The available project evidence and public Supabase APIs/documentation do not establish an authoritative inventory, cancellation and join primitive for EVERY already admitted Edge/Storage writer. No hosted provider terminal trace, revocation result, worker join ledger or all-writers-stopped attestation has been obtained. Therefore the executable step “retire unknown reservation” is BLOCKED on hosted. Keep quarantine and its FK. Do not infer that the platform has no such facility; obtain a documented provider guarantee and demonstrate it in an approved disposable hosted project.

A25s AbortSignal, Edge wall-clock maximum, deployment replacement, logs with no recent entries, an empty Storage listing, absence of a DB transaction, credential rotation by itself, or a boolean in JSON is NOT proof. An Edge execution may have reserved but not yet issued its one POST; a remote Storage request may commit after the caller stops waiting. SQL locks do not fence a privileged remote Storage writer.

## Preconditions / evidence record
Two distinct registered operators; an authenticated subject request for live profile erasure; an independent authorization ticket. Use request_id, profile_id, exact sealed object name, deployment generation, key-generation fingerprint (never the credential), correlated provider request IDs and terminal states. Record approver/executor identities from verified JWTs; SQL rejects Edge service credentials. Store evidence_ref pointing to an immutable restricted incident record. Do not include keys, JWTs, personal contacts, images or raw Auth exports in Hub.

The authorization/owner-confirmation15minute expiry in this SQL candidate is a proposed security control, not a retention decision or permission to roll out. Authorized in-progress finish can resume from its audited begin; expiry does not authorize new work. Lost/expired authorizations require renewed verification, never hand-editing audit.

## Gates, in order
| Gate | Required action and verifiable evidence | Stop condition / present result |
| --- | --- | --- |
| D0 owner permission | Explicit permission identifying disposable hosted project, candidate SHA/SQL hashes, test accounts, exact writes and rollback. Separate later pilot permission. | No permission for hosted execution in current task; NOT EXECUTED |
| D1 freeze | Close new upload admission; close every producer/ingress, scheduler, background path, legacy writer, signed/TUS capability and operator backfill. Retain deletion/read and SQL barriers. Snapshot active reservations and correlated execution IDs before and after freeze. | Any unidentified producer/capability → BLOCKED |
| D2 fence credentials | Through an approved key-type-specific process revoke ALL credentials/capabilities usable by old writers, not merely issue a new key. Verify old key rejection with nonwriting authorization probes and provider evidence. Assess legacy JWT impact on Auth/company before touching it. | A negative probe at one instant does not cancel requests already admitted; proceed only with D3/D4 |
| D3 close pre-POST executions | Enumerate all gateway executions that could have reserved a slot; join/terminate them with an authoritative platform guarantee they cannot resume and send POST. Include background work. Correlate each to one reservation. | No complete execution ledger or missing join/termination guarantee → BLOCKED |
| D4 remote commit drain | For EVERY possible Storage POST obtain provider-authoritative completed/aborted status and guarantee no later commit. Account for proxies, queues, retries and in-flight requests that predate revocation. A timeout or absence query cannot substitute. | Current interfaces/evidence do not prove this; **BLOCKED** |
| D5 reconciliation | Only after D1–D4, inspect actual metadata and Storage API results for each sealed path. Match SQL state, file size/MIME and provider terminal result. Resolve observed object through finish/recover or reviewed erasure. | A new/late object or unexplained mismatch invalidates the proof; restart investigation |
| D6 scoped authorization | Approver creates profile_erasure authorization bound to a live owner confirmation, or orphan_cleanup authorization bound to an audited deleted-profile tombstone. Another registered operator executes. Proof kind reflects ACTUAL D3/D4 evidence, not elapsed time. | Missing consent, second identity, scope or credible evidence → no begin |
| D7 deletion | Audited begin → narrowly authorized Storage API remove → SQL finish checks absence → re-inventory. Never SQL-delete storage.objects; never drop FK or audit. | Storage/API error retains data/FK; retry safely, renew plan when inventory changes |
| D8 completion | Verify actual objects absent and no potential writer, account/profile outcome, audit identities, alert state. For a whole account, separately verify company and all other owned data before Auth hard-delete. | No claim of completed erasure with residual/unknown work |
| D9 reopen | Separate operator/owner review: issuer/registry/policies/canaries, backup status, no unknown writers, no critical alerts; reopen admission only with explicit permission. | No automatic enable after cleanup |

## Acceptable evidence routes (both currently unverified)
A. Provider supplies authoritative terminal request traces plus complete execution enumeration/join guarantees. Prove every request_id covered and no pre-POST execution can resume.
B. Revoke the old writer capability, prove all existing remote operations drained and all pre-POST executions joined/terminated. New trusted generation must not reuse old request IDs. Revocation alone fails D4.

Do not weaken strict20 or replace it with “bounded overshoot” without an owner decision. Deliberately injected privileged late writes in tests represent a violated trust assumption: they are observable and now have an audited post-deletion cleanup path, but the test does not prove prevention of arbitrary privileged writes.

## What can be done without hosted writes
Review candidate SQL/ACL and public docs; inspect already approved read-only technical configuration without secrets; obtain provider support statement; prepare evidence templates and test cases; run local/disposable CI. None of these by itself produces a hosted all-writers-stopped proof. No permission is requested to apply the candidates as part of this document.

## References and their limits
- https://supabase.com/docs/guides/functions/limits — worker/request limits; not a promise cancelling remote Storage commits.
- https://supabase.com/docs/guides/functions/background-tasks — background work exists; handler completion is not universally equivalent to all background work joined.
- https://supabase.com/docs/guides/functions/logging — logs aid investigation, not a global atomic drain barrier.
- https://supabase.com/docs/guides/auth/jwts — privileged role claims require a trusted issuer; a service JWT is not a custom operator JWT.
- https://supabase.com/docs/guides/storage/debugging/error-codes — terminal-response contract is version-dependent; proxy/WAF replies and legacy embedded status need separate validation.
No private project credential or hosted configuration was fetched/changed to manufacture proof.
