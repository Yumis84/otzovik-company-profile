# Specialist Profile V1 — implementation contract (draft)

Status: planning only; no production changes. GitHub issue: https://github.com/Yumis84/otzovik/issues/3

## Owner decisions (2026-10-14)
- Account signup/login stays unchanged.
- In account cabinet, "Add profile" offers "Company" or "Individual specialist".
- Specialist is independent; optional links to one or more companies are postponed until after V1.
- Existing company profiles, company IDs, RPCs, URLs and permissions must continue to work.
- Specialist reviews are desired in V1, but only after moderation/complaints/self-review controls.

## Verified code entry points
- `account-home.html` currently renders "Мои компании", calls `get_my_companies`, and links to `account-create-company.html`.
- `account-create-company.html` currently calls `create_my_company(p_name,p_slug,p_website,p_phone,p_city,p_email)`.
- `otzovik-company-subdomain-corrective-migration.sql` defines `create_my_company` with membership `verification_status='verified', verification_method='creator'`. This proves repository SQL, NOT current production schema.
- Public profile generator lives in `Yumis84/otzovik-public-profiles/scripts/render-profile.py`.

## Implementation sequence / gates
1. Read-only audit of actual Supabase schema, RLS, grants, RPCs, memberships, publication workflow. Compare live database to repository SQL; record VERIFIED/NOT CHECKED.
2. Define minimal additive schema: profile_kind company/specialist; specialist_details; publication consent; explicit professional credential verification. Do not reuse creator ownership as credential verification.
3. Add cabinet profile-kind choice in feature branch; keep existing company creation behavior unchanged. Do not enable specialist creation until server-side RPC and permissions exist.
4. Add specialist RPC + owner-only edit path with deny-by-default checks; draft status initially; no implicit verified credential.
5. Add privacy allowlist, active consent, publish/unpublish/tombstone, static generator Person/ProfilePage metadata; preserve company markup and contracts.
6. Add moderated reviews for specialist with self-review prevention and complaints.
7. Acceptance tests: legacy company regression, account with company+specialist, cross-user write denied, unverified credentials labeled correctly, no publication without consent, unpublish removes PII from current tree/sitemap, no Person review-rich-result JSON-LD.

## Future non-V1 design constraint
Allow later many-to-many specialist↔company association with confirmation from both sides, revocation and role/type of association. This is not ownership, membership or delegated edit permission. No company foreign key required to create a specialist.

## Explicit restrictions
No production writes, DNS/VDS changes, Cloudflare Worker, migration apply, or merge to main without explicit approval. Claude review in Hub OTZOVIK task d93efda1-50e1-426d-8cc1-0ee616422c18 is read-only and live Supabase was NOT CHECKED.
