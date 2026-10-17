# PR20: specialist integration acceptance and rollout

Date: 2026-10-17. Branch: `feature/specialist-main-integration-v1`.
Baseline: `beb2e139914288f4ef2d6e591adfe503c7de4d99`; main: `68d3f94c928394187c92eeb623c9697e34d75ed5`.

## Findings and fixes

The previous CI run 38995392548 passed PostgreSQL but failed browser login: an authenticated specialist-only account was redirected to company creation. Login now sends authenticated users to the requested safe cabinet route or home. Registration confirmation defaults to profile selection and preserves an allowed `next` route. Auth failures release the busy state and permit retry.

Dashboard loads invitations, companies and specialists independently, including rejected network promises. A failed company/invitation request no longer hides specialists. Draft cards clearly identify private status and work on mobile. Company slug input now matches the 63-character database bound.

Company profile, branches, services, media, access, company-context and mobile-swipe implementations are unchanged from main. Tests now load their real JS modules. The current company edit RPC is captured as an isolated test fixture, not a production migration.

## Acceptance matrix

| Check | Result / evidence |
|---|---|
| Specialist create/list/edit/reload, field bounds | PASS: isolated SQL and browser |
| Registration confirmation route, immediate signup, login, empty account | PASS: browser Auth adapter; hosted email/Auth not exercised |
| Specialist-only and mixed company/specialist account | PASS: browser with actual isolated data RPCs |
| Company create and edit/readback | PASS: production-baseline RPC definitions executed in isolated SQL |
| Foreign/anonymous user, revoked company member | PASS: SQL denial and browser closed edit state |
| RLS, table grants, EXECUTE, helper isolation, draft-only status | PASS: SQL; trusted BYPASSRLS definer required, empty search_path |
| Company/specialist shared address and retry | PASS: SQL registry and browser; overlapping transactions run on PostgreSQL in CI |
| Double submit/repeated edits | PASS: one create request, stable row count after repeated updates |
| RPC failures, thrown network errors, failed edit load | PASS: visible errors, retry, disabled unloaded form |
| Mobile 390px layout and company navigation | PASS: browser |
| Branch/service creation, photo upload, owner access UI | PASS: unchanged main UI with scoped contract adapters; Storage and subsystem backends simulated |
| Local SQL | PASS: 13 groups; 2 concurrency groups skipped by PGlite, required in CI PostgreSQL |
| Local Playwright | PASS: 12 groups, no page errors; external requests blocked |
| Hosted Auth/PostgREST/Storage and production smoke | NOT RUN: requires approved isolated staging or release smoke |

GitHub Actions is the release gate for the final commit: PostgreSQL 16 runs real overlapping transactions, then Playwright. Check the PR's latest successful run, not an older SHA. Browser SQL uses PGlite; Auth, email delivery, Storage and unchanged subsidiary company RPCs use test adapters. This is not a claim of full hosted end-to-end coverage.

## Read-only production preflight

No production changes were made. Specialist/registry tables are absent. On this date the live company create/read definitions exactly matched `tests/fixtures/company-rpcs-before.sql`:

- create_my_company: MD5 `98d71841e7941b405231e6ed98949331`.
- get_my_companies: MD5 `0d7f2edb1535c0f50bde7a0cf65be389`.
- Seven-argument update_my_company_profile: MD5 `e380e23d4deb6b4ea7894e3bfa2e386a`, captured in `tests/fixtures/company-edit-before.sql`.
- Company RPC owners are postgres/BYPASSRLS; public/anon cannot execute the create/read RPCs.
- Membership aggregate: 7 verified owners, 2 verified admins, no unverified memberships. The candidate's verified-only list filter currently excludes none; repeat this check at deployment time.

## Safe rollout (requires separate authorization)

1. Keep PR draft until final-SHA CI is green. Recheck current main and production function definitions/membership states immediately before release; investigate drift rather than replacing newer RPCs.
2. Create/verify a recoverable database backup and export current function definitions and grants. Use an isolated Supabase staging project with the same baseline. Do not test against production users' records.
3. Generate one transaction: `node scripts/specialist-migration.mjs > /tmp/specialist-migration.sql`. It combines only the two 20261017 candidates. Do not apply legacy `20261016_profile_kind_v1_CANDIDATE.sql` or test fixtures.
4. Review the generated SQL, collision preflight and lock timeout. Apply to staging as the trusted database owner. Run role/ownership tests with two real authenticated users, signup confirmation, RPC routing/schema cache, and actual company Storage/branch/service/access smoke. Verify drafts never enter the public publisher.
5. After explicit approval, apply the same transaction to production during a controlled window. Any preflight error, slug collision, drift or lock timeout means rollback/stop; do not weaken guards. Verify table/RPC grants and private draft behavior before frontend release. Refresh PostgREST schema cache if required and verify the new RPCs resolve.
6. After separate merge/release approval, deploy the reviewed frontend. The existing Pages workflow deploys on main and uploads repository root; review the deployment artifact policy before merging. This task did not modify deployment configuration or trigger a production release.
7. Run authorized smoke with dedicated accounts: registration → login → chooser → save → home → edit → reload; mixed/empty accounts; foreign-user denial; existing company edit, branches/services/photos/access. Confirm no public draft URL/publisher event. Monitor RPC errors and address conflicts.

## Rollback without deleting data

Before deployment preserve the previous frontend artifact and SQL/grant snapshot. On failure, disable specialist entry points by restoring the previous frontend. If needed revoke EXECUTE on the three specialist RPC signatures from authenticated (and any explicitly granted application roles), retaining all saved drafts. Keep the shared slug registry and company collision protection while specialist records exist; dropping them would reintroduce cross-type collisions. Do not drop tables, delete drafts, or blindly restore old company RPCs. Any database rollback is separately reviewed and approved against the current state. Re-enable only after correcting the cause and rerunning CI/staging checks.

## Remaining gates

Final-SHA CI, staging hosted Auth/PostgREST/Storage smoke, deployment artifact review, and explicit production migration/merge/release authorization. No production SQL, main merge, DNS/Worker changes, data removal or draft publication is authorized by this report.
