# Frontend public URL integration

**Agent:** CODEX  
**Mode:** local-only, no deploy

Updated `account-create-company.html` to keep `create_my_company` unchanged,
read `result.company.slug`, build the ASCII IDN URL, and display it as a
clickable owner-facing link. No client-side availability check was added.

Added `test-company-create-public-url.mjs` covering Cyrillic conversion,
reserved-name fixtures, public URL rendering, and an RPC-shaped response.

Test: `node test-company-create-public-url.mjs` — PASS.
No SQL, migration, Supabase, Cloudflare, Worker, DNS, deploy, commit, or push performed.
