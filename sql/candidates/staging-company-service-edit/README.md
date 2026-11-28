# Staging cabinet server integration

Target project is `salmcnhexlftrgtiryyo`. This directory is outside automatic migrations.

## Standalone company service edit

`01-apply.sql` is the byte-exact Work №1 candidate from Hub `cc69e9ce`, SHA-256 `95aa37d3c73c8e25cf9c425b66df22f1928837a4a9d97558487a110a61119410`. Work №1 recorded the PostgreSQL rehearsal in `762fdec4`. Installation creates one function and its grants in one transaction. It does not call the function, modify table rows or install a trigger. Confirm that the exact signature is absent and that company_services, company_memberships, audit_log and auth.uid() match the reviewed contract before applying. Afterwards, check authenticated EXECUTE and anon denial. Roll back the installation with `90-rollback.sql` (RESTRICT). Earlier legitimate edits and audit entries are preserved.

The current cabinet commit calls create/manage/list services. An edit UI must call `update_my_company_service` with the selected company ID, service ID, name, category and description and validate both IDs in the acknowledgement.

## Dependent changes

| Capability | Source and dependency |
| --- | --- |
| Company reviews and publication status | Existing sibling package `staging-company-integration`, Work №1 `f9dc40d`. Follow its immutable checksums and runbook: read-only 00, apply 10 then 20 then 30, rollback 90. Apply only when the current catalog, backups and data-preserving rollback are confirmed. The reviews UI uses both `get_public_company_profile_v2(p_slug)` and `get_my_company_client_content(p_company_id)`. |
| Specialist activity | Work №1 Hub `9d946d37`, candidate SHA-256 `ec71f4d4e9ad082996a92f49c418aa99c06b6d8870f12024373d4f4c19cb8656`. The source bytes were unavailable to this session. The editor needs an `is_active` boolean from the existing status getter and `set_my_specialist_activity_v1(p_specialist_id,p_is_active)`. Preserve slug/revision; the public shell, router and photo visibility need compatible behavior before activation. |
| Company photo unpublish | The media screen calls `unpublish_my_company_media(p_company_id,p_storage_object_name)`. That signature is absent on staging and a Work №1 SQL definition was not found in the company package. Preserve Storage bytes until the database confirms removal from publication. |

Keep production outside the apply and rollback scope.
