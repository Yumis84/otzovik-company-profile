# Specialist MVP acceptance candidate

This candidate collects the server rollout and its provenance for PR #50.
Owner priority is specialist MVP completion. Reputation prototype c53581ed remains a separate next-stage artifact.

## Source and deployment mapping

| Component | Exact source or deployment |
| --- | --- |
| PR #50 head before integration | 9b25c91827a29258d98ec973b50ec5297949641a |
| PR #50 base | f809b76296b4181c1f52d3bee4692f95f3a26312 |
| Work1 tested server/recovery source | 0f77e1b0e5bfc853167376b38329b9596778bf6c |
| Work2 UI runtime | 422edcb77bb696a8033677b821a092f4eed08185 |
| Work2 evidence/report commit | cfabdef8ada5414ed52b1b7ecf55f68d829baafe |
| Accepted composite deployment | dpl_GYFCsaAywSb88yhBbseayxd3JHoo |
| Staging Supabase | salmcnhexlftrgtiryyo |
| Gateway | specialist-media-gateway, version 2, verify_jwt=true |
| Gateway deployed bundle SHA256 | b88ae29159bb639698c30ac88ab437a4de22a08bb457319a84cf4370e5ef5e66 |

Preview origin is https://otzovik-pr51-preview-n99qbj9rv-yumis84-7003s-projects.vercel.app .
The accepted deployment is composite. It is not a deployment of PR #50 head.
The deployed handler is byte-identical to server/specialist-media-gateway.js at the Work1 source above.
staging/recovery/deployed-gateway-index.ts records the exact staging-only adapter with its two approved origins.
edge/specialist-media-gateway/index.ts retains its original environment-based configuration.
This candidate does not change a deployed function.

Work1 source commit order after PR #50 is a49ad28, 763422b, 6420d2b, e9459a1, 01e3df2, 0f77e1b.
The first two commits include specialist UI changes. Work2 must reconcile those overlapping files with its accepted UI before integration.
Do not substitute this older UI for the tested Work2 runtime.
The hosted generator produces install SHA256 771d8007ee18ea87abb4e316b9e62827212c0b9863865ea437be4c27a4e027bd and rollback SHA256 0d537fe2caf1920504655b9daa63d77e26ac09ebb7737ba6e3c3d1c1a172cab6.
These describe the already executed staging rollout. They are not instructions to apply it again.

## Evidence reused without rerunning successful scenarios

| Scope | Evidence and limit |
| --- | --- |
| Auth A login and persisted draft | Work1 prior staging create/save/reload/relogin; Work2 secure A login on accepted composite deployment |
| Foreign B read/edit/delete | Prior real UI denial plus server SQLSTATE 42501, Hub a1c9e997 |
| Media upload/delete | Work1 bb7638db; Work2 999ba51a adds real upload/display/reload and public image delivery |
| Publication persistence | Work2 999ba51a, draft stays private until explicit republish |
| Selected services and contacts | Work2 999ba51a, exactly selected subset public; private phone/email omitted |
| Unpublish and republish | Work2 999ba51a, known public photos become 404 after unpublish |
| Responsive UI | Work2 reports earlier mocked tests at five widths; actual accepted viewport 1363 with no overflow |
| External encrypted backup | Dropbox baseline and rollout archive downloaded, decrypted and checksummed; original 3 files backed up |
| Rollback | Work1 b9e32950, separate 90-rollback.sql in uncommitted transaction |

Work2 fixture 78151a87-a520-4c2a-8c43-947eedd883ad and its selected images must remain available for owner visual review.

## Additional server verification on 27 November 2026

The following checks close post-install evidence gaps without repeating the successful UI cases.

- All 20 specialist tables have ENABLE and FORCE RLS, no anon SELECT and no direct authenticated mutation grants.
- Publication and unpublication RPCs are callable by authenticated users, not anon or service_role.
- Internal media mutation RPCs are callable by service_role, not anon or authenticated.
- Public getter is intentionally anonymous and has an empty search_path.
- Public photo resolver is service_role-only with an empty search_path.
- Actual post-install B role simulation rejected foreign publication state read, publish and unpublish, all SQLSTATE 42501. The enclosing transaction rolled back.
- No uploading/deleting reservations remained. Original file paths still contain 2 + 1 objects. The accepted fixture has a saved publication state.
- Gateway version 2 source was retrieved read-only and matched the recorded handler.

The B check exercises PostgreSQL role and auth.uid semantics. It is not a browser JWT test.
Security advisors report expected definer-function exposure for deliberate RPCs and RLS-without-policy on RPC-only tables.
One mutable-search_path warning concerns the existing company function request_company_profile_publish, outside specialist changes.
Auth leaked-password protection is disabled in staging. This is recorded for production-readiness review; no Auth configuration was changed here.

## Remaining acceptance and integration work

1. Work2 must confirm its exact commit set and resolve overlap against the six Work1 commits above. Hub REQUEST 69f1ccf8 records this coordination.
2. Integrate the candidate server/recovery sources and accepted UI into the agreed branch. Preserve the public-media gateway adapter configuration.
3. Verify the integrated artifact's source/provenance and changed entry points. Earlier results apply only to their recorded sources and deployments.
4. Obtain the outstanding independent SQL/security review and resolve any findings. Historical quota-concurrency failure must have an exact-head real PG17/Edge resolution before full release approval.
5. Keep PR #50 Draft until the integrated source and remaining review evidence are accepted. No production release or merge is included.

No UI/browser tests were rerun for unchanged accepted code. No production data, policies or settings were changed.
