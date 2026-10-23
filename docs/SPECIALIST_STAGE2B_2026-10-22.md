> Status update 23.10.2026: approved candidate applied to STAGING ONLY; see [hosted activation report](SPECIALIST_STAGE2B_HOSTED_2026-10-23.md). Earlier blocked status below is historical.

# Specialist contacts — stage 2B, 2026-10-22

Scope: additive Contacts implementation on PR31 HEAD c0a97c00450da75f039837a938c76a671fcd775f. PR31 remains Draft/open, main 76b3fa7a99df04d320b022a5a777fdbdf897b826. Claude HANDOFF 03354f47-a50a-43b0-a5d1-8a68a0019275 reviewed.

## Real staging preflight (read only)
Project salmcnhexlftrgtiryyo: specialist_settings has phone/email/website/work_formats/service_area/qualifications/contact_visibility/version/updated_at. Existing get_my_specialist_settings(uuid) and save_my_specialist_settings(uuid,text,text,text,text[],text,text,integer) enforce owner_user_id/auth.uid(), profile_status=draft; save locks draft and checks optimistic version. The seven-channel collection, its tables and new RPCs are absent. No hosted DDL, migration, Auth setting or production change was made. Backend evidence was read before implementing. Existing PR31 settings stay independent, including legacy website: no hidden backfill, no dual-write.

## Candidate, not deployment
docs/specialist-contact-channels-candidate.sql requires manual review and explicit approval. It is NOT in an automatically applied migration directory, build or hosted scripts. Disposable tests are its only execution path. Fresh additive install (not rerunnable); prerequisite PR31 specialist schema. Trusted superuser/BYPASSRLS migration owner required; transaction and 60s statement timeout. Check object names are absent, backup and review exact staging definitions immediately before any future approved application.

Two private tables: collection header with aggregate version and ordered channel rows; separate IDs, raw input, server canonical HTTPS href, kind, label <=40 codepoints, order, preferred flag, accepts_inquiries flag, forced is_public=false. Max20 entries, duplicate(kind,canonical href) and foreign IDs denied, max one preferred. Same URL in website and portfolio intentionally allowed. Only owner draft list/save RPCs; all direct table access revoked and FORCE RLS/no permissive policies, helper not executable by client roles. SECURITY DEFINER has empty search_path. Public contact toggle is not offered; forced-private database constraint prevents bypass. There is no verification claim or messenger API integration.

Save atomically replaces the list after validating all input. Profile row lock serializes initial and later saves; expected aggregate version rejects stale tabs/replayed saves with PT409 (HTTP409). A lost response may have committed; UI retains inputs and asks reload rather than silently retrying. Empty list clears channels but preserves version header. No old-field conversion/deletion.

Emergency disable candidate after an approved install: revoke EXECUTE on list_my_specialist_channels(uuid), save_my_specialist_channels(uuid,integer,jsonb) FROM authenticated; keep private rows for recovery. Do not DROP tables or roll back unrelated PR31 data. UI already handles unavailable RPC; production application is separate work.

## Link policy
Seven kinds: Telegram, MAX, VK, WhatsApp, OK, website, external portfolio.
- Telegram accepts @name or single direct t.me/telegram.me username; canonical t.me lowercase; service/invite/action/query links rejected.
- WhatsApp accepts explicit +international digits or wa.me/digits, 8–15 digits; no local-number guessing, message payload or query.
- VK/OK accept exact allowlisted HTTPS profile hosts/paths (mobile aliases canonicalized); action/redirect paths denied.
- MAX accepts copied full HTTPS max.ru non-root path without query. No guessed username/phone route: existence and profile semantics are not independently verified.
- Website/portfolio: HTTPS ASCII DNS domain, optional path/query; no credentials, ports, IP/local/test hosts, fragments, punycode/IDN, control characters, backslashes, malformed escapes, dot segments or markup characters. This conservative MVP deliberately excludes some valid real-world links. No HTTP upgrade, URL fetching, redirects resolution, DNS or account verification. External pages can still redirect/change; HTTPS/host validation is not a trust certification.

Both UI and SQL validate, but server is authoritative. Links rendered only from server canonical href, revalidated in UI; labels use DOM text/input.value, never innerHTML. Links use noopener/noreferrer/nofollow/ugc. No contact values logged, no localStorage drafts.

Official references consulted for format guidance, not claims of ownership/existence: https://core.telegram.org/api/links ; https://faq.whatsapp.com/5913398998672934 ; https://m.ok.ru/help/gde-vzyat-ssylku-na-profil?st.pltf=WEB ; https://help.max.ru/help . MAX exact route semantics need service-specific confirmation before widening policy.

## UI and compatibility
Reuse existing Contacts page, editor navigation, company visual styles and specialist helper CSS. No new navigation, All Sections, company files or company RPC changes. Separate collection form so absent RPC cannot disable existing settings. Missing-RPC notice explicitly says channels unavailable; no fake successful save. On failure input stays. Order/remove/preferred/inquiries supported. Company byte/blob comparison is a completion gate.

## Verification and remaining gates
Run npm run test:channels and npm run test:channels:browser. Channels SQL test runs on disposable loopback database named otzovik_acceptance only or embedded PGlite; no hosted credentials. Browser uses RPC transport stub backed by real disposable SQL, external network blocked. CI PostgreSQL test configured; local PGlite serialization does not prove overlapping PostgreSQL transactions. GitHub CI status must be checked separately.

Local channels: 8 security/model groups PASS, 5 SQL-backed browser groups PASS, including seven-kind persistence/reopen, hostile links, duplicates/quota/preferred/publicity/types, foreign/anon/company/child-ID denial, forced RLS with accidental SELECT grant, stale/replayed saves, order/removal, safe DOM, offline input retention, missing RPC fallback, settings independence, 390/1440 overflow.
Hosted creation/saving/reopening NEW channels remains BLOCKED until candidate SQL is reviewed/approved/applied to staging. Do not represent local SQL acceptance as hosted acceptance. Publication, public contact privacy choices, IDN support, account/link verification and broader MAX formats remain separate work.
