# Work1 final candidate validation — 2026-11-27

Scope: existing staging logical clone, PostgreSQL 17.11, loopback only. Hosted staging was not modified. Auth credentials were excluded; JWT claims were simulated inside isolated SQL transactions, not obtained from live sessions.

Final rehearsal database: `staging_clone_final_v3`. Harness process exit 0.

- PASS captured catalog preflight before application.
- PASS 10 canonical missing-module application preserves all original rows and 69 captured function bodies.
- PASS rollback after committed 10, then original catalog preflight and data hashes match.
- PASS reapply 10 + apply 20 + 30, original data/function hashes match (new private artifact bucket excluded from original bucket comparison only).
- PASS canonical owner role update/delete, analyst rejection, no owner self-removal/promotion, idempotent remove, revoked-member content denial. Test writes roll back.
- PASS rollback refuses nonempty new module and preserves probe transactionally.
- PASS full 10/20/30 rollback without CASCADE. Original catalog preflight and all baseline row/function hashes match afterward.
- Preserved 32 captured tables (including auxiliary Storage), 7 Storage object metadata rows, 12 specialists, 1 captured invitation. Snapshot predates accepted B membership; never substitute it for current live history.
- PASS SHA256SUMS, deterministic regeneration, git diff whitespace check.
- PASS gateway unit transport/hash/rejection tests. Mocked network and actual response-byte hashing; not actual hosted Storage delivery.

Previous-session evidence d538abd2/b65c760c, unchanged forward SQL: canonical source/rating/review/Q&A/response, DTO/queue, foreign isolation/RLS and metadata delivery/failure tests passed on isolated staging clone. These are attributed prior results, not repeated here. Preserved tests/staging-company-delivery.sql from previous uncommitted work.

Work2 preliminary 96d4d50f addressed: 20/30 and every package file covered in manifest/checksums; rollback/runbook included; pinned scoped catalog fingerprint included; full-cycle harness covers 20/30; private schema must be absent so existing schema ACL is never changed. Status URL remains fail-closed until a separately approved delivery-ready deployment.

Limits: no live JWT A/B denial/revocation, no hosted Storage upload/readback, no live public route, no Work2/CRITIC final verdict. Specialist compatibility evidence is preserved data/catalog/function definitions, not a new hosted UI E2E. Rollback blocks post-use data deletion and requires export/reconciliation. Partial 10 rollback and full 10/20/30 rollback were exercised; intermediate 10+20 path is supported by conditional drops but has not been separately exercised.

Verdict: ready for independent exact-commit review; hosted deployment NO-GO pending independent acceptance, fresh backups/preflight and separate owner authorization. Missing deployed owner RPC still blocks authorized B revocation; this candidate does not deploy it automatically.
