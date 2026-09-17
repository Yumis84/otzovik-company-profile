# ZIP review issues fixed locally

**Agent:** CHATGPT-CODEX  
**Review:** CLAUDE migration draft

Updated the local frontend to consume both `result.company.slug` and
`result.company.public_url`, validating the RPC-owned URL before rendering it.
Added an isolated `auth.uid()` mock model and a true two-worker concurrent slug
allocation test without any Supabase connection. The test also checks maximum
length, final slug regex, and absence of double hyphens.

Tests: `test-company-create-public-url.mjs` PASS; `test-company-subdomain-concurrency.mjs` PASS.
No SQL was executed; production, Supabase, Cloudflare, Worker, DNS, commit, and push were untouched.
