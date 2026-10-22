# Shared settings navigation — company and specialist

Owner task 22 October supersedes the old left/center auto-scroll UX. Follows Hub audit6d35d11e, decision17ac46a9, Work handoff bf84dc32 and review request681e5f40. Continue DraftPR29, no merge. Rollback is test Pages c1ac8bd4-fdda-4e00-953f-1d80419968ed / commit3d6a154.

## Implementation boundary

One registry `account-profile-sections.js`, one renderer `account-profile-navigation.js`, one stylesheet `account-profile-navigation.css`. Company-derived order/style; availability and narrow editor routes per kind, existing company roles retained. Both company context and specialist shell call the same renderer. No duplicated HTML menu lists remain on company pages. Compatibility adapters derive their menus from this registry, not separate lists.

Mobile <=640px: Profile/Services/Photos primary links + native button All Sections. Expanding exposes the complete applicable list, current link aria-current=page. Additional active section is always named beneath the primary row, including on clean/direct URLs; desktop also shows the current extra label even if its horizontal link is outside the viewport. Selection closes the list. Escape closes and returns focus; outside click and focus leaving navigation close; native links preserve keyboard navigation and open-in-new-tab behavior. No page swipe, arrow dock, auto-centering, scrollTo or forced reveal. Desktop retains the company horizontal list, with wrapping rows; resizing shows the correct variant. Small mobile widths tested at320/390.

Company HTML changes limited to removing repeated nav contents and adding shared CSS. Headers, forms, inline editor scripts, RPCs and CSS remain unchanged (normalized32-source parity gate). account-company-context.js replaces only old menu mutation/role/auto-scroll functions with shared adapter/render calls; active company bar, context keys, media decoder and other editor links retained. Navigation is not an authorization boundary; server Auth/RPC/RLS remain authoritative. Role visibility uses existing adapter rules.

Specialist existing profile, service, media and contact editors remain routed through own narrow RPCs; no company ID/RPC substitution. Photos section includes avatar and portfolio. Other existing sections keep honest unavailable statuses. No SQL/Storage migration, mock persistence, automatic publication, AI enablement or paid call introduced.

## Acceptance gates

- Shared core SQL contracts and both adapters; normalized company editor/header/CSS parity; clean/direct URL section resolver; role/type matrix; no scroll calls; both production consumers import same renderer.
- Browser regression company profile/branches/services/photos, specialist save/reload, foreign/anonymous/private draft denial.
- Mobile both kinds320/390: three primaries, full list and current extra label, selection/reload/deep links, Escape/focus, outside close, no overflow. Desktop1280: full list, extra current item, manual overflow preserved.
- Disposable local Supabase Auth/PostgREST/Storage regression; hosted migrations forbidden.
-68 exact allowlisted public files, no SQL/docs/tests/secrets; after green CI publish test Pages via existing hosted Composio connection and compare live bytes.

## Functional status / remaining work

Company existing backend editors unchanged: profile/services/branches/media/reviews/Q&A/sources/access. Existing company AI/notifications still unavailable; analytics is not real visit tracking. Specialist base draft profile works with hosted backend. Services/prices/duration, avatar/portfolio and contacts have existing editors/candidates and isolated acceptance, but hosted RPC/schema/private bucket absent: saving explicitly disabled on missing backend. Reviews/Q&A/sources/analytics/notifications/AI/MCP/publication specialist backends remain unavailable and clearly marked. AI/MCP remain required product work, not silently dropped.

This iteration unifies navigation used by BOTH real consumers. It does not claim every editor/form/backend has already been unified. Next: per-section shared editor primitives with typed RPC/Storage adapters and independently approved hosted backend rollout. Public specialist snapshots/staging Worker are separate; master5 remains private specialist draft and must not be exposed.

No production Worker, DNS, SQL, main merge or paid resources. Test Pages publication is the only deployment. CI links, exact head, deployment and final results will be recorded in PR29 and Hub HANDOFF.

Observed regression boundary: unchanged legacy company profile form overflows at320px (document398px), while shared menu bounds are11..309px with no overflowing children. The32-source normalized parity guard confirms its forms/header/CSS were not modified. Menu geometry is tested independently; this pre-existing form layout issue is recorded for a separate narrow fix, not silently hidden or claimed resolved.

Claude review ab824e02 read in full. M1: persistent All Sections label plus active name inside blue toggle, full current label retained. M2: mobile links/toggle min44px, primary/link font14px. M3/M8: desktop wraps horizontal links, no hidden active tab or forced scrolling, same640px breakpoint. M5 focusout closes, M6 active label respects role-filtered items. C5 normalized32-source editor/header/CSS parity replaces previous33 raw-file gate. C1 intentionally draft-only until approved published-specialist contract (current schema allows onlydraft); widening statuses would invent a publication/edit contract. C2 CompanyAdapter is contract-tested but not mounted for company lifecycle; existing company context/selection/roles remain unchanged; pending/unverified are not granted new access. Future shared-company controller migration requires explicit status/role parity tests. M4 grouping and M7 unknown-section handling remain follow-up UX work; no role expansion or public data exposure.
