# Specialist private editor release candidate

Task 6e1cf1f6-693c-4b71-97ef-3eed1a9ba43c. Date2026-10-27.
Status: NO-GO for production release until the explicit gates below; candidate preparation in progress.
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
4. docs/specialist-contact-channels-candidate.sql: channel set/version + rows, normalization/private-only APIs.
scripts/specialist-editor-migration.mjs emits steps1–3 as a transaction for isolated tests only. No executable auto-migration directory. Apply ONLY the exact reviewed hashes after fresh preflight and explicit approval.
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
NO-GO now for production merge/deploy/SQL/publication: backend missing, release audit pending, real-stack result pending, Auth/domain deployment choices unresolved. Public profile publication is a different feature and remains excluded.
Final exact HEAD/CI/run URLs, preview equivalence and audit response are in the final Hub HANDOFF; no pending test is claimed PASS here.
