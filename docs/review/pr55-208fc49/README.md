# PR55 guard proposal — pending independent review
Target source208fc49, baseline PR53 d1585cd. No live guard or pinned manifest is changed by this package.
Apply the nine exact replacements in JSON over the existing PR53 approvedCompanyVersion output, each requiring a unique old anchor, then verify target SHA256. No regex/prefix/file exemption is proposed.
R1-R8 describe explicit authentication/RPC context hygiene. R9 isolates optional logo errors. Broad outer catch intentionally does not clear stored context on transient import/network failure.
Independent reviewer must inspect final exact bytes and approve the narrow transformation before the integrity gate changes. Recompute the guard module own canonical pin only after approved implementation; keep protected file list, basis, shared navigation SHA unchanged.
Run: node tests/pr55-guard-proposal.mjs
This proves exact reconstruction and rejection of altered anchors/extra bytes, not hosted JWT authorization.
P3 silent fallback to first owned company remains pre-existing and outside this proposal. Runtime layout/styles unchanged from PR53.
