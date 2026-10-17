# PR20: isolated Supabase staging acceptance

Status: PREPARATION ONLY. No hosted environment has been created; hosted Auth/PostgREST/Storage tests remain NOT RUN.

## Hard boundaries
- Never use production Supabase `rzhlcszqtuhkhfibygnk`, the museum project, or production personal data as a test target.
- No new paid resources, project creation, hosted migrations, production SQL, merge, DNS or release without explicit owner authorization.
- Branching attempt returned `PaymentRequiredException`; do not retry with paid upgrades automatically.
- Local PGlite/PostgreSQL tests are not hosted Supabase Auth/PostgREST/Storage tests.

## Environment choice
1. Prefer a new disposable Supabase project, after cost quotation and owner approval. Use only synthetic users and fresh credentials.
2. Alternatively rehearse with local Supabase CLI; label the result LOCAL and keep hosted acceptance as NOT RUN.
3. Record target project ID, region, version, cost approval, date and PR SHA. Never commit credentials.

## Offline preparation
- Verify GitHub Actions PASS on the exact candidate SHA.
- In an isolated checkout run `npm ci`, `npm test`, `npm run build:pages`, `npm run test:pages`, `npm run test:browser`.
- Generate SQL **without connecting to any database**: `node scripts/specialist-migration.mjs > specialist-staging.sql`.
- Inspect the SQL. It must combine only the two 20261017 specialist candidate migrations as one transaction, without legacy profile_kind SQL or test fixtures.
- A fresh Supabase project is not automatically compatible: establish the required company schema/RPC baseline with synthetic data; never import production personal data.
- Check trusted function owner, BYPASSRLS, FORCE RLS, REVOKE, EXECUTE and trigger permissions before migration.

## Two-user acceptance (record PASS / FAIL / NOT RUN for each)
1. Synthetic users A and B: sign-up, email confirmation, login, logout and safe redirect.
2. A: create draft, list it, edit, reload persisted values, immutable slug.
3. B and anonymous: cannot read/list/update A's draft via UI **or direct API**.
4. Protected RPC EXECUTE denied to anon; owner-only operations verified with real hosted JWT sessions.
5. Specialist/company slug collision and concurrent claims behave safely.
6. Existing company create, verified membership, edit and revoked-user denial remain correct.
7. Real Storage smoke for supported existing company photo flows.
8. Mobile cabinet, error recovery, private draft status and no public specialist draft route.
9. Pages artifact `_site` contains public files only; no sql/, docs/, tests/, scripts/, agent-logs/ or .github/.

Record sanitized evidence, SHA and precise test environment. Do not store passwords, tokens or real user details.

## Stop and recovery
- Any cross-user read, broken company RPC, unsafe slug collision, function-owner mismatch or leaked public file means NO-GO.
- Remove disposable staging only with authorization.
- Production rollback must be reviewed separately, preserve user drafts/registry and restore captured company RPC baselines. Do not use ad-hoc DROP statements.

## Release gate
Independent Claude security PASS, isolated hosted acceptance PASS (or separately documented explicit owner risk decision), final-SHA CI PASS, and **separate explicit owner approval** for production migration, merge and release. Until then: NO-GO production.
