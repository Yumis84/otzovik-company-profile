# Specialist editor: readiness for a synthetic test envelope

Scope: candidate only, no hosted changes, no real users, no production credentials or copied data. Security baseline PR41 and Claude audit 856e1f48. Isolated CI 40654414597 passed; Claude independently reproduced PG16 SQL and concurrent tests. Neither result establishes hosted readiness. A synthetic hosted run, real-user pilot, and production each require distinct explicit approval.

| Gate | Current | Evidence required before separately approved synthetic hosted execution |
| --- | --- | --- |
| Environment and authority | BLOCKED | Owner selects disposable project and approves exact SHA, scripts, credentials, synthetic-only dataset, costs, backup/rollback, named operator and test window. Explicitly identify and exclude production project, production keys and live frontend. Capture redacted project identity and environment provenance. |
| Complete writer inventory | BLOCKED | Enumerate gateway, direct privileged SDK/REST, Storage API, signed URLs, TUS, schedulers, queues, old deployments, keys and all operator backfills. Two reviewers compare inventory against provider configuration and logs; unknown path fails gate. Record generation, owner, capability, request IDs and freeze result; never record secrets. |
| All writers stopped (D1–D4) | BLOCKED | Freeze admission and every inventoried writer; revoke old capabilities only via separately approved plan; enumerate/join all pre-POST executions; obtain provider-authoritative terminal status for every in-flight Storage request and a guarantee that no delayed commit can occur. Attach immutable evidence per path and independent reviewer signoff. Timeouts, quiet logs, expiry, revocation by itself and an empty bucket are not proof. If provider cannot prove completion, retain quarantine and stop. |
| Operator issuer / independence | BLOCKED | Design and independently review dedicated short-lived JWT issuer, registered subject binding, staff separation and MFA, key protection, expiration, rotation and revocation. In disposable environment test issuance, disabled identity, expired/revoked token, foreign path and service-role denial through actual RPC and Storage. Distinct JWT subjects alone do not prove two people; root service_role remains trusted. No production signing key or sample token in artifacts. |
| Lost-login support | NOT IMPLEMENTED | Owner/legal approve identity verification, evidence minimization, independent review, fraud/appeal handling, auditable grant and revocation, retention and deletion. Design and test a separate constrained flow before real-person pilot. Never bypass subject authorization with ad hoc SQL. Synthetic-only scenarios may use synthetic login and must not pretend this gate is closed. |
| Owner decisions | PENDING | Explicit decisions on strict20/quarantine, storage generation/cutover, Auth/SMTP and recovery, audit/tombstone retention and cleanup, operator staffing/MFA, cohort/stop thresholds and cost. 15-minute TTL is a proposal; do not extend automatically. |
| Candidate security and functional acceptance | PARTIAL | Independent review of this delta, native PG16/17 concurrency + replay + expiry and UUID variants, exact artifact hashes, actual isolated Auth/PostgREST/Storage/Edge and browser create/save/reopen. Verify denied cross-profile/company access. Repeat on intended disposable target only after permission. Self-attested proof is not provider evidence. |
| Monitoring / recovery | BLOCKED | Demonstrate critical orphan and stale begin alert delivery/acknowledgement, on-call ownership, stop rule, safe reconciliation, fresh authorization/proof, re-inventory, rollback and cleanup. No automatic expiry-based release, manual Storage metadata delete, FK bypass, or silent data destruction. |

## Evidence worksheet (blank template, not evidence)

- Run ID, reviewer, approved scope and expiry; project identity and exact repository/SQL/artifact SHA.
- Per writer: entrypoint, owner, credential generation fingerprint, freeze state, all execution IDs and provider terminal references; unknowns and reviewer decision.
- Per operator: identity binding, MFA and issuer/revocation test result, independent approver/executor, no secrets.
- Synthetic fixture IDs and namespace, exact checks/results, failure injection, cleanup verification, timestamps and immutable references.
- Go/no-go and signoff for each gate, explicit residual unknowns and rollback owner. Any missing evidence means NO-GO. No claims about production.

## Safe local run

Use the existing `.github/workflows/specialist-gateway.yml` disposable CI and `tests/prepare-gateway-stack.mjs` / `tests/local-stack.mjs`; the latter refuses non-local targets. SQL fixtures `tests/specialist-pilot-hardening.mjs` and `tests/specialist-gateway-sql.mjs` accept only loopback database `otzovik_acceptance`. Use throwaway synthetic accounts; no hosted URLs, credentials or real personal data. Inspect test target safeguards before running; keep the database disposable. CI exercises real local Auth/PostgREST/Storage/Edge and reports its own limits. A synthetic run is not provider drain evidence or permission to deploy.
