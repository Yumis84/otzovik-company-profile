# Real local Supabase acceptance

This suite runs a disposable **local** Supabase stack on a GitHub-hosted Linux runner. It creates no hosted Supabase project, does not link the CLI to production, uses synthetic users and needs no production secrets. The workflow has only `contents: read`. No paid branching or subscription upgrade is involved.

## Reproduce on a Docker-capable machine

Use an isolated checkout with Node 24 and Docker. The fixed `/tmp/otzovik-supabase` workspace and ports 54321/54322/54324 must be unused.

```sh
npm ci
node tests/prepare-local-stack.mjs
npx supabase start --workdir /tmp/otzovik-supabase -x studio,realtime,edge-runtime,logflare,vector,supavisor
npx supabase status --workdir /tmp/otzovik-supabase -o json > /tmp/otzovik-local-status.json
npx playwright install --with-deps chromium
node tests/local-stack.mjs
npx supabase stop --workdir /tmp/otzovik-supabase --no-backup
```

The test refuses non-loopback API/database hosts, nonstandard test ports, and a database already containing companies. It uses the real Auth schema, `auth.uid()`, roles and JWTs; the unit-test Auth fixture is not installed. Never modify the guards to point this harness at a hosted database. The status file contains only local disposable credentials; do not upload it or print it in CI logs. CI stops the stack with `always()`.

## Scope and provenance

- CLI pinned at 2.121.0; local PostgreSQL 17, GoTrue/Auth, Mailpit, PostgREST and Storage are actual services.
- Signup requires email confirmation. Mailpit receives real local SMTP messages; confirming the link and password login use GoTrue.
- Browser uses the real bundled Supabase JS SDK 2.115.0. No test Auth/RPC/Storage adapters are used. Only the frontend's embedded production URL/publishable key are replaced in the served test copy, and its CDN SDK is supplied locally. Requests to production/external sites are blocked. The repository's deployable pages retain their production configuration.
- Company create/read/edit functions come from the existing reviewed fixtures. `company-stack-snapshot.json` is a read-only 2026-10-17 snapshot of branch/service/media columns, constraints, functions, media policies, membership self-read policy and private Storage policies. It contains no production rows, JWTs or secrets.
- Subsidiary RPC execution is explicitly granted to authenticated and denied to anonymous in the harness. This validates their authorization behavior, not a complete dump of all production ACLs.
- The production external publisher is deliberately replaced by the existing SQL event sentinel. No public profile is exported. No real invitation is sent.

## Required assertions

1. Two confirmed users, actual signup/login and email-link routing.
2. Specialist create/edit/read persists with real JWT over PostgREST; repeated edits do not duplicate rows.
3. Foreign user and anon cannot read/write drafts or the slug registry directly. Direct table denials must have SQLSTATE 42501, not an unrelated missing-table error.
4. Company create/edit, address conflict and simultaneous specialist creation.
5. Actual company location/service RPCs: create, list, archive/publish and foreign denial.
6. Actual private Storage: upload, register media, signed download with byte comparison, foreign write denial and private object anonymous denial.
7. Pending/revoked membership hides the company and denies edit/service/photo writes while preserving the user's specialist draft.
8. Mobile browser: login, chooser, specialist create, edit, reload, logout/relogin and foreign edit denial.
9. Browser company profile/branch/service/photo flows against real local services.
10. Draft publication sentinel and non-destructive RPC-disable rollback.

A passing local suite closes the LOCAL integration gate. Hosted email deliverability, hosted gateway configuration, CDN/Worker and external publishing remain **NOT RUN**. No result authorizes production SQL, main merge or deployment. The ephemeral CI stack is not a persistent public preview URL.
