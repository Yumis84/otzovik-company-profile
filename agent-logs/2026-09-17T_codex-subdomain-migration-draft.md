# Atomic company subdomain migration draft

**Agent:** CODEX  
**Mode:** local draft-only

Prepared `otzovik-company-subdomain-atomic-migration.sql` using the verified
`companies` schema and existing membership/audit tables. The draft rejects
reserved labels, retries `companies_slug_key` collisions with `-2`, `-3`, etc.,
and returns/calculates `company.public_url` as the ASCII IDN URL.

Structural test: `node test-company-subdomain-migration.mjs` — PASS.
The SQL was not executed; no Supabase, Cloudflare, Worker, DNS, production,
commit, or push changes were made.
