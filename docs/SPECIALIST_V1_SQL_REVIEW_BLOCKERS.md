# Specialist V1 candidate SQL: review blockers and acceptance

Candidate: `sql/20261014_specialist_drafts_candidate.sql`
Status: NOT APPLIED, NOT APPROVED FOR PRODUCTION.

## Critical blocker: shared slug namespace
The draft RPC checks `companies.slug` before inserting a specialist. However the existing live `create_my_company` RPC does not check `specialist_profiles.slug`. The two tables also lack a shared unique constraint. Therefore:
- A company could later claim a specialist slug.
- Concurrent company/specialist creation can race even if both RPCs perform SELECT checks.

**Do not apply candidate migration until** a cross-type reservation/unique-slug mechanism is designed and tested atomically, and the company creation path is updated compatibly. Do not silently change company slug suffix semantics.

## Other blockers
- Check actual EXECUTE grants, publication dispatch and RLS with production-equivalent roles.
- Confirm new SECURITY DEFINER functions are owned by a suitable role with intended table privileges, and that auth.uid() semantics are preserved.
- Ensure public data and consent are not accessible through unintended RPCs.
- Verify no preexisting specialist-like tables/functions and no slug collisions in live data.
- Decide whether a specialist can have more than one independent profile; current candidate permits it.
- Explicitly review CASCADE delete of specialists on auth user deletion against audit/retention requirements.
- Consider input limits and normalization for profession, specialization, city.
- Verify SQL in a disposable test database and perform rollback rehearsal.

## Test matrix
1. Anonymous caller cannot execute create/list.
2. Authenticated user creates a draft, receives own id and draft status.
3. Other user cannot list/read the draft.
4. Direct INSERT/UPDATE/DELETE by authenticated client denied.
5. Reserved slugs, xn-- prefix, malformed slugs denied.
6. Collision with existing company denied.
7. Collision with newly created specialist denied.
8. Concurrent cross-type collision denied by database constraint, not only SELECT checks.
9. Existing create_my_company/get_my_companies unaffected.
10. No public profile, sitemap, media, review or Person JSON-LD emitted for draft.
11. Revoked consent and unpublish tested before any publish capability is added.

## Review decision
**FAIL / HOLD for deployment** until shared slug uniqueness and permissions tests pass. The candidate is useful for code review, not for applying as-is.
