# AI consultant v1 — owner mock preview, candidate only

Task: ed62eebb-85d3-478c-b133-6d45199ac34d. Base main 3b8a639.
References: Claude 96bdeb41, cbb12c5d, 640480cf and bc200b3f (32cd7a27).
No production SQL, deployed page, provider call, billing, booking, external embed, CRM or notifications.

## Verified context and boundaries

PR23 remains Draft at 69d4bc6. Both existing CI runs succeeded. Its uncommitted hosted/PT409 fixes remain untouched in the original checkout. This PR adds only ai/, tests/ai/, independent SQL candidates, this document and a new test workflow. Existing pages, routing, manifests and company/specialist functions are unchanged. Hub search returned no separately named AGENTS.md/WORKSTREAM_SCOPE or current state record; task and cited handoffs are the available live rules. No applicable local AGENTS.md found.

Claude v2 recommends company-only and no summaries. Owner's newer instruction authorizes a shared company/specialist contract and safe temporary summaries. Resolution: settings work for both types; actual specialist chat fails closed until a real publication contract exists. Summary is only a code-validated enum derived from the last visitor message, never prose, assistant claims or recursively summarized content. This is a restricted experiment, not approval of retention or provider privacy.

## Contract

Identity is always (profile_kind, profile_id UUID). Do not infer from slug, last active company or other profile. Settings: version, enabled, greeting (300 chars), instructions (2000), extra_information (4000), position (bottom-right, bottom-left, inline). Instructions are preferences; extra_information is owner-provided answer data. Neither is a trusted system message. No secrets belong in either field. `enabled` records desired future public availability; owner preview intentionally works while disabled. There is no public chat endpoint in this deliverable.

RPCs: get_my_ai_config(kind,id), save_my_ai_config(kind,id,expected_version,settings), get_my_ai_snapshot(kind,id). All require current authenticated ownership; company membership must be verified and owner. Admin/manager/analyst are deliberately not granted access in v1 (a permission expansion requires an explicit decision). Specialist uses its independent owner_user_id. Direct private-schema access is denied; all tables have ENABLE/FORCE RLS; SECURITY DEFINER functions use empty search_path and explicit EXECUTE grants. Trusted BYPASSRLS migration owner is required, consistent with existing candidate model. PT409 is used for stale versions, not SQLSTATE 40001.

SQL is not automatically applied. ai_private has configs, snapshots, platform, and a reserved session-storage model. Platform starts disabled. Settings are persisted through RPC. Sessions currently live only in the bounded gateway process; the SQL session model is not wired into runtime. No plaintext token is stored server-side: keys are SHA256 digests of 256-bit random bearer tokens. Tokens/JWT are held only in browser memory; refresh or process restart loses resume. There is no cross-device or global visitor identity.

## Public knowledge adapter

`publishedSnapshot()` accepts an explicitly confirmed published export, strips unknown/private fields, retains published services/public contacts and hashes the bounded payload. It never reads specialist drafts. The trusted publisher supplies the UUID binding; slugs in export JSON are not identities. Snapshot import/invalidation must be bound to the existing publisher's successful publication/unpublication events before deployment. That publisher integration is intentionally NOT changed in this independent PR: actual authoritative publication boundary and specialist publication are unresolved. No arbitrary URL fetching, SSRF path or browser-supplied snapshot is implemented. Owner RPC only reads an already installed snapshot; missing snapshot fails 409. SQL explicitly returns no specialist snapshot until its publication contract is approved. Synthetic specialist snapshots are tested only through the injected repository.

Do not seed snapshots from live company rows or copy a draft. Prices, contacts and publication semantics must remain identical to canonical profile.json. Current normalizer handles flat export schema; nested legacy variants need explicit adapter tests before use. Publication/version mismatch during a response fails 409. Revision change clears prior history, slots and idempotency cache.

## Server and temporary memory

Run `node ai/server.mjs` with explicit isolated AI_SUPABASE_URL, AI_PUBLISHABLE_KEY (`sb_publishable_...` only), optional PORT and AI_PREVIEW_TTL_MS. Server binds loopback only. Login uses ordinary Auth password flow, verifies bearer with /auth/v1/user and invokes the owner's RPCs with the same JWT. No service-role/provider secret is needed or exposed. Browser login credentials are sent only to loopback gateway then configured Supabase. Use synthetic isolated test accounts. No production credentials in this preview.

POST /api/login, /api/config, /api/save, /api/start, /api/chat, /api/history, /api/clear. Same-origin validation, no CORS, no-store, CSP and textContent output. Start creates separate profile-bound session; every operation rechecks ownership. Chat: bounded input, profile snapshot, platform rules, owner preferences as untrusted data, last <=10 messages/8000 chars, enum intent summary, provider timeout, repeat/sequence guard, usage counter. Simultaneous turns return 409. Repeated request IDs do not call provider twice inside the bounded cache (last 30 responses); older IDs fail sequence validation rather than replaying. Provider errors do not commit history/usage. No paid accounting claims.

Experimental preview TTL defaults to 30 minutes from creation, fixed not sliding, configurable 1 second–24 hours; this is NOT approved product retention. Cleanup runs every 10 seconds and before access. Expired/cleared tokens fail; clear/new conversation deletes old in-memory history immediately. Clear/kill during provider execution prevents commit. Restart also removes all history. No logs contain transcript, password or token. In-memory usage is an aggregate counter per profile, not a financial ledger.

Rate caps: 10 session starts/minute/owner, 20 chat turns/minute/owner, 30/profile, <=200 sessions/process; login capped globally. This is sufficient only for loopback owner mock preview. Before public runtime: distributed caps, captcha choice, abuse controls, stable session store, narrowly scoped gateway DB role, privacy decisions and external-provider validation are required. MockProvider is replaceable via `complete(context)` injection; executable rejects non-mock AI_PROVIDER. No DeepSeek HTTP implementation/key or real API call is enabled. Prompt-injection safety with a real LLM is NOT proven by deterministic mock tests.

## Disable / rollback

Runtime `gateway.kill()` blocks starts and responses and clears session data; DB platform.disabled blocks snapshot RPC and is rechecked after provider completion. `AI_CONSULTANT_V1_DISABLE_CANDIDATE.sql` disables platform/profile flags, purges reserved sessions and revokes config writes. Stop the gateway process to discard active memory. It changes no company/specialist objects. To restore in an isolated test only, restore intended profile flags, grant the original save signature and explicitly clear platform.disabled after audit. No automatic re-enable or destructive down migration.

## Verification and release blockers

`node tests/ai/acceptance.mjs`: PGlite locally; CI uses real PostgreSQL16 in disposable loopback otzovik_ai_acceptance DB. Role/CRUD denial, swapped IDs, two owners, revoked membership, validation, PT409, platform flag, snapshot filtering, token isolation, TTL/clear, idempotency, revision reset, context/summary bounds, rate cap, concurrency/kill, provider failure/retry, real HTTP origin/auth and disable regression.

`node tests/ai/browser.mjs`: desktop/mobile login, profile selection, setting save, mock chat and clear with synthetic Auth/repository adapters. This does not claim real Supabase browser Auth acceptance. `npm test` and `npm run test:pages` verify unchanged existing main flows/artifact. New files are deliberately excluded from Pages and cannot be released by the existing manifest.

Remaining before launch: independent SQL/security review; hosted Auth/PostgREST check of these NEW RPCs; publisher snapshot binding/invalidation; specialist publication; durable multi-instance sessions if required; retention and privacy/provider-transfer decisions; real provider budget approval and injection evaluation; public abuse controls and gateway hosting choice. Existing PR23 hosted conflict fix remains a separate workstream. Production SQL, merge and site release each still require owner permission. No hosted demo is published because publication is expressly forbidden.
