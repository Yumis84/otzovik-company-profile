# Cloudflare cabinet recovery — 22 October 2026

## Verified checkpoint and scope

Owner authorizes a separate test Pages project and staging Worker development, not production Worker/DNS/Supabase schema changes. This supersedes the older VPS plan (Hub42ac0140). No FirstVDS/Jino work.

| Repository | main at inventory | Responsibility |
| --- | --- | --- |
| otzovik-company-profile | 76b3fa7a99df04d320b022a5a777fdbdf897b826 | Static cabinet; explicit public manifest |
| otzovik-profile-worker | b53d5e90130a807b81b05a45a2b4984b41fdc9a4 | Dynamic Worker; immutable v10 baseline; staging only config |
| otzovik-public-profiles | 6d05ad4b1aed7616d02a65c85acfc86c2c448a3a | Existing exported profile snapshots, not cabinet runtime |
| otzovik | a3681aacafaf71c4ec1c1bcc3716d340b0a1b6e9 | Existing site, not a replacement Worker |

PR20 and26 merged. PR23 (69d4bc6), PR24 (250e370), PR25 (bc9a0e5) remain open and are NOT part of this artifact. PR26 leaves account-mobile-swipe.js inert: neither horizontal page gestures nor bottom arrow menu. Upper menu links remain.

Read: Worker AGENTS.md, docs/CHATGPT_HANDOFF.md, README.md, release-manifest.json; cabinet build script and allowlist. No AGENTS.md or WORKSTREAM_SCOPE.md found in cabinet main. Hub context query returned no state for this new recovery workstream. Worker source/header/version records are historical source evidence, not a fresh dashboard deployment attestation.

## Current blockers — no fake deployment

- Cloudflare dashboard redirected to sign-in. Secure login request did not complete. No authenticated Cloudflare access, Pages project creation, Git app permission grant, staging upload or live Worker version inspection happened.
- Consequently there is NO verified pages.dev address yet. The intended project name is a configuration value, not an existing URL.
- Test2 exists as active/ready in Supabase. HTTP probes of production test2, unknown/reserved slugs and staging returned403 without Worker version header from this execution path. Do not interpret that as a Worker response or test PASS. Dashboard/provider-side verification is still required.
- No real Auth user/session was supplied for the test cabinet. No signup, company/profile creation, upload or real user mutation occurred. Existing data was read only.

## Existing Supabase inventory (read only)

Project rzhlcszqtuhkhfibygnk. All inspected public/storage tables have RLS enabled; specialist_profiles and profile_slug_registry additionally FORCE RLS. Those private tables have no direct row policies; their authenticated RPCs check auth.uid(). company_memberships SELECT is scoped to the current user. Company edit/create RPCs are not executable by anon. The legacy six-argument company writer is not executable by authenticated; the current seven-argument writer is. Its body checks active company + verified owner/admin and writes before/after into audit_log.

Company create returns active/ready, a unique shared-registry slug and public_url. It can make data public; use only an explicitly disposable synthetic profile during live testing. Reserved names are rejected. Company descriptions and other fields are replaced together by the seven-argument writer: send all fresh values.

Specialists currently have create_my_specialist_draft, get_my_specialists and update_my_specialist_draft only. Two rows are private draft. No public specialist RPC, services/settings/media RPCs or specialist-media bucket are installed. Existing company-media bucket is private, 5MiB, JPEG/PNG/WebP; owner/admin verified membership scopes Storage INSERT/SELECT/DELETE. Anonymous media SELECT is restricted to published company objects.

Security advisors flag private.phase8a_marker_v1 mutable search_path, disabled leaked-password protection and intentional public/authenticated SECURITY DEFINER APIs. These are findings to review, not permission to alter production. No-policy RLS on private RPC-only tables is fail-closed, not a reason to grant direct access.

## Pages setup after Cloudflare authentication

1. In account Urphin (5e7fdad18984cbc8aac6b06e754efedd), select **Pages**, not Create Worker / Workers Builds. Create isolated project otzovik-cabinet-dev. Reuse existing GitHub app access if sufficient; expanding repository permissions requires explicit approval at that step. Limit access to this repository; never reconnect the static repo to production Worker.
2. Source Yumis84/otzovik-company-profile. Framework None. Repository root. Build `node scripts/build-pages.mjs`; output `_site`; Node24. No server/service-role secrets or bindings. No custom domain/DNS changes. Retain GitHub Pages until owner decides otherwise.
3. Before initial publish run npm ci --ignore-scripts, npm test, npm run test:pages, build and `node scripts/check-cloudflare-pages.mjs`. The readiness workflow validates and uploads ONLY the reviewed static output, with hashes in a separate artifact. It has no Cloudflare credentials/deployment steps and grants contents:read only.
4. Native Pages Git integration generates branch previews, but does not imply GitHub tests have passed. Keep merges owner-approved; publish main only after checks and preview acceptance. No automatic production Worker workflow. If the account requires a paid plan, stop before purchase.
5. Copy the actual deployment address from successful Pages output. Open `/account-login.html` (the existing root index is a public sample profile, not the cabinet). Verify all expected HTML/CSS/JS files and compare hashes with reports/cloudflare-pages-artifact.json. The report itself is NOT published.
6. Supabase signup uses emailRedirectTo on the current site. Verify exact Pages callback allowlist with an operator before a real signup. Changing production Auth URL settings requires separate approval. Do not add wildcard redirects to every preview domain. Password sign-in to existing users does not prove signup email delivery.

Official configuration references: https://developers.cloudflare.com/pages/configuration/build-configuration/ and https://developers.cloudflare.com/pages/configuration/preview-deployments/ . Preview URLs are public by default; this static frontend still connects to the existing production Supabase backend. Calling it a test Pages deployment does NOT isolate its database. Use explicit disposable accounts/data or a separately approved isolated Supabase test project.

## Acceptance and publication boundary

For each result record deployment URL, git SHA, test user alias (no credentials), profile UUID/slug and before/after counts. Registration/email confirmation, password sign-in, logout/session expiry, create company, edit all fields, create service/location, image upload, reload persistence, desktop/mobile and foreign-owner denial must be exercised against the actual Pages deployment. Do not mark them PASS based on local SQL tests. Unknown/reserved/inactive slug, no-media and Supabase error handling require real or isolated fixtures; never deactivate real profiles to test them.

PR23 is a separate dependency: migrate only an approved isolated DB first, then publish its tested editor branch as a Pages preview. Do not merge PR23 or apply its SQL to production as a side effect of Pages setup. A basic specialist draft on current main is not a full editor or published specialist.

Specialist staging requires an approved published-only RPC/snapshot contract and publication gate. Never expose get_my_specialists, draft rows or a service-role key through a public Worker. Preserve src/baseline-v10.js and release-manifest production record. Stage only at the config hostname otzovik-company-profile-staging.urphin.workers.dev under /__staging/<slug>/. Implement shared slug resolution through the existing registry, not a second namespace. No production custom route. Actual staging upload remains blocked by authentication and published specialist contract; do not fabricate a public specialist example from private drafts.

## Rollback and continuation

Pages: retain the previous successful deployment ID and source SHA, then use the project's rollback/redeploy of that exact static artifact. Rolling back static files does not roll back database writes. Stop preview writes independently if needed. Do not restore an old swipe script.

Worker: repository wrapper fixes the staging name and requires ALLOW_OTZOVIK_STAGING_DEPLOY=yes; run npm ci, npm run verify, npm test and npm run dry-run first. Production remains pinned to v10 per historical manifest: version4a362783-ec1e-49a8-b03e-9e057082fd28, recovery deployment b72ccba2-b461-4592-8311-a4ea1934d47d. Do not upload, roll back, purge cache, change traffic, routes, bindings, secrets or Git integration without new production approval.

Next blocking action: authenticated Cloudflare access. Then create Pages, record actual URL and perform live Auth/data acceptance. Separate approval required for production Supabase/Auth changes and eventual production specialist Worker release.
