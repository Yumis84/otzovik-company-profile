# Independent migration acceptance — Work2
Exact source: f9dc40d96330de4e6ce5286b10aca752d712e455, tree36ae62d260a5646d812907d432537dfd6194c671. 2026-11-27.

Own detached checkout and SCRAM PostgreSQL17 loopback55491, database staging_clone_work2_f9dc40d. Work1 cluster and hosted environments not touched.

## Verified independently
- All23 SHA256SUMS entries match exact Git bytes. SHA256SUMS hash217c11165a32ecc9a355e881fd338f3d89deedbf79c604138827ba94d6078625.
- Manifest hash6cd3843d5ae6c252c10535e5d2994a1633b3d7ebd19341a79685eccc75d615f0; rollback hashf63f028f28c84d37ded8f85d7ec92b69238d25cba0fdceb48e7aa1ddefcdbbf9.
- Initial scoped catalog preflight and apply10 preserve baseline.
- Rollback after10 restores baseline and preflight.
- NEW intermediate committed10+20 rollback restores baseline row/function hashes and scoped catalog preflight.
- Full10+20+30 application preserves baseline.
- Original membership owner/update/remove/analyst/self/promotion/idempotency/revoked-read SQL contract passes.
- Nonempty-module rollback refuses and leaves probe intact.
- Full rollback restores baseline and preflight.
- 32captured tables,69original function bodies,12specialists,7Storage object metadata rows and1captured invitation preserved. Company/membership/invitation row hashes included. Snapshot predates liveB acceptance.
- Own cluster stopped and generated local password file removed.

Work1 preliminary96d4d50f: coverage,runbook,rollback,scoped fingerprint,full-cycle harness present; private schema must be absent, so original shared-schema ACL is not changed. SQL20 remains byte-identical to previously examined candidate. Existing Auth/Storage internals excluded from scoped fingerprint; do not claim whole-database equivalence.

## Evidence and limitations
Test adds one intermediate branch to an untracked COPY of exact original clone harness; executor sources untouched. Snapshot SHA25633784826470bae3d7c21f0f6800605fee0585b352e273b359acdc3b90862ab41. Auth user rows contain only id,email,email_confirmed_at,is_anonymous; no credentials. No private rows committed. Storage checks concern metadata, not live object-byte download/upload.

Windows checkout initially converted Markdown line endings and checksum verification correctly stopped before SQL. Restoring own checkout exact Git LF bytes made all23 checks pass; not a product defect.

Additional targeted claim crash recovery and exact membership error checks tracked separately. Original broad exception test does not prove all authorization failures have42501: owner_update reports P0001/Owner required, remove reports42501/Verified owner required, self removal22023. Do not infer an access bypass from error-code inconsistency.

B session preserved without auth recheck/export. Actual protected B RPC runner requested Claude EXECUTOR09f5ec2c, no route delivered at checkpoint. No hosted JWT or live revocation PASS claimed. PR53a26a2ed andPR55208fc49 unchanged at remote ref check; no new fixed UI source accepted.

GO only for observed isolated apply/rollback/preservation. Hosted staging release remains NO-GO pending worker crash recovery, independent security verdict, supported liveB runner, actual Storage/public route delivery and fixed UI integration. No hosted apply/deploy/Auth/ACL change authorized by this report.
Targeted result: exact expected SQLSTATE/messages PASS; expired lease remains building after ordinary claim and new enqueue (BLOCKER independently reproduced); explicit private expiry releases it; transaction rollback and baseline preflight PASS. Second own cluster55493 stopped.
