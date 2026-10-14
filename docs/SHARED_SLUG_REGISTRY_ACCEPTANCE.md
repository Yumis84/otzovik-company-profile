# Shared slug registry: deployment review checklist

Candidate: `sql/20261014_shared_slug_registry_candidate.sql`
Status: NOT APPLIED. Requires independent SQL/security review and isolated DB acceptance.

## Why
`companies.slug` and `specialist_profiles.slug` are independently UNIQUE, so a simple SELECT collision check is race-prone. The registry's primary key enforces atomic cross-type uniqueness.

## Deployment prerequisites
1. Freeze concurrent company/profile creation during backfill or acquire explicit transaction-scoped locks on the affected tables before copying slugs. **Current candidate does not acquire these locks**, so do not deploy it as-is.
2. Verify trigger owner and SECURITY DEFINER permissions. Ensure direct clients cannot write the registry.
3. Confirm company RPC's unique_violation retry handles collisions raised by the trigger and does not loop beyond slug-length bound.
4. Check slug changes and deletion/reuse policy: whether deleting an old profile should release its public URL or preserve a permanent tombstone. Current candidate releases on DELETE; this may be unacceptable for reputation/impersonation safety.
5. Confirm the app's DNS/publication routing resolves profile type unambiguously and that legacy company subdomains continue to resolve.
6. Test transactional rollback on conflicts during backfill; verify no existing company slug is overwritten.

## Acceptance scenarios
- Existing companies backfilled exactly once; no mismatched reservations.
- New company vs existing specialist slug: company creation suffixes or fails cleanly, never steals slug.
- New specialist vs existing company slug: specialist creation fails without data mutation.
- Two concurrent creations (company/company, specialist/specialist, cross-type) cannot share a slug.
- Slug rename reserves new name atomically and releases old only per approved policy.
- Trigger exceptions roll back both profile row and reservation.
- No registry SELECT/INSERT/UPDATE/DELETE privileges for anon/authenticated.
- Re-running migration is idempotent only after reviewing trigger lifecycle and consistency.
- Existing company RPC signatures and get_public_company_profile_v2 output unchanged.

**Review gate: HOLD.** These are code candidates, not validated migrations.
