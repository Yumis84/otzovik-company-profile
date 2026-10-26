# Specialist next phase — audit and implementation design

Date: 2026-10-26 (Kaliningrad). Status: PROPOSAL / NO MIGRATION AUTHORIZATION.
REQUEST 611cb6fd-52b6-4308-801a-30631069d642; owner decision 0789632b-652e-4961-aee0-fe5a64a3b454.
This is PR A: documentation only, based on PR34 HEAD 693446dff47bb1335c43104cb37ed47931134700.
No executable migration, application change, hosted write, deployment or publication is included.

## 1. Authority and evidence

Read Hub PR33 HANDOFF 16e9a9ee, PR34 a2324636, Claude audit ece8bd6b and its detailed FYI 4db9d9bb; owner decision takes precedence over audit suggestions.
Hub project_context_get returned state=null and no shared memories; scoped memory_search for PROJECT_STATE / AGENTS.md / WORKSTREAM_SCOPE.md returned none. These named documents were not available, not assumed to exist or reconstructed as facts. Repository and relevant ancestor paths contain no AGENTS.md; no WORKSTREAM_SCOPE/PROJECT_STATE tracked in this checkout. Current REQUEST and decisions are the effective bounded scope.
GitHub issue #22 and existing SPECIALIST_PUBLICATION_PHASE2_PROPOSAL.md confirm publication is a separate gated workstream. No minimum-description/photo/contact thresholds, verification labels or public-contact switch are authorized here.
Current code: account-specialist-services.js, account-specialist-media.js, account-create-specialist.html; hosted function definitions and catalog metadata reviewed independently.
Evidence snapshot: SPECIALIST_NEXT_PHASE_PREFLIGHT_2026-10-26.json. No contacts, names, emails, object paths, credentials or user row payloads collected.

## 2. Fresh GitHub verification

All five PRs are OPEN DRAFT, unmerged, mergeable=true / clean at inspection. Main remains 76b3fa7a99df04d320b022a5a777fdbdf897b826.

| PR | Actual HEAD | Current base | Current HEAD workflow result |
| --- | --- | --- | --- |
| #30 | b382174a12c4cb6cbed35ded3cf66e6657483f6a | main | SUCCESS 39775765433, 39775761046 |
| #31 | c0a97c00450da75f039837a938c76a671fcd775f | main | SUCCESS 39815318297, 39815318277 |
| #32 | 9b3d2d829e30a00852a6773a0cff8e2684deaa42 | PR31 branch | SUCCESS 39963536654 |
| #33 | 2fd81f07bf30aced6d47c1e84a9182ef3232c2e7 | PR32 branch | SUCCESS 39974927824 |
| #34 | 693446dff47bb1335c43104cb37ed47931134700 | PR33 branch | SUCCESS 39984915671 |

PR34's previously pending final CI is now completed SUCCESS, verified at GitHub, not inferred from the earlier runtime commit.
Runs for PR33/34 were executed against integration base PR31 before retargeting. Same HEADs; do not describe these as fresh automatic runs against current stacked bases.
PR31 already includes PR30 prerequisite; do not merge overlapping PR30/31 blindly. Resolve release sequencing separately after owner approval. PR29 is not a source/base.
Workflow currently triggers only main and PR31 branch. PR A will retain final base PR34 and will not retarget or alter workflows merely to obtain a docs CI badge. Run relevant local evidence checks instead.
Canonical links: https://github.com/Yumis84/otzovik-company-profile/pull/30 through /34; action URLs use /actions/runs/<ID>.

## 3. Staging read-only preflight

Project salmcnhexlftrgtiryyo = otzovik-specialist-staging, ACTIVE_HEALTHY, PostgreSQL 17.11.0.003. Production not queried.
Six tables: specialist_profiles, specialist_services, specialist_settings, specialist_media, specialist_channel_sets, specialist_contact_channels. All ENABLE + FORCE RLS.
No direct anon/authenticated/PUBLIC table grants were returned; no public-table policies. Access is via owner RPC, not browser direct tables.
17 specialist-named functions: 16 SECURITY DEFINER owner/helper functions and one internal normalizer. All fixed empty search_path; anon EXECUTE false for all; authenticated true for 16, false for internal normalizer. DEFINER must retain explicit auth.uid()+owner+draft checks; FORCE RLS alone does not constrain a privileged function owner.
Profile table has no numeric CAS version. update_my_specialist_draft changes name/profession/specialization/city/description with owner+draft predicate; get_my_specialists builds explicit JSON keys (new columns will NOT automatically appear).
Services have version default1; existing writer locks parent then service and rejects stale with PT409. Settings have a separate version and aggregate save. Channels have a separate channel-set version. No proposed service/year/project update may call or rewrite settings/channels.
Service bounds: nullable numeric price_from/to, each present amount 0..100000000, to>=from when both; RUB/USD/EUR; duration1..1440 nullable; max50 services via writer. Legacy schema permits from-only, to-only and both-null. Both-null is NOT evidence of negotiated pricing.
Aggregate-only scan: 4 service rows, all RUB and both bounds present. Other valid legacy shapes still require synthetic coverage; no row values exported.
Media: id, specialist_id, unique object_name, kind avatar|portfolio, caption<=500, created_at. No order, CAS, project id or photo-rights record. One-avatar unique partial index. FKs cascade from specialist profile.
Private specialist-media bucket: 5MiB/object, JPEG/PNG/WebP. Three authenticated-only policies SELECT/INSERT/DELETE; no UPDATE/upsert. All storage policies inspected: other bucket company-media policies are explicitly bucket-scoped.
can_upload_specialist_object takes advisory lock specialist-media:<profile>, counts ALL objects under profile prefix (including avatar and unregistered uploads), max20; parent owner+draft pinned. Paths stay <profile>/portfolio/<uuid>.webp etc.
register_my_specialist_media locks parent, validates ownership/kind/path and uploaded object's size/MIME, upserts metadata by object_name. It does not validate image contents or photo rights.
delete_my_specialist_media removes metadata only. Existing UI deletes Storage object FIRST then metadata. This is a critical integration point: adding a restrictive project FK alone is insufficient because old UI could delete the bytes first.
delete_my_specialist_draft takes media advisory lock then parent FOR UPDATE, refuses while Storage objects remain. All project/media mutations must use the SAME advisory-lock-before-parent order to avoid deadlocks with upload/delete.
Shared slug registry trigger exists; no change proposed. pg_depend inspected for keys/indexes/trigger dependencies; PL/pgSQL textual calls are not a complete catalog dependency graph, hence explicit function-body review above.

## 4. PR B: price mode and unit

Add nullable specialist_services.price_mode text and price_unit text. Do not backfill units or label historical rows negotiated.
Allowed units: service (за услугу), hour (час), lesson (занятие), day (день), square_meter (м²), project (проект).
NULL unit means not specified, including historical records. UI default service only for NEW services; do not silently assign it while editing an old record.
Modes: NULL = legacy unspecified mode; priced; negotiated; unspecified. New v2 writes always explicit.
- legacy NULL: retain existing nullable-bound semantics and currency exactly. Read projection: amounts present => priced, otherwise unspecified; preserve raw null for compatibility.
- priced: at least one finite bound; each present 0..100000000; ordered if both. Equal bounds = exact; from-only => «от», to-only => «до». No arbitrary two-decimal restriction on old values.
- negotiated: both bounds NULL. Unit may be selected but does not imply a monetary amount.
- unspecified: both bounds NULL; distinct from explicit «по договорённости».
A price-unit choice never derives duration; currency stays RUB by default only on new records, existing USD/EUR remain selectable and unchanged. No currency conversion.
CHECK must use explicit IS NULL predicates; SQL three-valued logic must not accidentally accept priced+both-null or reject valid legacy rows. Reject NaN/infinities before numeric comparisons.

New RPC (separate name, no default-overload ambiguity):
save_my_specialist_service_v2(p_specialist_id uuid,p_service_id uuid,p_name text,p_description text,p_price_mode text,p_price_unit text,p_price_from numeric,p_price_to numeric,p_currency text,p_duration_minutes integer,p_is_active boolean,p_version integer) -> full JSON row.
Read get_my_specialist_services already serializes full row; additive fields are compatible with current JS. A dedicated capability read (or v2 endpoint presence established by deployment manifest) gates the new UI; never silently retry a failed v2 save through v1.
Preserve the exact v1 signature, grants and JSON existing keys. V1 compatibility wrapper must lock and CAS exactly as before:
- new legacy client insert => price_mode NULL, unit NULL;
- existing write preserves unit; if prices are unchanged, preserve mode (including negotiated);
- if bounds change, infer priced when any bound, unspecified when none; do not infer negotiated;
- increment version ONCE per committed save, not twice through nested wrappers.
Common validation/core in an internal non-exposed helper; every exposed wrapper independently checks auth/owner/draft. PT409/40001 handled by existing conflict UX; use PT409 canonical.
Legacy UI cannot express unit/negotiated: it may show old «цена не указана». This is a known presentation limitation, not lossless semantic support. Updating numeric values in an old tab is an explicit pricing edit; mode changes with those values and version protects stale tabs.
Never clear numeric input on mode toggle without preserving local unsaved values or a clear prompt. Send incompatible mode+amount as validation error rather than silently discard amounts.

## 5. PR C: optional practice start year

Add specialist_profiles.start_year smallint NULL and start_year_version integer NOT NULL DEFAULT0.
Use separate get_my_specialist_experience(p_specialist_id uuid) -> {start_year,version,server_year}, and save_my_specialist_experience(p_specialist_id uuid,p_start_year integer,p_version integer) -> same payload.
Why separate: legacy profile writer has no CAS and get_my_specialists has explicit key projection. Reusing settings would create an unrelated aggregate writer and partial-save risk.
RPC locks parent, owner+draft check, exact version match; changes only start_year/start_year_version (plus updated_at). Blank clears to NULL; integer only, proposed lower bound1900, upper bound current server year in Europe/Kaliningrad. Lower bound is a proposal, not an approved product restriction; no birth date/minimum age.
Static CHECK year NULL or1900..9999 plus version>=0; time-dependent upper validation belongs in RPC, not an immutable CHECK with current date.
UI in existing Profile section, compact optional field with independent explicit «Сохранить год начала работы» and independent state. Main Save MUST NOT claim that this separate operation saved. No best-effort two-RPC combined save. If owner wants a single Profile save, design atomic profile-v2 with a full profile CAS in a later explicit decision.
Create retains existing minimal fields; optional year can be set only after successful creation. Legacy profile saves do not touch year. No verification claim; never increment stored years annually.
API only emits owner-private data; display «Работает с <year>» may be proposed for future public snapshot, not implemented now.

## 6. PR D: project cards and safe media relationship

Add specialist_portfolio_projects:
id uuid PK (client supplied for retry), specialist_id uuid FK profiles ON DELETE CASCADE, title text trimmed1..150, description text nullable<=2000, sort_order integer0..999, version integer>=1, created_at/updated_at.
UNIQUE(id,specialist_id) supports composite links. No unique sort_order: stable order (sort_order,id), list reorder under collection CAS avoids uniqueness swaps.
Add specialist_portfolio_sets(specialist_id PK/FK CASCADE,version integer>=0 default0) for create/delete/reorder aggregate CAS.
Add specialist_portfolio_project_media(project_id,specialist_id,media_id,sort_order):
PK(project_id,media_id), UNIQUE(media_id) so one photo belongs to at most one card, UNIQUE(project_id,sort_order); composite FK(project_id,specialist_id) -> projects; composite FK(media_id,specialist_id) -> media, requiring additive UNIQUE(media.id,specialist_id).
Project delete cascades LINKS only; media deletion cascades LINKS and bumps affected project/list versions through a reviewed trigger. Parent profile deletion cascades all. Reject attaching avatar even when same owner; enforce kind=portfolio in RPC under lock (composite FK alone cannot enforce kind). Cross-profile attachments rejected even for the SAME owner.
Existing portfolio images remain ungrouped; do not invent projects or duplicate files. Old Photos page continues listing every original media row. New UI shows cards plus «Фото без проекта» inside the existing Photos/Portfolio page. No navigation changes.
Proposed limits for approval: <=20 cards/profile; 0..10 photos/card; existing20 total files/profile retained, including avatar/orphans. These are capacity ceilings, not required content. Text-only cards valid; no quota increase.
Reorder RPC consumes complete expected ID set, rejects duplicates/missing/foreign IDs, uses collection version, updates order atomically; all mutations use profile media advisory lock then parent row then collection/project/media rows in deterministic UUID order.
New owner-only RPC names:
get_my_specialist_portfolio(p_specialist_id);
save_my_specialist_portfolio_project(p_specialist_id,p_project_id,p_version,p_collection_version,p_title,p_description,p_media_items jsonb);
reorder_my_specialist_portfolio(p_specialist_id,p_collection_version,p_project_ids jsonb);
delete_my_specialist_portfolio_project(p_specialist_id,p_project_id,p_version,p_collection_version).
p_media_items is an ordered array of {media_id,rights_basis?}; omitted rights_basis preserves existing declaration on updates, explicit null clears it, server stamps only a new/changed declaration. Invalid or duplicate items abort the entire call. Create requires project version NULL; update exact version. Successful mutation returns row + fresh collection version; no storage bytes are manipulated in a DB transaction.
Retry after unknown commit: reread by client UUID, reconcile payload/version; do not automatically overwrite after conflict or create duplicate cards.

### Deletion compatibility is a release gate

Preferred compatibility policy: old owner deletion of a linked photo remains allowed, automatically detaches it, bumps affected project/list versions and leaves the text card. New project UI explains this behavior. Do not introduce RESTRICT that strands metadata after old UI removed bytes.
Storage delete policy remains unchanged; bytes can disappear before DB metadata. New reads treat unavailable photo as missing and keep card editable, never call it a successfully loaded photo.
New UI delete operation still has partial states: Storage-first then metadata, with retry metadata if bytes already absent. CAS project edits cannot guarantee atomicity with old Storage API; explicitly test removal-vs-save races. Broken-link reconciliation removes links and bumps versions in owner RPC when confirmed missing, not by exposing Storage paths.
Deleting a card removes card+links ONLY, preserves shared/unassigned media bytes and existing Photos use. Deleting photos requires separate explicit confirmation. No background destructive purge or new paid worker.
Existing explicit cleanup handles unregistered uploads. Do not define orphan as «not linked to a project»: registered ungrouped photos are valid and must never be cleaned as orphans.
Storage and database are not one transaction: upload -> register media -> attach in one atomic project RPC. If attach fails, media remains private/unassigned; show retry/choose-existing. If register fails, keep existing unfinished-upload cleanup. Parent/delete/upload races must follow existing advisory lock order.

### Photo rights

Propose optional self-declared record on project-media link: rights_basis NULL|author|permission, rights_declared_at server time. Not a verification or public consent certificate. Legacy photos stay unknown; do not backfill declarations. No mandatory checkbox/upload block without owner decision. If shared on media instead, that is a separate reviewed contract change.
Do not collect passports, client names, permissions documents or domestic addresses. Future publication must separately assess personal images and public rights; private attachment is not publication consent.

## 7. RLS, APIs, dependency review

New tables ENABLE+FORCE RLS; no browser direct grants; no anon read/write policies. Owner reads/writes only through reviewed DEFINER RPC with fixed empty search_path and explicit auth.uid()+owner+draft checks. REVOKE EXECUTE FROM PUBLIC,anon; GRANT authenticated only named owner APIs; internal helpers not executable by authenticated. No user_metadata-based authorization.
Do not alter specialist-media bucket/policies for this design. Keep path namespace private; no signed URLs or owner identifiers in Hub/public JSON.
Additive schema does not authorize publication. Existing company tables/functions, slug registry, channels/settings, publisher, profile_status and workflows untouched.
Versioned price writer needs an approved v1-body change. PR D also must patch the EXISTING delete_my_specialist_media body to acquire the media advisory lock BEFORE its parent row lock, keeping the signature/return/authorization and metadata-only behavior. Otherwise a new link-deletion trigger acquiring the advisory lock after legacy parent locking would invert lock order and risk deadlock. Trigger bodies use the already-acquired ordering and bump versions without re-entering RPCs. Project link-version triggers and reconciler are additional reviewed backend changes, not silently «just new tables».
Inspect dependency by both catalog AND source call graph, including old clients' delete order. Snapshot exact function definitions and grants privately before approved rollout; migration rollback must restore definitions, not guessed candidates. Existing candidate files differ from hosted PT409 behavior; do not replay blindly.

## 8. Migration and rollback sequence (proposed, not SQL)

Each PR supplies reviewed local up/down candidates after owner authorization. No generated migration timestamps or executable SQL supplied in PR A.

| PR | Up sequence after approval | Safe rollback |
| --- | --- | --- |
| A audit/design | Docs and synthetic contract cases; no DB/runtime | Revert docs only |
| B prices | Add nullable mode/unit and constraints; internal validation + v2; compatible v1 wrapper; reload API schema cache through approved release process; old/new clients tests; deploy UI separately | Roll back UI first, disable new writes; retain additive columns/data and compatible wrapper. Exact down only if all extended values exported and owner approves loss; restore v1 before dropping columns/functions in reverse dependency order |
| C year | Add year+version; bounded/CAS get/save RPC; separate UI after backend verification | Hide year UI; keep data/RPC. Destructive down only approved export, remove new RPC then columns; legacy profile functions unchanged |
| D projects | Add composite media unique, project/set/link tables + indexes, private rights metadata, RLS/grants, link-version triggers, owner RPC/reconciler; race tests; existing-page UI | Revert UI first; keep tables/data, triggers while writes possible. Disable project writes through approved release; export card text/order/links, drop RPC/triggers/links/projects/sets/composite key only after dependency check. Existing bytes/media untouched |

Do schema changes in short transaction with lock_timeout/statement_timeout; on timeout rollback, no retry storm. Add/validate constraints in safe phases if tables grow; first measure row count/locks. No old data rewrite needed for nullable price/year fields.
Staging rollout gate: approved migration commit+target ref+backup/rollback+independent audit; single controlled apply; catalog diff and old/new smoke tests. Production is a separate explicit release decision, never inherited from staging approval.
Capabilities/readiness: endpoint unavailable => show new field unavailable, preserve old editor operation, no silent dropping of new values. Backend before frontend. Feature rollback is data-preserving by default.

## 9. Required acceptance before B/C/D release

| Area | Required scenarios |
| --- | --- |
| Old rows | null/null, from-only, to-only, exact, range, zero, valid fractional prices, RUB/USD/EUR; null unit/mode not rewritten; old JSON keys intact |
| Service writes | each unit/mode; negotiated vs unspecified distinct; incompatible bounds reject without partial update; v1 numeric edit mapping; unchanged negotiated preserved; stale v1/v2 writers, duplicate retry, limit50 |
| Year | NULL/clear,1900/server-year edges, future/negative/decimal/non-number; stale CAS, year-rollover timezone; legacy profile Save preserves year; one independent save fails without false combined success |
| Cards | text-only, multiple photos, stable reorder; duplicate/missing IDs; attachment same owner OTHER profile denied; avatar denied; quota10/card and20/global, avatar+orphan accounting |
| Partial failures | upload fails; register fails; attach fails; commit response lost; card deletion leaves photos; Storage succeeds+metadata fails; already-missing object retry; linked photo deleted by old UI; orphan cleanup excludes valid unassigned media |
| Concurrency | real PostgreSQL simultaneous v1/v2 saves, reorder/create/delete, attach/media-delete, upload/profile-delete; stale list/project versions; consistent advisory/parent lock order; no deadlocks/leaks |
| Security | owner vs other owner vs same owner other profile, anon, direct tables, internal helpers, role grants, forced RLS, draft-only; XSS titles/captions rendered textContent; no private fields in public snapshot |
| UI | existing five links, save/reopen, progressive optional fields, offline/error/retry,320/390/1440 no overflow, keyboard/focus errors, currencies preserved |
| Regression | PR32 contacts/partial-save/privacy, PR33 saved UX, PR34 saved overview; all33 company files committed blobs AND working bytes identical; workflows/public build manifest unchanged |

Local reference cases in this PR's validation exercise design semantics only; they do NOT prove future SQL, hosted security or concurrency. Fresh current-head CI above proves existing code baseline. No actual hosted create/update/delete tests run during this read-only phase.

## 10. Decisions and release gates

Product direction (units, negotiated, optional start year, multi-photo cards, RUB default preserving USD/EUR) is approved.
Separate approval needed before: concrete B/C/D hosted SQL/DDL/function-body/grant/trigger changes; year1900 lower bound and independent save UX; card/photo/text ceilings; optional photo-rights semantics; staging rollout and production rollout separately.
No Storage ACL expansion proposed; if later required, stop and seek explicit approval. No education move, published-edit contract, publication requirements, verification, reviews, AI/billing or paid resources in this phase.
Ready next: prepare PR B implementation in isolation after model review; do not apply schema merely because this document was merged or acknowledged.

## References

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/guides/storage/management/delete-objects
- https://github.com/Yumis84/otzovik-company-profile/issues/22
Supabase changelog.md fetch attempted: search renderer rejected text/markdown content type; current RLS/Storage official docs read. No new Supabase feature was implemented on assumptions.
