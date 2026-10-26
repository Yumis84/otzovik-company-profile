# Stage B — specialist service pricing

REQUEST 19d3c2a9-d512-4360-98ad-621201152b50; base PR35 18b974d1aac3aa1bb4030308f53fd91184653256.
Status: implemented and tested in isolation; **NOT approved for hosted apply**. No PR C/D work.

## Behavior

Existing Services form and five-link navigation retained. Mode: price / negotiated / unspecified. Optional unit: service, hour, lesson, day, square_meter, project. New services default RUB and service unit; legacy edits preserve existing RUB/USD/EUR and NULL unit (no invented unit). Legacy NULL mode displays priced when any bound exists, otherwise unspecified; never automatically negotiated.
Zero is a valid price, including exact0; no automatic «free» label. From-only, to-only, exact and range supported. Negotiated and unspecified have NULL amounts and remain distinct. Currency without monetary amount is not presented as a rate.
Switching mode retains unsaved numeric input in the page. Saving a non-priced mode explicitly stores NULL amounts; this is the selected mode's meaning. New v2 accepts at most two nonzero decimal places. Fresh read-only metadata clarified that hosted price columns already are numeric(12,2), not unconstrained numeric. No type change, amount rewrite, currency conversion or historical backfill.
A read-only owner capability RPC gates new controls. Only missing-function PGRST202/42883 uses the unchanged legacy pricing form. Other capability errors fail closed. A failed v2 WRITE is never retried through v1. Stale save keeps draft and explains reload; explicit reload resets form only after confirmation.
No company, contacts, profile creation/year, media UI, publication, public output, AI or billing changes.

## Exact migration package and dependency order

UP: supabase/migrations/20261026040132_specialist_service_pricing_candidate.sql.
Created with the already installed Supabase CLI migration new, never applied by CLI.
Prerequisite: existing PR31 profile/services/editor schema; PR32–35 unchanged. Migration contains its own transaction, 5s lock timeout and30s statement timeout.

1. Add nullable price_mode/price_unit to specialist_services, no defaults/backfill.
2. Add two CHECKs NOT VALID, then VALIDATE in transaction. Existing range/currency/numeric(12,2) checks retained.
3. Create specialist_service_pricing_save_internal(uuid,uuid,text,text,text,text,numeric,numeric,text,integer,boolean,integer,boolean), inaccessible to PUBLIC/anon/authenticated.
4. Create save_my_specialist_service_v2(uuid,uuid,text,text,text,text,numeric,numeric,text,integer,boolean,integer).
5. Replace ONLY body/language of save_my_specialist_service(uuid,uuid,text,text,numeric,numeric,text,integer,boolean,integer), same OID/signature/defaults. Existing grants including service_role retained, PUBLIC/anon revoked; authenticated execute retained.
6. Add get_my_specialist_service_pricing(uuid), read-only {schema_version:2}, owner+draft check.
7. New public owner endpoints: fixed empty search_path, SECURITY DEFINER, anon/PUBLIC execute denied, authenticated allowed. Internal helper independently checks auth.uid(), owner and draft, locks parent then service, checks CAS before validation, increments once. RLS/table grants/Storage and all other RPC definitions untouched.
8. get_my_specialist_services already returns row JSON; new keys additive, old keys/values retained. Test checks every unrelated existing function definition unchanged.

V1 compatibility: new v1 rows have mode/unit NULL. Existing v1 edits preserve unit. Numeric comparisons use IS NOT DISTINCT FROM: unchanged amounts preserve mode; changed bounds map priced if any amount or unspecified if none. Currency-only changes preserve mode and are separately tested; version increments exactly once. Legacy editor cannot express new semantics; presentation limitation, not a claim of full old-UI support.
V2 has a distinct name (no overload ambiguity), requires explicit mode; contradictory mode/amount, NULL required fields, invalid unit/currency/range, NaN/infinity and out-of-bounds reject before write. No silent v2 rounding; v1 retains historical rounding semantics of numeric(12,2).
Current CAS error PT409, and existing UI also handles legacy40001. No price unit is inferred from duration.

## Rollback

Preferred operational rollback: revert only Services frontend to baseline; **keep additive columns and compatible v1 wrapper**, all new values remain readable and editable by approved clients. Tested v1 editing extended rows.
Optional contract DOWN candidate: sql/specialist-service-pricing-rollback-CANDIDATE.sql. Explicit owner approval required. Locks services, REFUSES if ANY mode/unit is non-NULL; it never clears metadata. Then restores exact hosted v1 definition captured2026-10-26, drops v2/capability/internal helper and two constraints/columns. No rows or prices dropped. Legacy-only down tested. Test-only clearing metadata to exercise down is NOT a rollout instruction.
If guard refuses, stop: do not clear columns or CASCADE-drop anything. Export/review is a separate decision. Full current definitions and grants must be snapshotted/reverified immediately before any approved apply/down.

## Claude review ca0da4e9 incorporated

GO for isolated B, NO-GO hosted migration remains:
- P1-1: common inaccessible helper; numeric IS NOT DISTINCT FROM; currency-only negotiated edit tested; version once.
- P1-7/G4: native PostgreSQL17.11 actual multiconnection SQL plus SQL-backed Edge browser; v1/v2 conflict and upload/price/profile-delete interleavings. Not PGlite concurrency claims.
- P1-8/G1: read-only hosted pg_get_functiondef+aclexplode snapshot for six named service/media functions stored privately at C:/Users/Yumis/otzovik-stage2b-private/pricing-hosted-definitions-2026-10-26.json. Public hash/ACL inventory: SPECIALIST_PRICING_HOSTED_HASHES_2026-10-26.json. Recheck hashes before apply; abort on drift. No hosted CRUD/DDL executed.
- P2-4: new v2 values >2 decimal places reject; existing values/currencies unchanged.
- G2: no workflow changes/retarget used. Existing automatic CI does not cover PR35 base. Full tests/local-stack.mjs requires unavailable disposable Supabase Auth/PostgREST/Storage config and Docker stack; this remains a staging-approval gate. Isolated SQL-backed browser fixtures simulate Auth/Storage and do NOT substitute a real Supabase stack run.
- G3: production shape/scale aggregate audit is still required before production release. Production not queried for B.
- G5: exact hosted staging apply requires separate explicit approval; production another decision.
P1 portfolio findings (link reorder constraint, universal media lock ordering, server reconciliation, retry semantics, rights retention, global quota) are recorded as required corrections for FUTURE PR D; no project/card SQL added now. Year/save proposals remain PR C.

## Reproduction and evidence

Use PostgreSQL17 installed locally; no downloads/dependency changes are needed:
```powershell
$env:PG_BIN='C:/Program Files/PostgreSQL/17/bin'
npm.cmd run test:pricing:local
node tests/pages-artifact.mjs
node tests/specialist-ux-browser.mjs
```
scripts/test-pricing-local.mjs creates a fresh temporary cluster per pricing test, random password, free loopback-only port, exact disposable DB name, invokes synthetic fixture tests, then stops/removes only that cluster. It refuses a non-PG17 binary and unknown test names. Existing shared databases are not used.
Raw pricing/SQL/media logs and final counts are recorded in the acceptance supplement. Browser routing aborts all unrelated network traffic, selects actual isolated SQL RPCs through a test adapter; no production request.
Security tests: owner/foreign/anon, direct table/helper deny, stale/cross-profile child IDs, CAS, unchanged unrelated functions/company sentinel, quota50, invalid inputs atomically reject.
Browser: save/reopen, legacy USD/NULL unit, retained mode values, negotiated/unspecified/zero, range field errors, v2 missing/offline no fallback, stale reload, XSS textContent, capability absent, foreign disabled inputs,320/390/1440.
Media race regression: upload vs profile delete; new price save vs upload vs profile delete; existing Storage-first metadata cleanup unchanged. Storage tables/policies are local fixtures, not hosted Storage proof.
33 company legacy account files must match base PR35 blobs AND actual checkout bytes. No .github or public build manifest changes.

## Approval request — do not execute from this document

Requested next: independent review of this exact UP, DOWN and source HEAD; decide permission for a single controlled staging migration on salmcnhexlftrgtiryyo ONLY after remaining full local Supabase stack/CI gate and drift checks.
Include migration SHA256/commit, before definitions+ACL snapshot, backup/rollback and post-apply catalog diff + owner/foreign/anon smoke in that explicit release decision.
This PR and HANDOFF do not grant apply permission. No deploy, merge, public profile or production release is requested here.
