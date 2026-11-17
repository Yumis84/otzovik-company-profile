# Publication replay and PG17 safety — review only

Baseline PR #50 cff300dd32683a371d8f4968091ec3743ce4646c. This is a proposal, not an approved publication contract. SQL is not executed by these files.

| Scenario | A: signed token + generation | B: server generation + bounded ledger | C: single-use server-issued operation record |
| --- | --- | --- | --- |
| Old replay after unpublish or newer publication | Reject mismatched generation, even if token valid | Reject mismatched generation; generation checked before any new mutation | Reject consumed/invalidated operation; retain generation on profile |
| After TTL / pruning | Reject expired signature; do not accept UUID as new | Requires trusted expiry or tombstone for old keys; generation alone does not distinguish old IDs within the same generation | Reject if operation absent or expired; never implicitly create it on execute |
| Lost response | Retry identical token inside expiry, return recorded result | Retry same ID inside retention; expiry requires explicit new consent | Fetch existing operation status or retry same operation; expiry requires explicit new consent |
| Concurrent requests / cap | Lock profile/generation, enforce quotas and return prior outcome for replay | Same; rate-limit new intents only; preserve replay window | Atomic issue/consume/status under same profile lock; limits on issue |
| Recovery / keys | Expired ledger can be removed once all signatures expired plus in-flight/clock grace; key rotation/revocation and restore required | With trustworthy expired-ID rejection, bounded retention permits cleanup; otherwise preserve ledger | Cleanup expired records; missing IDs fail closed. Requires an issuer endpoint but no signing key |

Recommendation to owner: evaluate C first if an existing authenticated server/DB operation-issuance path can be reused; missing/expired operation must remain a hard refusal. It needs an explicitly approved contract change and independent security review; it is not implemented. Compare the operational burden of A's key lifecycle against C's additional authoritative database state; B alone is insufficient unless it can reject expired IDs without relying on an untrusted client clock. For all choices check backup restore, rollback of generations/operation records, replay from other clients and unpublish/erasure races. P1-2 access rights and P1-5 retention/legal are separate owner decisions.

## PG17 readiness and remaining work

`disposable-pg17-guard.mjs` validates a narrow loopback configuration before any connection. Environment variables are not independent proof: the runner must prove fresh hosted VM, empty Docker context, locally-created new Supabase, no production/hosted credentials, container/port ownership and synthetic fixture marker; abort if any check fails. After connecting, verify server version 17, fixture identity, distinct connection backend PIDs and synthetic users. Test-only stack setup must not point to existing DBs. Always destroy only its own stack.

`pg17-concurrency-primitives.mjs` supplies blocking-relation observation and teardown helpers; **it is not a T1–T7 harness**. No SQL integration tests are claimed. Implement and run T1 disable/publish; T2 same ID; T3 cap race; T4 rename/unpublish; T5 suspend/erase/delete; T6 third-connection disable latency; T7 suspended/erasing replay, as specified in `SPECIALIST_811E688E_PG17_REVIEW.md`. Use explicit barriers, bounded timeouts, assert postconditions, rollback and independent clients. Current review candidate lacks runtime lock timeouts; T6 must record its actual latency/failure, never assume success.

## ACL / timeout REVIEW CANDIDATE specification

Before replacement in a single transaction require `to_regprocedure` for exact signatures, validate expected function owner, baseline definition hash and privileges; snapshot OID, owner and proacl and effective EXECUTE for anon/authenticated/service_role (including inherited and PUBLIC grants); compare after replacement and rollback on any difference. Explicitly exercise missing function, altered ACL, inherited unexpected EXECUTE and altered owner. Never add GRANT/REVOKE to the candidate. Add function-level lock_timeout to publish and emergency disable only after proving lock order and choosing reviewed configuration; ensure audit and failure handling do not silently treat timeout as disable success. Actual SQL patch and ACL tests are not yet implemented.
