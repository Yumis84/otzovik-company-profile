# Atomic operator model and CI trust — synthetic preparation only

Basis PR45 `400d16123ec9e09e5db2d425a9742f59231ff291`, REQUEST 6fd9ea36, Claude 6a2046ac. This is not a hosted issuer, real MFA, user authorization, Storage/RPC integration or permission to delete. SQL under `tests/fixtures` is a disposable-only model, not a migration or release candidate. No real identities or secrets.

## Atomic model

- Ed25519 synthetic tokens bind sub, jti, exact operation (`plan_erasure`, `cleanup_orphan`, `authorize`), target, nonce, epoch, issued/expiry with lifetime at most 60 seconds. They cannot authorize a real operation.
- In one PostgreSQL transaction the subject row is locked, active/epoch and token revocation checked, a unique jti consumed, and a synthetic action plus audit recorded. Concurrent replay must have one winner. Epoch increments on disable, re-register, MFA change and revoke-all. Re-registration retains identity and monotonic epoch. Missing or unavailable store fails closed.
- Expected synthetic action failure uses a savepoint: its action insert rolls back, while the jti consumption and rejection audit commit together; replay requires a new token. A transport failure or loss of the entire transaction has an **unknown outcome**; this fixture does not provide durable recovery or external quarantine. Never assume a retry is safe, and do not treat this model as meeting a real-world crash-recovery gate.
- Token revoke accepts the matching synthetic subject or synthetic admin, but the caller identity is injected by the test harness. Real authentication of callers and admin authority is NOT IMPLEMENTED.
- Lost-login case rejects subject=requester. Each approval validates a signed synthetic MFA assertion with current epoch and locks an active registered reviewer. Reviewer, subject and requester identity records must be distinct; two approvals are required; audit records reviewer and MFA time without case reference/PII. Completion always returns `grantsAccess=false`. Synthetic identity records do not prove two independent people. No real evidence, legal policy, account access, deletion or approval grant exists.
- Neither model nor worksheet can issue provider drain proof or permit deletion. `worksheetFieldsPresent` means only fields exist, not a verified drain.

## Independent required CI trust root — proposed, NOT installed

1. Host a separately administered reusable workflow and verifier outside the PR repository, pin its full commit SHA, and retain the expected baseline/policy in that trusted repository or a protected organization variable. PR44/45 are reference seeds only, not independently approved roots.
2. The trusted job checks out the untrusted PR as data with no privileged secrets, validates paths/hashes before running any PR-controlled code, and reports a required status. Avoid executing head code in a privileged `pull_request_target` context. Sign or separately review updates to the baseline and protected-path policy.
3. Protect original guard and tests, candidate guard and workflow, all `.github/workflows/**`, package and lock files, `scripts/pages-files.json`, all public artifact paths, operator/gateway SQL, company files, CODEOWNERS and the policy itself. Include additions/deletions, renames, symlinks and case differences. The synthetic detector checks PR45 pages-manifest paths, PR45 workflows and specified guard/package files, plus local snapshots of its own script and new workflow. It cannot stop coordinated self-modification, protect future unknown paths, or replace a trustworthy external check.
4. Owner-controlled CODEOWNERS, required review, required independent status, and any admin bypass decision need explicit consent. Test red results for guard, policy, workflow, manifest, package, public paths and CODEOWNERS in a disposable fork before relying on them. Repository admins and trusted-workflow maintainers remain trusted actors. No ruleset, ACL or external workflow is changed here.

## Owner decisions — blank worksheet

| Question | Options or required details | Decision |
| --- | --- | --- |
| Hosted target | Separate disposable project, exact SHA, budget, owner, lifetime, synthetic data, backup/rollback | NOT CHOSEN |
| Model | strict20/quarantine, alternative architecture, bucket generation and cutover | NOT DECIDED |
| Auth | identity provider, MFA, operator separation, issuer, revocation and recovery | NOT DECIDED |
| Retention and rate | audit, tombstones, confirmations, erasure records, rate limits and legal basis | NOT DECIDED |
| Cohort / TTL | synthetic-only scope, alert thresholds, 15-minute candidate TTL, on-call | NOT DECIDED |
| Trust root | independently administered repo/workflow SHA, reviewers, required check, admin bypass | NOT DECIDED |

Hosted synthetic, real-user pilot and production remain NO-GO until independently verified writer drain, real issuer/MFA/revocation, support verification, monitoring, independent CI control, owner decisions and explicit target-specific approval. Tests in this branch cannot close those gates.
