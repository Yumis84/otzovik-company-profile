# Specialist Profile V1: database and publication contract (DRAFT, NOT APPLIED)

Issue: https://github.com/Yumis84/otzovik/issues/3
Status: design proposal only. No production migration or changes.

## Verified live state (read-only inspection 2026-10-14)

- Public tables include companies, company_memberships, ownership_claims, reviews and company_profile_publications.
- companies has id UUID, unique slug TEXT, name TEXT, status default active, profile_status default ready; there is no profile_kind column.
- create_my_company and get_my_companies are installed SECURITY DEFINER owned by postgres.
- create_my_company inserts status active/profile_status ready and owner membership verification_status verified, method creator.
- get_my_companies scopes rows to auth.uid().
- ownership_claims authenticated INSERT policy checks auth.uid()=user_id, pending status, empty evidence, verified_at NULL, review_note NULL.
- reviews.company_id is NOT NULL with foreign key to companies.id. This is not directly suitable for independent specialist reviews.
- Actual EXECUTE grants, trigger paths, publisher authorization and complete RPC security review remain **NOT VERIFIED**.

## Proposed additive schema (requires review)

Keep companies and company_memberships unchanged in V1. Rather than insert specialists as fake companies, introduce:

- specialist_profiles: id UUID primary key, owner_user_id UUID NOT NULL, slug TEXT UNIQUE NOT NULL, display_name TEXT NOT NULL, profession TEXT, specialization TEXT, city TEXT, description TEXT, profile_status TEXT NOT NULL DEFAULT 'draft', created_at, updated_at. All profile fields self-declared. No automatic professional verification.
- specialist_publication_consents: specialist_id, owner_user_id, policy_version, consented_at, withdrawn_at, field_allowlist; publication requires current active consent and explicit published state. Keep a versioned consent record; never publish unpublished contact data.
- specialist_credential_verifications: specialist_id, credential_type, status default pending, reviewed_at, reviewer_id. Separate from ownership. Do not imply a verified qualification without evidence.
- specialist_reviews: specialist_id, author_user_id, body, moderation_status default pending, timestamps. Moderation/anti-self-review/report workflow must be designed and tested before enabling writes.

No company link in V1; future many-to-many specialist↔company association must be possible without changing specialist ownership or review identity.

## Proposed RPC boundaries

- create_my_specialist(...): authenticated only, checks auth.uid(), name, slug, collisions with company namespace and reserved slugs; creates draft; never accepts caller-supplied owner ID, verified status or publication status.
- get_my_specialists(): authenticated, returns only own specialists; does not expose other users' drafts.
- get_public_specialist_profile_v1(slug): returns ONLY allowlisted, explicitly consented fields for a published specialist. Must return no data for drafts, withdrawn consent or unpublished profiles.
- publish/unpublish: owner-only, server-validated; remove static artifacts and sitemap entries on unpublish; tombstone/410 policy required. Do not claim full erasure from immutable Git history.

## Publisher contract

- Existing company generator and get_public_company_profile_v2 remain unchanged until separate compatibility tests pass.
- Specialist generator uses ProfilePage with mainEntity Person; self-declared jobTitle/knowsAbout clearly labeled. No aggregateRating/Review JSON-LD for Person.
- Never write raw Supabase response directly to public profile.json; serialize an explicit allowlist.
- Reject unrecognized fields, sensitive data, unconsented media, private object storage keys and internal IDs.

## Acceptance gates

1. Old company cabinet, RPC and public profiles unchanged.
2. Specialist draft can be created without a company and cannot self-verify credentials.
3. A user cannot read/edit another user's draft.
4. A specialist cannot publish without current explicit consent.
5. Consent withdrawal blocks RPC output and triggers removal from current sitemap/artifacts.
6. Slug uniqueness is enforced across the public namespace; reserved/homograph patterns rejected.
7. Specialist reviews are moderated; owner cannot review own profile.
8. Company reviews continue to use existing company_id semantics.
9. Person structured data is valid and excludes unsupported review-rich-result markup.
10. Actual SQL, RLS, grants and publisher checks pass an independent security review before any production rollout.

## Blockers before migration implementation

Read-only inventory of function EXECUTE grants, publisher dispatch authorization, full company RLS interactions and consent deletion behavior. This document is NOT executable SQL and is not a claim of readiness to deploy.
