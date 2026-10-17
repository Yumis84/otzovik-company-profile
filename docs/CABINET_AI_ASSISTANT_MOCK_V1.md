# Internal platform assistant — separate mock v1

Authorization: Hub REQUEST8ebed126, DECISIONe667a69f; gateway target Supabase Edge Functions+Postgres per3c714cfd. This product helps authenticated owners build profile drafts. It is NOT the visitor consultant in PR24 and NOT the external owner MCP agent. This branch starts from main3b8a639 and changes only new cabinet-ai/, tests/cabinet-ai/, this spec and its test workflow. PR23/24 pages, SQL and routes remain unchanged.

## UX and working mock

Desktop: right docked panel next to profile editor. Mobile: fullscreen chat, explicit close; separate /history page lists the SAME conversations. New conversation, resume, clear, proposal review, reject and explicit confirmation. Model proposals never write directly. Every confirmation checks authenticated owner, conversation/profile binding and optimistic profile version. Unknown prices return unknown; no internet claims or fabricated citations. Mock description is verbatim owner text, not a factual externally verified description.

`node cabinet-ai/server.mjs` serves loopback18888. /api/demo gives access only to explicitly synthetic demo-a/company-demo and demo-b/specialist-demo data; anyone with loopback access can choose either fixture. THIS IS NOT REAL AUTH AND MUST NOT BE DEPLOYED. There are no real credentials, provider calls, production data or saved secrets. Hash-keyed random bearer fixture tokens expire after30min. TTL30min and bounded process-local memory are an experiment, not product retention. History is owner/profile scoped; <=10 messages/8000chars; clearing/expiry removes proposals. Fixed platform rules are code-owned, HTTP rule overrides rejected. Pending proposal IDs bind exact stored patch/version/owner/profile; approval cannot supply a patch or target. Platform kill denies new/chat/approval operations. Usage caps are mock per-owner rates, not billing.

## Planned production architecture (candidate, no deployment)

Cabinet uses existing Supabase Auth session; Edge Function verifies JWT user AND live membership/ownership for every operation. No password proxy or demo routes. Distinct endpoint namespace /cabinet-assistant/v1; visitor /profile-consultant/v1 and MCP grants are separate. Profile owners cannot edit platform prompt, tools or budget. Provider adapter may be shared, but prompts, context, credentials handling, usage scope and telemetry must remain separate. DEEPSEEK_API_KEY stays only in server secrets; never read/display/test here. Real invocation needs explicit approval.

Postgres private namespace cabinet_ai:
- conversations(id,owner_user_id,profile_kind,profile_id,created_at,expires_at,seq), messages(conversation_id,seq,role,content), requests(conversation_id,request_id,input_hash,status,result_ref), proposals(id,conversation_id,owner_user_id,profile_kind,id,expected_profile_version,allowlisted_patch,provenance,expires_at,status), audit(actor,profile,proposal,action,version,at) without raw transcript; aggregate usage scoped to cabinet owner separate from visitor profile budget.
- ENABLE/FORCE RLS, no direct anon/authenticated grants. Narrow RPCs enforce current auth.uid and authorized profile on EVERY call, including lists/reviews/approvals. Mutable grants/JWT user_metadata do not authorize. Proposal approval is a dedicated authenticated endpoint, never a model tool; atomic lock/version check/save-draft/audit/idempotency. No auto-publish/delete, no visitor access, no company/specialist table merging. Wire existing draft RPCs only after PR23 lifecycle coordination.
- Model capabilities: get_authorized_draft, propose_allowlisted_patch, get_platform_help; no raw SQL/HTTP/credentials, no approve/publish capability. Tool arguments validated by code and bound server-side to selected profile. Membership revoke/delete immediately blocks resume/approve; purge related memory on account/profile deletion.

## Retrieval and grounded prices

Current mock DOES NOT FETCH NETWORK. validateSource only accepts HTTPS exact platform allowlist with no IP/userinfo/ports; no arbitrary visitor URLs. Future retrieval must resolve all A/AAAA addresses, reject loopback/private/link-local/metadata/reserved addresses (v4+v6), pin vetted address/host/TLS SNI, revalidate every redirect, prohibit credentials, cap redirects/body/timeout/MIME, remove scripts, and run outside model execution. DNS rebinding and redirect tests are mandatory before enabling. Fetch result becomes untrusted quoted data with exact URL, retrieval time, text hash and evidence span. Prices must include currency/unit/date/source, and uncertainty; missing evidence -> no suggestion. No scraping/logins/cookies or current internet search in this PR. A boolean or model-supplied citation is not evidence.

## Threats and gates

Cross-owner/profiling leak -> profile-bound conversation and live owner check. Stored prompt injection -> fixed platform rules plus untrusted source blocks, no arbitrary tools. Malicious proposal -> server-stored allowlist plus explicit confirmation and stale-version rejection. Token theft -> short TTL, server checks, no third-party JS; production HttpOnly/CSRF design to be decided. Replay -> request ID/seq and idempotent approval; changes after review ->409. Cost abuse -> distributed owner/global quotas and timeout before paid provider, no reuse of visitor credits. PII -> no secrets in prompts/logs, user deletion, retention approved before durable storage. All profile changes remain drafts.

Before production: independent Claude review; real Auth/RLS/RPC tests; SQL-candidate for this private namespace; durable sessions and retention decision; hardened retrieval tests if enabled; provider/privacy/budget GO; explicit production SQL, merge and release permission. The Node server is only a fixture harness; no new live hosting or existing route is installed. Existing Pages manifest excludes every new mock file.

## Tests

node tests/cabinet-ai/acceptance.mjs:6 groups covering ownership, mixed kind/id, history isolation, no model writes, explicit confirmation, idempotency, stale proposal, unknown prices, URL rejection, TTL/clear/kill, real HTTP fixture-token authorization and Origin/rules rejection.
node tests/cabinet-ai/browser.mjs: desktop1280/mobile390, proposal review/approve, separate history resume, overflow and text output. Synthetic Auth only. Existing CI remains regression evidence, not acceptance of unimplemented real AI/retrieval/Auth.
