# Specialist cabinet stage 2A

Request: Hub 40a8e4be-03cc-44b0-ac0e-0a52d555bbd4. Base PR30 b382174. Reuse PR23 specialist editors, not PR29 shell.

| Section | UI | Existing backend | Read-only staging preflight | Risks / validation |
| --- | --- | --- | --- | --- |
| Profile | PR30 six-field form | get/create/update_my_specialist_draft; specialist_profiles | Present | Draft-only UUID ownership; create/edit/reopen regression |
| Services | PR23 services editor | get/save/delete_my_specialist_service; specialist_services | Present; forced RLS; auth EXECUTE, anon denied | Version conflicts, input ranges, cross-owner IDs, XSS |
| Photos / Portfolio | PR23 private media editor | get/register/delete_my_specialist_media; specialist-media | Private bucket; 5 MiB; JPEG/PNG/WebP; owner SELECT/INSERT/DELETE policies | Upload/register failure recovery, cleanup, cross-owner Storage, object quota |
| Contacts / Work | PR23 contacts editor | get/save_my_specialist_settings | Present; forced RLS; auth EXECUTE, anon denied | Private-only visibility, HTTPS, version conflicts |

## Scope
Company source files are immutable. Only specialist pages use the shared specialist-only navigation helper, with the existing account-preview.css unmodified. Header markup matches PR30/company. No All Sections, branches or future-section placeholders. Saved specialist IDs travel in ?id=; new profile creation shows only available navigation. A context plaque identifies the specialist. Existing save-to-list behavior remains.

The existing PR23 RPC/UI/Storage code is reused; pure UI navigation/styles are adapted to the approved company appearance. Clean Pages URLs are normalized back to the existing .html login-next allowlist. No company controller or RPC is used by specialist modules.

## SQL boundary
All imported SQL files are reviewed PR23 candidates required by disposable local/CI tests. They are NOT automatically applied to any hosted database. Existing staging salmcnhexlftrgtiryyo already supports this stage. No hosted schema migration, production mutation, main merge, DNS or billing change is authorized by this PR. If staging drifts, stop and report rather than apply candidates.

## Validation
- npm run test:editor: disposable PGlite/PostgreSQL security contract tests.
- npm run test:pages: public artifact allowlist and dependency validation.
- TEST_BROWSER_CHANNEL=msedge node tests/specialist-stage1-ui.mjs: mock-RPC profile regression.
- Existing CI: PostgreSQL and isolated real local Supabase Auth/PostgREST/Storage; editor tests reused from PR23. Company browser regression remains from current main (no old swipe behavior imported).
- Separate staging-only deployment substitutes URL/publishable key and bundles the same pinned SDK. Source company bytes stay unchanged; deployment config differences must be declared. Hosted synthetic-only checks and final evidence are recorded in Hub HANDOFF.

## Known limits
Published specialist editing is intentionally unavailable until a separate revision/publication contract. Client image re-encoding does not provide server content scanning. Hosted email delivery is outside this stage. The reused synthetic staging company fixture lacks the pending-invitations RPC and may show an unrelated dashboard warning. Owner visual acceptance is required before merge.
