# Specialist publication: isolation and deployment plan (draft, NO-GO)

This is a plan, not an approved rollout. The existing company site and Joomla must continue serving unchanged. The specialist publication implementation, erasure barrier, audit, independent acceptance, and public host are not complete. Do not enable publication, run hosted SQL, change DNS, certificates, Cloudflare, FirstVDS, or merge based on this document.

## Isolated acceptance

1. Start a disposable Supabase stack with a separate project identity and synthetic users; never import production data or credentials. Verify endpoint addresses and absence of routes to production before loading any SQL candidate. Keep the stack private and ephemeral unless the owner explicitly approves a persistent hosted resource.
2. Load the documented candidate sequence into a disposable database only. Run the company integrity gate, PostgreSQL 16 and 17 test suites and real Auth/JWT, PostgREST, Storage, Edge and browser flows. Test both owners and anonymous access, stale version, concurrent publish/delete/unpublish, replay, rollback, upload reservation RESTRICT, and deletion with/without reservations. Collect exact commit, image versions and run IDs.
3. Prove the public v1 response contains only display name, profession, specialization, city, description and slug. Verify text-only rendering, CSP and `Cache-Control: no-store`; show a warning that descriptions may contain contacts. No media, private paths, contacts, settings, internal owner IDs, or reviews.
4. Validate unknown, draft, suspended, unpublished and erased slugs return the same 404 response, and test invalid Host headers, malformed slugs and request routing. Explicitly test the company site and navigation. Do not assume a successful mock validates Auth, Storage or erasure.
5. Ask Claude to independently review the exact new HEAD and evidence. Remediate P0/P1 and obtain owner decisions on account erasure with outstanding reservations, operator authority, takedown delay, slug retention, backup/PITR and infrastructure trust. Public reviews remain blocked by review-erasure P0.

## Proposed release gates, only after explicit owner approval

- Inspect actual runtime and FirstVDS trust state read-only. Record baseline company endpoints, current TLS certificate chain and expiry, routing, DNS, monitoring, exact package versions and rollback owner. Previous Cloudflare code is not an authoritative baseline.
- Agree on the canonical external host suffix and wildcard certificate strategy; prove certificate coverage and renewal in an approved isolated environment. Route by an exact, normalized single-label Host allowlist backed by the published projection, rejecting unknown/invalid/draft hosts. Do not infer production routes from this plan.
- Prepare and independently review ordered migrations, catalog preflight, postchecks, exact hashes, backup/PITR and tested rollback. Publication control starts disabled. Deploy code and schema separately from activation, only within the approved change window; keep company traffic on its existing verified path.
- Exercise synthetic specialist and existing company profiles via the approved test host. Verify no-store on every layer, TLS and unknown hosts, no private data, erasure and operator suspend, status/latency/error monitoring and measured takedown delay. Only then request a separate decision to enable public projection.

## Rollback and restoration

Before a change, retain approved, tested backups and versioned routing/configuration outside the affected runtime. On an incident, disable specialist public control and route only specialist traffic to the reviewed unavailable response; preserve the existing company path. Restore the previous application and routing configuration only after verification. Never re-enable public projection automatically after backup restore or PITR: reconcile deletions, erasures, tombstones and control status against an independently retained erasure ledger first. If such a ledger or trustworthy restore proof is unavailable, remain disabled and escalate. Verify unknown/erased specialist hosts return 404 and company pages still work after rollback. A rollback must not delete real user data or silently restore erased data.
