# Specialist cabinet integration — 22 October 2026

Owner scope: complete existing specialist cabinet, preserve approved design and independent company/specialist identities. Test Pages publication authorized; production DB/schema, public AI enablement, main merge, production Worker and DNS are not authorized.

## Sources and integration

- Main `76b3fa7a99df04d320b022a5a777fdbdf897b826` already contains merged PR20 and PR26 (no page swipe or arrow dock).
- PR23 `69d4bc6d6c6c0c9ad5e7b72197b821702333abec`: selectively imported independent services, contacts, private media, candidate migrations and tests. Its branch is untouched. Existing audit/recovery guard and limits retained. No blind branch merge.
- PR24 `250e370ff5d6850b813bada3e53b6300154ae4fa`: visitor consultant contract remains profile_kind/profile_id, published-only knowledge, private owner instructions, versioned settings, enable/kill switch and isolated session TTL. A specialist private draft has no published snapshot. No mock server or chat endpoint is shipped by this Pages artifact.
- PR25 `bc9a0e50b74798cad5348bb37ccb32517df146de`: cabinet assistant is distinct from visitor consultant: authenticated ownership, persistent conversation history and stored allowlisted proposals, optimistic versioning and explicit confirmation. Its disposable test config/vendor dependency is not valid on this Pages environment; launcher is therefore not copied or enabled. No fallback to demo identities or in-browser fake history. Approved prototype code remains in its PR for separate server rollout.
- Claude audit `7eedde11-30fd-40d3-81aa-e84502e6c45a`: root cause accepted. Multi-tab PR23 code was not published and its DB candidates were absent.

## Behavior

Dashboard edit and successful create open `account-specialist-profile.html?id=<uuid>`. Legacy create?id links redirect there. Saving the six-field basic draft stays in the editor. Name, profession, specialization, city and description load through existing owner-only get/update RPCs; slug stays reserved/read-only. No company context fallback.

All 12 sections are reachable through the same upper navigation: profile; services/prices/duration; avatar/portfolio; contacts/work formats; reviews/replies; questions; rating sources; analytics; notifications; AI assistant (owner helper and visitor consultant); own agent/MCP; settings/publication. No branches. Native scrolling applies only to the top menu; no page-changing swipe or bottom arrows.

Services, contacts and media are real RPC/Storage clients from PR23. On the live database their backend is **not installed**. Initial read failure keeps the whole form disabled and explains that storage is not connected. There is no localStorage persistence, simulated success or mock content. With the candidates installed in a disposable DB, save/reload, stale-version refusal and owner isolation are tested. Private media never uses public URLs.

Other sections state their actual unavailable status, with disabled actions. No invented reviews, ratings, usage numbers or grants. AI fields are disabled and explicitly do not save. MCP has individually listed, unchecked and disabled permission choices; it does not create a connection or token. Publication remains disabled. This is a functional navigation integration, **not completion of all server modules**.

## MCP grant/revocation contract

MCP is part of the current scope but cannot honestly be activated before its authorization backend exists. No raw key input or implicit use of the website login session by external agents.

Future server grant: id, owner_user_id, specialist_id, agent/client id, allowlisted scopes, created_at, expires_at, revoked_at and audit reference. Scopes independently opt in: draft:read, draft:propose, services:propose, media:propose, reviews:read, replies:propose. Default empty; publish/delete/permission-management are excluded. A company ID cannot substitute for specialist_id. OAuth authorization binds the authenticated owner, selected profile and approved scopes; code exchange/PKCE and short-lived audience-bound access tokens are server responsibilities. Store token hashes, never raw tokens; no secrets in Pages.

Each operation rechecks live ownership, grant, expiry, scopes and revocation. Editing uses stored server proposals and explicit owner confirmation, never an agent-supplied approval payload. Revoke is owner-only, atomic and immediately blocks the next request, including existing conversation resume and queued proposal execution; audit contains IDs/actions, not token/transcript. Existing history and draft deletion follow separately approved retention/cleanup policy. The UI must load server-confirmed grants before claiming any connection is active or revoked. No frontend-only revoke claim is implemented.

This is an integration contract, not a deployed OAuth/MCP endpoint. A reviewed migration/server implementation and two-owner/revoke-race tests are prerequisites for activation. No speculative schema applied.

## Fresh hosted preflight (metadata only)

22 October: only create_my_specialist_draft/get_my_specialists/update_my_specialist_draft exist, authenticated EXECUTE true, anon false. specialist_services/settings/media and specialist-media bucket absent. No AI config RPCs. No user records or Auth settings changed. Existing drafts are preserved.

## Migration approval package

Existing reviewed candidates are included unchanged from PR23. Generate offline with `node scripts/specialist-editor-migration.mjs`; this does not connect to a DB. Apply only after explicit approval for the target environment. Read-only preflight: sql/20261017_specialist_editor_preflight_READ_ONLY.sql. Apply includes editor, private media and draft lifecycle. Disable/enable candidates preserve data; do not drop tables/bucket. Guard refuses existing bucket or unsupported managed Storage policy permissions. Never bypass the guard.

Before any production apply: archive current definitions/grants; run same deployment identity in isolated hosted staging; test two real Auth users, owner/foreign/anonymous RPC and Storage, media quota/upload-delete races, apply→disable→enable and company Storage regression. Then request specific production SQL approval. Existing project is production Supabase even though the frontend is a test Pages site. Do not infer data isolation from pages.dev.

## Publication and rollback

Build `node scripts/build-pages.mjs`; validate `node scripts/check-cloudflare-pages.mjs`. Exact manifest: 61 public files. SQL, docs, tests, mock servers and config are excluded. Existing Cloudflare Pages project `otzovik-cabinet-dev`, direct-upload using Composio cloudflare connection; never connect this static repository to production Worker. No automatic production deployment.

Rollback target: Pages deployment `f3fcbd1d-23c6-497e-afc7-526d70bb8a12` (49-file artifact, commit ab3c52f). Frontend-only rollback does not change DB or delete drafts. Keep main and original PR23/24/25 untouched. Production Worker v10 and DNS must remain unchanged.

## Acceptance evidence and remaining limits

Local: 13 baseline PGlite SQL groups, 9 editor SQL/security groups, 61-file manifest checks and secret-pattern/inert-swipe preflight. Browser test uses isolated SQL with synthetic Auth; it does not establish hosted Auth. CI additionally exercises disposable real PostgreSQL/Auth/PostgREST/Storage and desktop/mobile browser. Record final-SHA CI results and deployment IDs in Hub; do not infer new CI from old PR23 runs.

Blocked on approval/server work: hosted editor migration; specialist public snapshot/publisher; reviews/questions/rating sources/analytics/notification backends; AI config/history/proposal gateway deployment; external MCP authorization/grant/revoke implementation; paid provider/privacy/retention decisions. Public AI remains off. Real user login/save on Pages requires owner session or separately authorized synthetic hosted test identity; existing owner reports successful creation are user evidence, not an automated end-to-end pass.
