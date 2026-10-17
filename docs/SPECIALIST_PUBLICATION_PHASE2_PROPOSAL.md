# Specialist public profile: phase 2 design (proposal)

Status: DESIGN ONLY. No production SQL or publication changes in this document.

## Existing baseline

- PR #20 merged into main as 18016d392a7f18352720ac6f197d56550cb344c9.
- Private specialist drafts live in public.specialist_profiles; access via authenticated create_my_specialist_draft, get_my_specialists, update_my_specialist_draft RPCs.
- Shared profile_slug_registry prevents collisions with company slugs.
- Public company publisher architecture separates source/private data from otzovik-public-profiles (static output).
- User verified the deployed specialist form works on 2026-10-17.

## Publication model

1. Draft is private by default. Neither a new draft nor an edited draft is automatically published.
2. Owner explicitly requests publication after seeing a preview of exactly the public fields.
3. Trusted backend validates ownership and publishability, records an auditable publication revision, and produces a public-only snapshot. An anonymous client must never read private draft records.
4. Static publisher fetches the canonical *public* snapshot through a trusted interface and writes sanitized HTML plus profile.json to the public-output repository.
5. Unpublish immediately revokes the public snapshot at the canonical layer and enqueues removal of static artifacts. UI must explain that static mirrors and search caches may persist until deletion completes.
6. Publication is asynchronous; maintain pending/failed/published statuses and retryable, idempotent jobs. Never claim publication succeeded merely because the DB mutation succeeded.

## Public contract proposal

Public identity: profile_type='specialist', slug, display_name, profession, specialization, city, description, published_at, updated_at, profile_version, human_profile_url. Only explicitly approved media IDs and public derivatives may be included.

Do not expose: owner_user_id, email, private phone, private Storage paths, signed URLs, auth tokens, internal moderation notes, private draft history. No fabricated reviews, ratings, verification badge or company association.

## Acceptance

- Owner can preview, publish, edit a new revision, and unpublish their own profile.
- Other authenticated users and anon cannot list/read/edit private drafts or publish another owner's profile.
- Slug collision across specialist/company rejected in concurrent requests.
- No XSS in HTML/JSON/metadata; strict escaping and URL validation.
- Unpublished slug has no public canonical payload, and static output is removed on retryable job completion.
- Company profile routes and publisher remain unchanged.
- Local Auth + PostgREST + browser tests pass before production migration.

## Release gates

Separate migration PR and frontend/publisher PR. Review SECURITY DEFINER ownership, GRANT/REVOKE, FORCE RLS, publication race conditions and rollback. Do not deploy production SQL or merge without independent audit and explicit release approval.

Tracks #22.
