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
