# One cabinet, two profile adapters — first iteration

Owner decision: Hub17ac46a9 and Claude audit6d35d11e. Scope approved in current task: preparation, then minimal shared shell on test Pages. No production/DNS/Worker/SQL/main merge. Baseline: PR28 cb7ee9342e7103db68c8d5adbaafc7225e05e4e6, test Pages deployment ded02297. First iteration is a small stacked PR against PR28, not a wholesale rewrite.

## Component map before implementation

| Component | Existing company implementation | Specialist implementation | First shared iteration |
|---|---|---|---|
| Header/home/profile switch | Repeated header in account-*.html, account-company-context.js | Separate brand/home links | One shell renders company-style header and shared My Profiles switch link; mount on specialist first |
| Horizontal navigation | Repeated HTML + company-context role mutations | specialist-ui navigation() | One renderer and typed menu configs, specialist left8px behavior retained; company config contract-tested but legacy pages untouched |
| Auth/context/access | getSession, get_my_companies, membership roles, saved company id | specialist-api context, get_my_specialists, owner-only draft | One controller normalizes kind/id/name/role/status/data; explicit IDs, no cross-kind or first-profile fallback; narrow adapters keep RPCs independent |
| Basic profile load/save | Company-specific seven-argument update RPC | Six-field draft load/update | Shared load/save lifecycle and exact per-kind argument adapters; specialist wired first; no schema or publication changes |
| Errors/loading/forms | Inline state text, disabled fieldsets | specialist-api message/status | Shared error/status helpers and fail-closed loading; preserve existing messages where needed |
| Services | Company name/category/description, immediate publication | Price ranges/currency/duration/private draft/version | Keep existing editors this iteration; next PR uses shared form/list primitives with distinct field schemas and mutation semantics |
| Media | company-media + company membership + publish pipeline | specialist-media + owner + private downloads | Move pure existing resize/text helpers into shared UI now; Storage adapters and editor migration remain separate next steps |
| Contacts/work | Company basics/branches | specialist_settings + work formats | Keep existing fields and guarded RPCs; shared field primitives in next section PR |
| Reviews/Q&A/sources | Existing company RPC clients | Backend absent | Shared shell routes/status only; never send specialist IDs to company RPCs |
| Analytics/notifications/AI/MCP | Some company sections also unavailable | Honest disabled specialist panels | Preserve honest status; a visible section is not a working backend. AI and MCP remain required product scope, not silently postponed or enabled |
| Publication | Public company v2 RPC/Worker | No approved public specialist contract | Separate investigation; shared UI does not publish drafts or fix Worker routing |

## First iteration design

- `account-profile-core.js`: transport-independent controller, UUID/kind/explicit-ID validation, session check, authorized context loading, revalidation before basic save, compatible profile context keys. It never changes permissions on the server.
- `account-profile-adapters.js`: company and specialist menu/normalization/basic-save adapters. Company roles stay verified owner/admin for edits; analyst/manager visibility follows existing contracts. Specialist requires owner draft. No combined table/RPC/bucket.
- `account-profile-shell.js` (+ scoped CSS): common company-style header, My Profiles switch link, common upper navigation, text/error/status/image helpers. No domain-specific RPC in shell.
- Existing specialist API/UI entrypoints become thin compatibility facades. All specialist sections use the shared controller/shell; basic editor uses common load/save. Existing URLs and `id`/`company_id` conventions remain valid.
- Company pages and account-company-context.js stay byte-identical. Common CompanyAdapter is exercised using the same controller and SQL contracts in tests; actual legacy company pages move one section at a time in later PRs. Do not claim this first step already eliminates every legacy company page.
- Specialist top navigation stays left aligned, with8px inset and edge clamps; no page swipe/arrow dock. Reuse company header styling, not a new design.

## Verification gates

1. Same shared controller contract tests for both kinds: load/save/reload, exact IDs/kinds, malformed IDs, unauthenticated/foreign/revoked denial, no fallback, independent keys and capabilities.
2. Company byte-identical gate against immutable baseline; existing browser company behavior/menu snapshot remains unchanged.
3. Existing 15 browser groups including mobile first/middle/last menu transitions/reload/manual scroll and private draft isolation; desktop and mobile shared shell/header checks.
4. Existing disposable real Supabase Auth/PostgREST/Storage suite. These tests do not authorize hosted schema changes.
5. Build exact public manifest; only reviewed public modules/CSS added. No tests/docs/SQL served. Compare immutable source archive to local build, then live HTTPS bytes after test Pages publish.

## Subsequent small iterations

1. Shared service editor primitives plus per-kind fields and draft/publish semantics; hosted specialist backend approval remains a separate gate.
2. Shared media and contact forms; retain independent Storage privacy/quotas and versions.
3. Move one legacy company page at a time behind isolated preview, starting with unavailable notification/AI UI, then analytics, then working services/media/profile after DOM/behavior parity. No simultaneous mass conversion.
4. Separate public specialist schema/snapshot/publisher/staging Worker contract, privacy and slug namespace tests. Never expose draft data as a public fallback.
5. AI owner assistant, visitor consultant, and MCP grant/revoke backends remain distinct scoped workstreams; no paid calls or public enablement here.

## Independent master5 diagnosis (read-only)

22 October live metadata: exact slug `master5` has NO companies row and NO company_profile_publications row. profile_slug_registry binds it to kind `specialist`; specialist_profiles status is `draft`. Public company RPC v2 delegates to v3_candidate and returns JSON null for master5. Fresh HTTPS master5/profile.json returns404, Worker version10; test2/profile.json returns200 version10. Thus master5 is a private specialist draft, not a missing published company. Worker currently only fetches company RPC; the404 is consistent with current privacy/publication contract. No repair, production mutation or publication performed. UI unification must not expose master5 to make the URL appear working.

Existing Worker source is available to Work via authorized GitHub access and preserved local snapshot; Claude's lack of access is her audit limitation, not evidence that a new route is needed. Any specialist public extension must be developed/staged separately with owner GO, published-only lookup and company/specialist slug collision protection.

## Rollback

Restore previous test Pages deployment ded02297-5285-458c-8bdb-9720b8f2f10c. No DB changes to roll back. Keep original PR28 and main intact. Do not remove Worker versions or change DNS.
