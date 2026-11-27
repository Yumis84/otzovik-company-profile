# Company invitation restoration candidate

Status is REVIEW ONLY. PR #50 remains pinned to 932dbda75f9bb6ec91c6e2ea85b0f0ffc97d19d8.
This separate candidate was not installed on any hosted project.

## Diagnosis

The existing cabinet calls get_my_pending_company_invitations on startup. On staging salmcnhexlftrgtiryyo the entire company invitation module is absent. The canonical table name is company_access_invitations. Earlier notes checking company_invitations used the wrong name; the corrected exact-name check also confirms absence.

The existing company_memberships table and get_my_companies RPC are present. UI suppression or an empty-result stub would hide this missing dependency.

A read-only catalog inspection of the existing otzovik project recovered the real schema, constraints, indexes, ACL and seven RPC definitions. No application records, auth records, invitation tokens or secrets were exported. source-snapshot.json contains that catalog evidence. The snapshot is an existing implementation reference and requires security review before reuse.

## Confirmed recipient-check defect

The existing UUID acceptance function reads the authenticated user's email and checks lower(invitation.email) <> user_email. For NULL user_email the IF condition is NULL, so execution continues. The token-based acceptance function already explicitly rejects NULL email.

A disposable PGlite fixture containing the exact original UUID function reproduced accepted status for a synthetic user with NULL email. That test transaction rolled back. The corrected UUID function rejects missing/blank email and uses IS DISTINCT FROM. The corrected fixture then passed recipient, role, expiration and repetition tests.

This establishes the function-level defect. Production exploitability and affected historical data were not investigated. No live invitation was accepted or changed.

## Proposed restoration

01-candidate.sql restores the observed table, original constraints and pending-email unique index, seven existing RPC contracts and their observed authenticated/service-role execution grants. RLS is enabled and direct anon/authenticated table access is denied, matching the observed module. Functions use an empty search_path and explicitly qualify extensions.digest. Only the UUID acceptance function adds the recipient validation correction.

The package has no automatic migration hook. It changes a company schema and RPC access rights if committed on staging. The existing session rule requires explicit owner consent for system-affecting ACL/schema changes. The current request authorizes preparation and fixes within scope, so this package remains an isolated review candidate. A hosted installation needs the approved company-module scope and independent review; no additional condition is imposed on unrelated specialist acceptance.

Before installation, verify the target ref salmcnhexlftrgtiryyo, existing companies/memberships/auth dependencies, extension availability, absence of the seven target RPCs and an empty/absent invitation module. Compare the source snapshot to the intended contract. The email delivery Edge function and company member-management RPCs are outside this package. Existing-user invitations and the cabinet list are the proposed first acceptance boundary.

90-rollback.sql removes only this new module and refuses to run while invitation data exists. It performs no CASCADE. Later real invitation/member activity requires a data-preserving recovery plan.

## Validation

Run node tests/company-invitations-review.mjs with the repository's pinned @electric-sql/pglite development dependency installed. The test is fully disposable and contains no network endpoint or credentials.

11 regression groups PASS. They cover original NULL-email reproduction and corrected rejection, foreign recipients, owner/role restrictions, recipient-only listing, anonymous/direct-table denial, expiration, decline/revoke, single acceptance, RPC search_path/grants and refusal to discard rows during rollback.

The fixture uses PGlite with pgcrypto and simplified company/auth dependencies. Hosted Auth, concurrent membership acceptance, email delivery and the full existing company access UI remain unverified for this candidate. Existing specialist tests were not repeated.

## GO / NO-GO

GO for independent review of this isolated candidate.
NO-GO for installation or production release pending scope approval, audit and target integration checks.
The specialist PR's existing green CI remains valid for its exact source. It does not certify this separate invitation candidate.

## Owner authorization and supplemental rollback evidence

Owner decision 9ca92460-1c05-49d7-a6ed-cf97cf3fb7b1 authorizes restoration of candidate abb113e on staging salmcnhexlftrgtiryyo and necessary module-only ACL changes AFTER independent audit. It supersedes the earlier missing-scope-approval blocker. Independent audit is still pending in task fc27169a-e4f1-4730-868a-bab23d6c27f8; no installation has occurred.

The SQL candidate, rollback and source snapshot are byte-identical to abb113e. Only this review note and the disposable regression test have changed. The original eleven scenarios were rerun as part of the extended test, because the same fixture now also exercises the token contract and destructive rollback boundary.

All 14 disposable groups PASS. Added cases demonstrate foreign/missing-email token rejection, matching-token acceptance within a rolled-back transaction, and successful empty-module removal. The successful rollback removes all seven module RPCs and its table while preserving the fixture's companies and memberships exactly. The existing rollback guard still refuses to remove a nonempty invitation table.

These checks are local PGlite evidence. Hosted staging installation, actual JWT/API invitation flows and hosted rollback rehearsal remain pending the independent audit. Production data and configuration are outside the authorization.
