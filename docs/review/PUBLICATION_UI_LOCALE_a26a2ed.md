# Publication UI independent acceptance — a26a2ed

Role: Work2 acceptance; ChatGPT2 branch/source not edited.

Exact subject: a26a2ed0b0969d3a13ac20aa43b4f2d587f6a96a.
Module SHA256: c2ad2467e4bbe09978ecc48d36711a787b2f1d1fbcda5676b27b1b51fbfb7140.
Original test SHA256: 19733fb13b9b6af030cc83085a9750bf0eda001ee38f15f6091b43260a2fa0bd.
Both committed UTF-8 blobs contain zero Cyrillic codepoints; labels are literal ASCII question-mark runs. This is not terminal encoding.

Original tests/company-publication-ui.mjs passes because expectations repeat the corrupted strings. Independent tests/publication-ui-locale-acceptance.mjs fails all six checks: queued/building/published/failed/unknown labels and public link text.

Reproduce after exporting exact module bytes via git show into a temporary module directory with package.json type=module:

    node tests/publication-ui-locale-acceptance.mjs /absolute/path/to/account-company-publication-ui.js

Expected on a26a2ed: nonzero exit, six false checks. This is a confirmed defect, not a general test-suite regression.
ChatGPT2 requested to fix UTF-8 labels and add corruption detection (Hub be09b075). Reaccept only the corrected component; do not repeat unrelated successful suites.
Component remains unwired pending Work1 status/retry/public URL contract. No protected UI, guard, server, SQL, Auth, ACL or production changes by Work2.
