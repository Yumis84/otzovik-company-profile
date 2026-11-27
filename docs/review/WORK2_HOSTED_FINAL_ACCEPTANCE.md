# Work2 independent hosted final acceptance
2026-11-27. Plan only: hosted scenarios NOT RUN. Baseline d84be0b1 / evidence c8e719d.
Owner forbids production, Auth resets/settings and duplicate backend development.

## Entry evidence required
Record exact backend/generator/UI SHA, migration package digest, deployment ID, canonical staging origin, allowed public route and CORS. Verify all endpoints target staging salmcnhexlftrgtiryyo; abort production rzhlcszqtuhkhfibygnk. Obtain Work1 catalog-specific package and Claude findings/disposition; fresh-install candidate is not an approved hosted migration. No hosted apply by Work2.

## Independent migration review on isolated copy
1. Obtain provenance/date/schema fingerprint of read-only staging catalog, ordered migrations, dependency inventory and expected before/after objects. Never assume absent native modules imply permission for fabricated empty DTO.
2. Read exact diff against staging catalog. Check preconditions fail before mutations on incompatible catalogs; no Auth, Storage visibility or unrelated ACL rewrites; no company/photo overwrite/drop/truncate; canonical reader signatures and native content retained.
3. On OWN isolated database matching supplied catalog, capture company/service/branch/media row counts and deterministic synthetic fixture hashes, constraints/indexes/triggers/RLS/grants/function signatures. Apply exact candidate with stop-on-error; record errors and transaction boundaries.
4. Compare after state: original rows/photos/object keys unchanged, existing roles retain expected rights, foreign/anon denied, intended owner/member APIs reachable. Check dependency/order and repeated apply behavior against documented contract.
5. Exercise documented rollback on empty and populated publication states; preserve existing company/media/native content and history. Refusal on nonempty state is acceptable only if explicit and leaves all data unchanged. Reapply only when contract permits.
6. Reconcile Claude security findings rather than repeat audit. Findings require exact fix SHA and targeted regression evidence. No hosted GO from local fixture tests alone.

## Hosted scenario matrix
All changes use dedicated synthetic acceptance companies and reversible edits; retain original fixtures/photos. Capture non-secret request outcome, actor identity, entity IDs, before/after values, deployment and evidence reference. Never record JWT/password.

| ID | Actor and action | Required observable result |
| --- | --- | --- |
| H01 | A opens cabinet, creates dedicated company, edits name/city/description, services/prices and branch | Correct company ID throughout; reload retains values; success/error messages agree with server |
| H02 | A uploads synthetic PNG/JPEG avatar and gallery | Actual private Storage/gateway transport succeeds; reload retains photos; public bytes decode; no private token/path exposure |
| H03 | A previews/selects public fields and explicitly requests publication | Consent and field selection honored; RPC attempt UUID is queue ACK only; queued/building/published reflects server |
| H04 | Anonymous opens Work1 supplied canonical staging public URL | Name/services/prices/allowed contacts/photos correct; private/draft fields absent; no fabricated content; direct refresh works |
| H05 | A edits and republishes with new UUID | New revision appears after success; same UUID durable; original photos preserved; stale artifact handling follows contract |
| H06 | Controlled worker failure in isolated staging mechanism authorized by Work1 | Failed state visible; no false success; last valid matching snapshot remains intact; retry new UUID succeeds; never inject faults into production |
| H07 | Dedicated company has known published and draft native reviews, sources/ratings and Q&A | Correct canonical author/response/source/scale/count; draft/foreign/erased content absent; unknown rating not fabricated zero; official answer correct |
| H08 | B securely signs in; verify visible B identifier before writes; accepts existing analyst invite | Correct invitation/company and role; no owner identity substitution; real server session used |
| H09 | B navigates granted company and attempts disallowed mutations | Read and write match exact server role matrix; expected denial leaves rows unchanged; hidden buttons alone insufficient evidence |
| H10 | B targets ungranted second synthetic company via explicit company ID/routes | No fallback to another company; no foreign data or successful mutation; refusal distinguished from network failure |
| H11 | A revokes B membership; B revisits open tab, reloads and attempts denied operation | Live server refuses access; stale UI clears; no late response restores rights; fixtures unchanged |
| H12 | Same integrated build opens existing specialist editor/public route | Narrow compatibility smoke only: correct profile/company navigation, saved photo rendering and no route collision; reuse previous full specialist PASS |
| H13 | Changed publication labels at 320/390/768/1280/1440 widths | Meaningful Cyrillic in all five states/link; no question-mark corruption/overflow; queued is not published; unsafe/unprovided URL has no link |

For H09 obtain exact analyst/admin/employee capability matrix from Work1; do not invent expectations from labels. For H06 prefer existing authorized fault fixture; no new server debug bypass.
For H07 use approved test fixture creation through supported API only; no direct hosted SQL.

## Current blocked checkpoints
B secure request again returned A (visible yumis@bk.ru), not B. No B authentication error established. Normal logout/login only; no resets. H08-H11 NOT RUN.
Chat2 corrected locale SHA/build not received. H13 NOT RUN on corrected source.
Claude result pending. Migration package in preparation per Work1 5a5660b7. Migration review and H01-H07 NOT RUN.
Existing preview is not a deployment of accepted PR56/PR2. Do not present it as final MVP.
Final GO requires actual hosted evidence, real B rights cycle, targeted locale acceptance and closure of confirmed audit findings.
