import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const sql = await readFile(new URL('./otzovik-company-subdomain-atomic-migration.sql', import.meta.url), 'utf8');
assert.match(sql, /MIGRATION DRAFT ONLY: do not apply automatically/);
assert.match(sql, /create or replace function public\.create_my_company/);
assert.match(sql, /create or replace function public\.get_my_companies/);
for (const name of ['www', 'api', 'admin', 'test', 'test2']) assert.match(sql, new RegExp(`'${name}'`));
assert.match(sql, /companies_slug_key/);
assert.match(sql, /unique_violation/);
assert.match(sql, /public_url.*xn--b1ajuq0c\.com/);
assert.match(sql, /company_memberships/);
assert.match(sql, /audit_log/);
assert.match(sql, /revoke all on function public\.create_my_company/);
assert.match(sql, /grant execute on function public\.create_my_company[\s\S]*to authenticated/);
assert.match(sql, /grant execute on function public\.get_my_companies\(\) to authenticated/);
console.log('subdomain migration structure: PASS');
