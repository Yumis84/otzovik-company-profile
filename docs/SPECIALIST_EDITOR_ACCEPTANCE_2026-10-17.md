# Specialist editor: services, private media and contacts

Scope: `feature/specialist-editor-navigation-v1`, based on `a9e57a4`; Claude critical HANDOFF `03aa8503-dd0a-4ccc-94dd-bbd3e0608100` is the architecture constraint. Company pages, company context keys, company RPCs and routing are unchanged.

## Implemented

Separate specialist services/contact/media pages share only new pure UI helpers and styles. Navigation requires an explicit validated specialist UUID and verified ownership; the context key is `active_profile={kind:'specialist',id}`. Missing/foreign/company IDs fail closed. Creation does not activate section links until a draft exists. Unimplemented sections remain disabled.

- `specialist_services`: private name/description, price range/currency, duration, availability, version; owner-scoped list/save/delete RPCs; 50 services per profile, serialized profile lock, optimistic version checks. Client-generated service UUID prevents duplicate rows on ambiguous retries.
- `specialist_settings`: private contacts, HTTPS website, online/studio/onsite formats, city/region service area, self-declared qualifications. Contact visibility is constrained to private, no exact home address or verified badge. Version check prevents stale overwrites.
- `specialist_media`: private avatar/portfolio metadata with separate bucket `specialist-media`, 5 MiB limit and JPEG/PNG/WebP allowlist. One avatar and 20 objects/profile, including interrupted uploads. Storage policy checks specialist owner, draft status, typed UUID paths and operation. No company membership lookup or company bucket. No anonymous policy. Client decodes/resizes images to WebP and renders authenticated downloads as blob URLs; no public URLs or signed links are displayed. Interrupted files can be explicitly cleaned up.
- Lifecycle: at most 10 drafts per user, serialized creation; explicit owner delete RPC releases slug via existing registry trigger and cascades editor records. Deletion is refused until all private files (including interrupted uploads) are removed. No automatic deletion, publication or slug changes.

## Migration and rollback

**Candidates only, not applied to production.** Existing specialist draft schema is prerequisite. Generate one transaction without a database connection:

```sh
node scripts/specialist-editor-migration.mjs > /tmp/specialist-editor.sql
```

It includes editor, media and lifecycle candidates in order. Trusted BYPASSRLS owner required; table FORCE RLS, no direct client table grants, narrow SECURITY DEFINER RPCs with empty search_path. Storage uses narrow owner-check helpers. Existing bucket causes migration refusal rather than silently changing its privacy. No production config/bucket was changed.

Deploy only after final-SHA CI, independent review and explicit owner approval. Recheck base schema/functions/bucket absence and archive definitions/grants first. Apply atomically in isolated staging, validate two users and company regressions, then request production GO. Rollback: restore previous frontend and apply the reviewed `sql/20261017_specialist_editor_DISABLE_CANDIDATE.sql`: remove specialist Storage policies first, then revoke editor/lifecycle/helper EXECUTE in the same transaction; retain tables, objects and slug registry. Do not drop data. Restore the previous create-draft function only from a verified snapshot if reverting the quota, with explicit approval.

## Verification

`npm run test:editor`: 7 SQL/security groups pass locally using PGlite and a minimal Storage table fixture. Tests cover owner/foreign/anonymous and cross-kind denial, direct table denial, stale versions, private defaults, bounds, quota, MIME metadata, avatar uniqueness, cleanup-before-delete and slug release. Static tests reject company RPC/context/bucket use in specialist modules and dynamic innerHTML rendering.

Pages builds 58 explicit public files; artifact checks pass. Existing company files remain byte-identical to the branch baseline. Existing SQL regression suite and browser suite are rerun in CI. The LOCAL Supabase workflow additionally applies these exact candidates to a real disposable PostgreSQL17/Auth/PostgREST/Storage stack and runs two-user Storage and specialist UI checks; final results must be read on the final SHA, not inferred from the PGlite fixture.

## Limits and release gates

- No public specialist snapshot, publisher, reviews, AI consultant, bookings, billing, domain/routing changes or employee/branch model was added.
- Private signed Storage links are bearer capabilities if an owner creates one independently. Foreign users cannot mint links; possession of an already valid signed URL is not prevented by RLS. The UI avoids signed URLs and uses authenticated downloads.
- Bucket MIME checks enforce declared types and size; they are not malware/content scanning or server image decoding. Public publication requires separate moderation/content validation and privacy review.
- Local email confirmation is real SMTP to Mailpit, not hosted email deliverability. Hosted gateway/CDN/publisher acceptance remains separate.
- Owner approval remains required for production SQL/Storage policies, merge/main and frontend release. No production mutation or unfinished feature publication was performed.

## Read-only production preflight

A metadata-only SELECT confirmed: base specialist draft table exists, all three editor tables and the new specialist bucket are absent. No user rows were read and no production writes were performed. This is an existence check, not deployment authorization. Recheck all prerequisites immediately before an approved deployment.

## CI evidence

Implementation `4270e055064edb278790077a10a03e5612e297e1` passed [LOCAL Supabase run 39061826797](https://github.com/Yumis84/otzovik-company-profile/actions/runs/39061826797): 13 real groups, including both specialist Storage/owner/cross-kind checks and browser service/contact/portfolio save/reload. [Regression run 39061826778](https://github.com/Yumis84/otzovik-company-profile/actions/runs/39061826778) passed 15 PostgreSQL groups, 12 browser groups, 7 editor security groups and 58-file artifact checks. Logs were inspected. Follow-up adds an explicit non-destructive editor-disable regression to verify company Storage still works; check final-SHA CI in the PR for its result.
