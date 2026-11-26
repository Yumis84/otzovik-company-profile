# Specialist MVP staging checkpoint

Runtime Git SHA: 422edcb77bb696a8033677b821a092f4eed08185
Branch: ui/chat2-completion-20261125
Related PR: https://github.com/Yumis84/otzovik-company-profile/pull/51
PR51 retains its existing head ui/left-sidebar-shared-20261122 (8e27961); continuation is not merged.

Deployment: dpl_GYFCsaAywSb88yhBbseayxd3JHoo (READY)
Origin: https://otzovik-pr51-preview-n99qbj9rv-yumis84-7003s-projects.vercel.app

## Source provenance

Composite staging artifact, 53 files. Existing deployed cabinet baseline dpl_57xqq2iDm6Ep4v4ktL9EUaxvULr6 preserved by exact Vercel file IDs. Overrides from runtime SHA above: account-create-specialist.html, specialist-public.html, specialist-public.css, specialist-public.js, plus new specialist-public-media.js. Editor URL/key replaced only in build with staging salmcnhexlftrgtiryyo. It would be incorrect to identify the whole composite cabinet with the runtime SHA alone.

## Changes

Published avatar/portfolio use existing gateway POST view=published, slug, photo with public legacy anon JWT in Authorization and apikey. No owner client/session or direct public Storage URL is used. Fetch omits credentials, disables caching, rejects redirects, has timeout/abort and MIME/size checks. Only published photo items are considered. Failed images retain initials or hidden empty gallery; object URLs revoked on cleanup. Actual editor public link uses same-origin specialist-public.html?slug= instead of an unavailable subdomain. Public manifest includes renderer/helper. Existing company design/styles retained.

## Validation

- PASS unit media transport: public credential, POST contract, 404/network/timeout, invalid UUID, unsupported content/empty/oversized blob, disposal race, object URL release.
- PASS actual Edge browser with MOCK responses: 320/390/768/1280/1440, decoded avatar/portfolio, Cyrillic/specialization/service/contact, no horizontal overflow.
- PASS MOCK 404: initials fallback, hidden empty gallery, zero broken images/page errors.
- PASS company integrity: 33 protected files and injected-change rejection.
- PASS publication consent controls, JavaScript syntax, diff whitespace.
- PASS static manifest build: 66 files and resolved static dependencies.
- REAL HTTP200 candidate: cabinet home, editor, services, contacts, media, public HTML, public JS/helper. Home/editor point to staging, no production project reference.
- REAL public getter HTTP200: current approved slug has three service items, no published contact/photo item in this read.
- REAL candidate-origin gateway preflight: HTTP403, Access-Control-Allow-Origin absent.

## Final real acceptance after gateway v2

Supersedes the earlier candidate-origin CORS403 and missing Auth session limitations above. Gateway v2 SHA b88ae29159bb639698c30ac88ab437a4de22a08bb457319a84cf4370e5ef5e66 per Work1 HANDOFF5274f753, verify_jwt=true.

Actual A login completed with secure browserAuth; no credentials read or exported.
Tested approved synthetic draft78151a87-a520-4c2a-8c43-947eedd883ad on the same n99 deployment.

- REAL PASS OPTIONS204, exact candidate Access-Control-Allow-Origin.
- REAL PASS UI upload avatar and portfolio, saved privately, reload persists both. Before explicit publication neither appears publicly.
- REAL PASS explicit publication: both public blob images decoded with naturalWidth>0.
- REAL PASS anonymous gateway POST with public legacy anon JWT only: both photos HTTP200, image/webp, 1834 bytes, no-store, exact CORS origin.
- REAL PASS draft description update remains private until explicit publication; then new description appears.
- REAL PASS unpublish: success message, confirmation unchecked, public profile unavailable.
- REAL PASS direct anonymous gateway access after unpublish: both known photo IDs return404.
- REAL PASS republication with fresh explicit selection/consent: profile and both images reappear.
- REAL PASS synthetic other-link MVP public contact https://example.org/ survives save/reload and is published only when selected.
- REAL PASS selected subset: exactly one selected service and one selected contact; two unselected services absent; private phone/email never selected or exposed.
- REAL PASS current public desktop viewport1363: no horizontal overflow, both images decoded. Five-width responsive tests remain the separately labelled MOCK evidence above.

Final visual acceptance state: published original three services, synthetic public contact and two new synthetic photos. Description retains the explicit MVP update-test suffix. Existing original profiles/photos not deleted. New photo IDs: avatar2d1ed2b8-e2f0-4890-bd6e-6d61efa1b682; portfoliocc70894e-38b8-435f-8c76-2150ea00a2bf. Preserve these test fixtures for owner acceptance.

GO for the tested staging publication/media/update/unpublish/republication acceptance scope. This does not authorize production release, PR merge or alias switch. PR51 head remains unchanged; runtime continuation is in ui/chat2-completion-20261125. No production, SQL, ACL, Storage policy, gateway or alias mutations by Work2.

## Work2 final UI / PR51 preparation, 2026-11-27

- REAL hosted public browser on pinned n99 deployment at320/390/768/1280/1440: scrollWidth equals viewport, both images decoded, three services and one contact, no page errors. 390px screenshot reviewed visually. This supersedes the previous public five-width MOCK-only limitation.
- REAL new synthetic draft a61c712f-5bcc-46ef-819a-dff790e32b0c, slug work2-final-261127: create with name/profession/specialization/city/description, edit and reload persisted; no duplicate creation.
- REAL new service create500-900 RUB, reopen after reload, update to500-1100 RUB, delete that exact newly created service; original services untouched.
- REAL private synthetic email, Online+Visit-client formats, territory and qualifications saved/reloaded on new draft.
- REAL initial publication of new profile shows saved name/specialization, zero public contacts and no private email. Then unpublish; retained new draft for evidence. It consumes the third draft slot.
- MOCK/disposable local UX regression:10 groups PASS, all four cabinet section layouts/menu links at320/390/768/1280/1440, fail-closed foreign/malformed IDs and absent RPC, read failure handling. Mock cases remain distinct from real browser results above.
- Corrected stale publication action label after unpublish; regression now asserts Update vs Publish state. This small change is source-only pending coordinated integrated staging build; do not claim it deployed on n99.
- Company integrity33 and injected-change rejection PASS; diff whitespace PASS.
- Real account home reports invitation load failure. Delegated to Work1 for underlying RPC classification, not hidden by UI.
- Work1 reports exact combined-head quota concurrency evidence unresolved. Full release stays NO-GO until combined acceptance closes it.

Integration: PR51 head8e27961 is ancestor of UI continuation (ahead35/behind0 atcfabdef). Existing PR51 can fast-forward without force or merge to main. Offline merge-tree against backend36e2679 (base9b25c918) yields only two content conflicts: account-create-specialist.html and account-specialist-services.js. Resolve those to Work2 source; preserve backend account-specialist-api.js startup timeout and other backend/SQL/gateway/recovery files. No backend branch changes or hosted SQL by Work2. Hub coordination89e6d0e9.

CI follow-up: gateway-integrity stopped at exactly three intentional UI/test changes (media editor, specialist editor and UX browser test). Refreshed only those canonical pins with original hashes and source80132f6 provenance in uiRevision. All SQL/gateway/company pins unchanged; checker unchanged. Canonical65+company33 PASS; an injected unexpected editor change FAILed as required, then exact bytes restored and guardPASS. Publication/media unit+browser checks added to shared-navigation CI; public browser test now uses Chromium on Linux and Edge on Windows. Full CI status must be read at final PR HEAD, not inferred from local checks.

Combined compatibility follow-up (base d6f0ded8, retaining Work1 erasure fixture and all server pins): editor now rejects malformed acknowledgement UUIDs and a valid UUID belonging to another update context. Startup harness adapted to actual DOM after()/public URL support and selection-key contract; all original17 assertions retained plus new wrong-UUID update test,18/18PASS. Services refresh harness adapted to actual retry DOM/messages,7/7PASS. Canonical65/company33 and publication controlsPASS; public renderer browser5widthPASS on combined UI. No hosted SQL/runtime deployment. Prior bdd CI14/15gateway+navigationPASS; realEdge passed19Auth/Storage/Edgegroups including quota concurrency, then failed publication fixture startup. Work1 fixed missing public-details setup/consent fixture on d6f0ded8; exact newCI remains a required release check. The checked deployed n99 artifact remains separate from latest integrated source.
