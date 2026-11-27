# Company publication integration candidate — 2026-11-27

Disposable/staging review package. No automatic migration, production deployment, main merge or scheduled worker is configured.

This preserves the queue/readability/source work recorded in Hub 206ff892 and completes the native DTO, artifact proof, finalization and artifact reader. `publisher-candidate.sql` retains the historical package ordering from 5767a377; its final definitions are hardened by `completeness.sql` and `complete-final.sql`.

## Contract and order

On a fresh isolated database only: `readability.sql`, `reputation.sql`, `dto.sql`, `sources-gate.sql`, then `content-dto.sql`, `publisher-candidate.sql`, `completeness.sql`, `complete-final.sql`, `owner-api.sql`, `artifact-reader.sql`. The first files create prerequisites and deliberately fail if those objects already exist. They are **not** a migration for an existing hosted project. A hosted delta must be prepared against its actual catalog and independently audited first. `content-dto.sql` requires the existing canonical native review and Q&A readers; it never substitutes synthetic empty data for an absent subsystem.

- Authenticated verified owner: `request_my_company_publication(company_id, request_id)`. Repeated/coalesced request keys remain durable. Other members cannot enqueue.
- Verified member: `get_my_company_publication_status(company_id)`. Foreign/anonymous callers denied. A changed snapshot loses its published confirmation.
- Trusted worker only: claim, heartbeat, expire, proof registration, finalization, artifact resolution. No client table access, private schema access or worker grants are added.
- Artifact reader checks current readability, requester authority, slug/tenant, current snapshot and proof. Changes/erasure invalidate stale artifacts. File readback detects missing/changed files before serving. The loopback acceptance route returns 404 for unavailable profiles and 503 for corrupted artifacts, with no-store/nosniff/noindex.

Generator companion: Yumis84/otzovik-public-profiles branch `work1/company-publisher-completion-20261127`. Its worker accepts only loopback PostgreSQL, and its Storage exporter only the fixed staging origin. It is an integration/acceptance harness, not a production service. No external runner or host is activated. Media network transport is independently injectable for tests; integration tests decode/reencode actual synthetic image bytes, not live hosted Storage.

## Validation

Use a disposable PG17 cluster with anon/authenticated/service_role roles and Python/Pillow. `tests/company-publication-integrated.py` creates new databases and installs synthetic fixture schemas plus the exact read-only captured canonical native readers. It never contacts hosted PostgreSQL. Set `--sql-root sql/candidates/company-publication --generator-root <public-profiles>/scripts --psql <path> --database <new_name>`; port 55487 is loopback only. No Auth JWT claim is made: role/identity checks use actual DB roles and a fixture auth.uid implementation.

Coverage: native reviews/rating/Q&A, draft and foreign isolation, role API grants/denials, concurrent enqueue, actual renderer and verified artifacts, changed files, revoked requester, stale snapshot, expired lease, suspension, sanitized photo, actual HTTP HTML/media, erase invalidation, nonempty rollback refusal, and empty rollback preserving two original synthetic companies. Generator-specific tests also cover scale 10, unknown vs zero counts, canonical author/response/program fields, metadata stripping and foreign/traversal/corrupt images.

`publisher-rollback.sql` removes only an empty publisher module, without CASCADE. After history exists it refuses; retain data and prepare a separately reviewed operational rollback. Native source/readability data and canonical readers are deliberately preserved. Reuse earlier successful specialist tests; these changes do not edit protected UI/guards.

Remaining release gates: independent final SQL/worker review; exact hosted catalog/preflight and reviewed migration; hosted worker/storage/JWT integration; Work2 real A/B browser acceptance. Production remains NO-GO.
