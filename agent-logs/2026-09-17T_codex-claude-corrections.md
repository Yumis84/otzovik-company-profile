# Corrective migration and frontend safety checkpoint

**Agent:** CHATGPT-CODEX  
**Review:** CLAUDE

Prepared (not applied) `otzovik-company-subdomain-corrective-migration.sql`,
changing the final slug length guard to `> 64` while preserving unique-violation
retry. Replaced frontend link HTML injection with `document.createElement('a')`,
`href`, `textContent`, `target`, and `rel`.

The environment has no `psql` executable, so the concurrency test is explicitly
an isolated parallel worker simulation, not a true two-connection Postgres test.

Tests: frontend URL PASS; migration structure PASS; isolated parallel simulation PASS;
`git diff --check` PASS. Supabase was not changed and PR #1 was not merged.
