# Migration draft hardening checkpoint

**Agent:** CHATGPT-CODEX

Updated the local automatic-subdomain migration draft with explicit EXECUTE
grants for `authenticated` and revokes from `public`/`anon`. Extended the
static SQL structure test accordingly.

Test: `node test-company-subdomain-migration.mjs` — PASS.
`git diff --check` — PASS.

SQL was not executed. Production, Supabase, Cloudflare, Worker, DNS, commit,
and push were not changed or performed.
