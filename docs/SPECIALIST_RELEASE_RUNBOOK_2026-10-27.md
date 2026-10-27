> Historical PR37 report. Superseded for server deployment by SPECIALIST_GATEWAY_RUNBOOK_2026-10-27.md in PR38. Do not apply the old managed-trigger package.

# Specialist private editor release candidate

Task 6e1cf1f6-693c-4b71-97ef-3eed1a9ba43c. Date2026-10-27.
Status: NO-GO for production release until the explicit gates below; candidate assembled; exact final CI and independent audit status recorded in Hub.
No main merge, hosted SQL/CRUD, DNS/Worker change or publication is authorized by this document.

## Verified source map

Fresh GitHub PR metadata/HEAD/CI and read-only schema evidence:
SPECIALIST_RELEASE_PREFLIGHT_2026-10-27.json (no user rows or secrets).

Release branch is created from main76b3fa7a99df04d320b022a5a777fdbdf897b826.
PR30 b382174a is an ancestor of PR31 c0a97c00. PR31 -> PR32 9b3d2d82 -> PR33 2fd81f07 -> PR34 693446df.
The NET tree change of this chain is squashed once onto main; do not merge/cherry-pick PR30 separately afterwards.
PR35 documentation and PR36 pricing mode/unit/new SQL are excluded. Service price bounds/currency/duration use the existing v1 contract.
PR17 superseded chooser prototype; PR20 already merged; PR23 old editor source selectively reused by PR31; PR24/25 AI are separate scope, not included. PR29 is not a release base and is not imported.
Existing company shell, styling, routes and 33 legacy account files are preserved. Specialist uses its accepted five-link context adapter and shared company CSS. No new independent cabinet or All sections navigation. This is NOT a claim that PR29's proposed unified-JS extraction has shipped; that refactor is excluded to preserve company behavior.

## Readiness matrix

| Area | Candidate | Staging catalog | Production catalog | Release gate |
| --- | --- | --- | --- | --- |
| Auth/signup/login | Existing shared account-login | Email enabled, signup disabled, confirmation required | Email enabled, signup enabled, autoconfirm | Local real Auth test; hosted mail delivery not inferred |
| Chooser/home Edit entry | Existing shared chooser/home, editor restored from chain | Client preview available | Main has basic entry/editor | Explicit home-to-edit and route tests |
| Profile identity/description | PR30+33 stay-in-editor UX | create/get/update present | create/get/update present | Slug collision/private ownership; production create differs from staging quota hardening |
| Services | v1 CRUD, amount bounds/RUB USD EUR/duration | table + RPCs/version present | ABSENT | Reviewed editor server package required |
| Avatar/portfolio photos | Private upload/optimize/register/read/delete | media table + private5MiB bucket +3 policies | ABSENT | Reviewed Storage/server package required |
| Phone/email/site/work | Private settings/formats/territory/qualifications | table + versioned aggregate RPC | ABSENT | Reviewed editor server package required |
| Messengers/social/custom links | Fixed optional fields + named links, private | channel tables + versioned RPCs | ABSENT | Channel candidate required |
| Saved overview | Read-only confirmed saved facts | Reads existing functions | Dependent reads unavailable, show unknown | Never equate errors to empty data |
| Price units/negotiated | EXCLUDED PR36 | Not applied | Not applied | Separate release/SQL decision |
| Start year/project cards/publication/AI | EXCLUDED | Not implemented here | Not implemented here | Separate product/release decisions |

Production has only specialist_profiles (ENABLE+FORCE RLS, no browser direct grants) and3owner RPCs. Staging has6tables/17functions and private specialist-media. Missing in production:5tables,14functions/helpers,privatebucket and policies. Existing get/update definitions match staging; create definition differs (quota/lifecycle hardening). No production data copied.
Auth site_url=http://localhost:3000 and uri_allow_list empty in both environments. Do NOT silently change these. Current production autoconfirm avoids confirmation redirect for new email signups, but recovery/confirmation policy and actual domain allowlist require a separate owner-reviewed Auth configuration decision. Staging signup intentionally disabled; never bypass it for a demo.
Profile core writer has no CAS in the current contract; concurrent base-profile edits are last-write-wins. Services/settings/channels use separate CAS versions. Do not claim profile text writes have atomic conflict protection. Adding profile CAS requires separate reviewed server work; log this risk for acceptance.

## Deployment facts and previews

Canonical test project otzovik-cabinet-dev still points to2f71b889-361b-4d6c-8097-e18257a428fe/sourcePR29e74a42bf. It is NOT the candidate.
Latest existing isolated preview: https://53545278.otzovik-cabinet-dev.pages.dev (sourcePR34 693446df), staging-only artifact config. Candidate runtime is derived from that accepted PR34 tree; compare exact runtime asset bytes before claiming equivalence.
Working GitHub Pages account-home.html returned200 and a specialist edit entry during read-only check. Main source remains76b3fa7. The branded domain fetch failed from this device; DNS/Worker routing is UNKNOWN, not repaired here.
No canonical deployment, domain, Worker, Auth settings or DB is changed in preparation.

## Defects and corrections

P0 deployment blocker: missing production services/settings/media/channels infrastructure. Not patched on hosted systems; exact candidate dependency package and separate apply gate below.
P1 test defect fixed: full local-stack browser expected redirect after profile update; current accepted UX stays in editor. Test now waits for confirmed save and exercises Home -> specialist Edit.
P1 integration gap fixed in disposable stack: channel candidate was not loaded by full-stack harness. Load it only into fresh local test DB before testing fixed messenger inputs.
P1 test data defect fixed: old contact browser fixture used a non-phone string. Use a synthetic valid number; contacts roundtrip must be genuine.
P1 route/fallback acceptance: expand to320/390/768/1440, every menu link keeps profile id, home edit returns to the correct editor; missing editor RPC disables Save and shows a readable status.
P2 profile core CAS gap and production Auth redirect configuration remain documented. No invented verification/publication/ready percentage.

## CI and isolated tests

Existing SQL/channel workflows use PostgreSQL17. Dedicated release browser uses actual PostgreSQL17 RPC fixtures with simulated Auth/Storage. Full local Supabase workflow uses real Auth, PostgREST, Storage, local confirmation mail and browser/company regression, configuration explicitlyPG17.
No Docker executable is available on Yumis-pc. Do not label fixture tests as real Auth; the GitHub disposable Supabase job must supply that evidence or remain BLOCKED.
All DB fixture setup/migrations run only in disposable local/CI environments. Never link Supabase CLI to a hosted ref.
Pin SDK2.115.0 / CLI2.121.0 and existing lockfile; no dependency upgrades.
Company gate: all33 current-main company/account blobs AND working file bytes must match. No pricing candidate or supabase/migrations directory may enter this release.

## Exact proposed server package (NOT APPLIED)

Dependency: existing production PR20 profile/slug registry and3RPCs, verified read-only.
1. sql/20261017_specialist_editor_CANDIDATE.sql: services/settings, owner APIs, FORCE RLS/private grants.
2. sql/20261017_specialist_media_CANDIDATE.sql: privatebucket/media/Storage ownership helpers and policies.
3. sql/20261017_specialist_lifecycle_CANDIDATE.sql: quota/lifecycle/create/delete and media lock hardening.
4. sql/20261027_specialist_storage_integrity_CANDIDATE.sql: separately reviewed actual-INSERT guard for quota/deletion races (managed Storage trigger; extra deployment gate).
5. docs/specialist-contact-channels-candidate.sql: channel set/version + rows, normalization/private-only APIs.
scripts/specialist-editor-migration.mjs emits steps 1 through 4 as a transaction for ISOLATED TESTS ONLY. No auto-migration directory. Hosted application requires separate review and explicit permission.
The source candidates use legacy40001 conflict codes in places, staging definitions usePT409; UI handles both. Do not overwrite hosted definitions blindly to make hashes match. A future apply package must reconcile this documented drift and be independently reviewed.
The lifecycle candidate replaces existing create RPC body; this is a real production server change, not merely new tables. No PR36 price-mode/unit/v2 API is a prerequisite.

## Integration procedure after separate GO

1. Freeze exact candidate HEAD/artifact hashes and independent audit result. Confirm clean tree/current main and33-file gate. Capture existing deployed artifact, main SHA and routing configuration.
2. Take approved database backup/restore point and private definitions+ACL/policies/bucket snapshot. Audit row counts/locks without copying personal rows; maintenance window/no concurrent writes.
3. Obtain explicit server-package permission with exact files/hashes/target, including create replacement and Auth/domain decisions. Apply once in a short bounded transaction where possible. No auto db push/repair/retry.
4. Verify tables/constraints/indexes, FORCE RLS, owner checks, empty search_path, effective PUBLIC/anon/auth grants, bucket limits/policies and company function/policy invariance. Refresh PostgREST cache through approved procedure.
5. Real Auth/PostgREST/Storage owner/foreign/anon smoke using disposable synthetic records. Verify conflicts, cleanup, old clients and company create/edit/service/media/access. On failure stop before UI rollout.
6. Obtain separate frontend publish permission. Publish the reviewed allowlist artifact through the existing deployment path; no DNS/Worker redesign. Confirm clean URLs and .html links retain query ids and login next.
7. Post-publish smoke: login, chooser, create -> saved editor, Home Edit, all menus, service CRUD, contact/channel roundtrip, avatar/portfolio, reload/relogin, missing-function states, mobile sizes. Confirm no private profile publication.
8. Monitor failures; do not interpret a queued deployment or successful DB mutation as a successful release.

## Rollback / disable

Frontend rollback: restore the exact previous complete reviewed artifact/main76b3fa7 through the existing deployment mechanism after owner permission. This restores basic profile editing and removes advanced routes; company bytes unchanged.
For temporary UI disable without touching company, replace only the specialist editor route HTMLs with an explicit unavailable page linking Home in a separately approved artifact; never hide errors behind a fake Save. Existing cached clients may persist: UI rollback is not server revocation.
Backend rollback is DATA-PRESERVING: leave private tables/files/new fields intact. Existing editor DISABLE/ENABLE candidates are reference plans requiring fresh review/permission; they do not cover every channel endpoint, so do not run them as a complete release kill switch.
Do not DROP tables/bucket/objects or CASCADE away records. A complete emergency revoke plan must enumerate service/settings/media/channel/helper EXECUTE grants and Storage helper dependencies from fresh snapshot, preserve core/company APIs, be isolated-tested and independently approved.
There is no automatically safe destructive DOWN once real data exist. Restoring old UI and retaining server data is preferred; restoration of definitions/grants only from the approved snapshot.

## GO / NO-GO

GO for isolated candidate testing only.
CONDITIONAL GO for a future private-editor frontend rollout only after backend prerequisites, exact-HEAD CI, real local-stack results, independent audit, artifact/routing checks and explicit owner release permissions.
NO-GO now for production merge/deploy/SQL/publication: backend missing, new Storage guard approval/audit pending, Auth/domain deployment choices unresolved. Public profile publication is a different feature and remains excluded.
Final exact HEAD/CI/run URLs, preview equivalence and audit response are in the final Hub HANDOFF; no pending test is claimed PASS here.

## Real-stack finding and additional server gate

CI40457929239 on bde46714 reproduced a P1: two real Storage API uploads at19objects both succeeded (21total). A lock in the RLS permission helper did not enforce the final insertion boundary. The original SQL package MUST NOT be released as a hard20-object quota.
The new integrity CANDIDATE enforces quota/path/draft existence on actual INSERT under the same per-profile advisory lock as draft deletion. It returns immediately for other buckets, keeps all company policies/grants untouched and exposes no callable browser helper. Isolated unit checks include privileged insertion denial; real Storage race is repeated three times at19objects. No hosted trigger or function was installed.
IMPORTANT: this candidate requires managed storage.objects TRIGGER privilege and must fail rather than changing ownership/grants. Supabase recommends treating its managed schema as read-only (https://supabase.com/docs/guides/storage/schema/design). This is an ARCHITECTURE/DEPLOYMENT BLOCKER until independent review and explicit owner approval; evaluate an app-owned reservation/upload gateway if managed triggers are rejected. A green disposable superuser test does not prove hosted deployment privilege or long-term managed-schema compatibility.
Production baseline lacks14functions relative to staging; the new guard adds one further function and trigger absent from BOTH hosted environments. Do not describe the five-file package as a copy of staging or a previously approved migration.
UI rollback leaves this guard/data in place. Removing it is a separate reviewed action because it reopens the quota race; do not DROP/CASCADE metadata or objects. The existing DISABLE/ENABLE tests cover their original subset, not complete channel revocation.

## Verification and preview evidence

Local native PostgreSQL17.11:15draft/concurrency groups,9editor/security groups,9channel groups PASS; SQL fixtures do not simulate real Auth. Local UX10groups PASS includes all menu destinations/home Edit/disabled missing-RPC Save at320/390/768/1440. Pages60 manifest/byte/traversal/symlink checks PASS.
All33 company/account source blobs and on-disk bytes equal main76b3fa7. All60 public manifest source files equal PR34 693446df. No PR35/36 source or auto-migration directory.
Existing PR34 preview53545278:60public routes/assets returned HTTP200 using clean HTML routes; no production Supabase reference detected. Deployment intentionally rewrites endpoints/public keys to staging, bundles SDK into supabase-client.js (HTTP200) and injects CSP. It is NOT a byte-identical deployment of this PR; source runtime matches PR34, but new SQL guard is NOT applied to staging and cannot be demonstrated there. No hosted write tests or new deployment were performed. Canonical dev URL still points to PR29.
Independent Claude review requested through Hub eventfd38a605, updated by47723dad with new storage finding. Until a new Claude HANDOFF exists, audit status is PENDING, never PASS.

## Exact missing production components

Tables: `specialist_channel_sets`, `specialist_contact_channels`, `specialist_services`, `specialist_settings`, `specialist_media`.

Functions absent relative to the staging catalog (identity arguments are in the preflight JSON):

- `can_manage_specialist_object`
- `can_upload_specialist_object`
- `delete_my_specialist_draft`
- `delete_my_specialist_media`
- `delete_my_specialist_service`
- `get_my_specialist_media`
- `get_my_specialist_services`
- `get_my_specialist_settings`
- `list_my_specialist_channels`
- `register_my_specialist_media`
- `save_my_specialist_channels`
- `save_my_specialist_service`
- `save_my_specialist_settings`
- `specialist_channel_normalize`

Additional release-only candidate: `enforce_specialist_object_integrity()` + `storage.objects` INSERT trigger. No hosted environment has this guard.

## Completed disposable full-stack acceptance

Source HEAD b931431d6458cacdcb6f46bc28140c6c7da18437: all four CI workflows PASS. Real Supabase run https://github.com/Yumis84/otzovik-company-profile/actions/runs/40458581239 completed SUCCESS:18groups, real Auth/Mailpit confirmation/JWT/PostgREST/Storage/browser; three repetitions of final-slot upload race; company create/edit/branch/service/photo regression; private specialist absent from publisher sentinel; original partial disable/enable checks. SQL/fixture browser runs40458581242,40458581241,40458581228 SUCCESS.
The final evidence/documentation commit also asserts actual server_version_num17 in the full stack. Its exact final HEAD/CI URLs are recorded in Hub after completion; source-SHA results above are not silently relabeled as final-SHA CI.
Hosted email deliverability, real production publisher/CDN/Worker routes and hosted signed-in writes were NOT tested; production remained read-only. Private profile publisher in the local harness is a SQL sentinel, not the production publisher.

## Remaining priorities and release decision

P0 rollout blocker: production prerequisites absent. P1 rollout blocker: new actual-INSERT quota guard needs managed-schema/deployability/independent review (or a separately designed app-owned reservation gateway); it has never been approved/applied hosted. P1 release gate: independent Claude HANDOFF pending (REQUEST fd38a605, FYI47723dad).
P2: profile core last-write-wins without CAS, Auth redirects/domain routing decision, source-vs-staging40001/PT409 drift, real hosted mail/CDN/Worker smoke. Treat these explicitly in owner acceptance; no silent schema/RPC/Auth changes.
GO: isolated candidate and repeatable tests. NO-GO: production release now. Completion of preparation documents these blockers; it does not grant deployment permission.
