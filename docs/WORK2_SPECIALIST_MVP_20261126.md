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

## Blockers / NO-GO

Authenticated create/edit/reload, selected contacts publication, update/unpublish/republish and real positive photos are not verified on this deployment. No authorized A browser session is available in this run; test credential environment is unset. Work1 must coordinate gateway CORS for this exact origin and confirm photo item schema/positive synthetic photo fixture. Do not switch stable alias until ready. Alias, gateway, ACL, SQL, Storage, production and existing user data were not changed. These mock/static checks are not real server E2E.
