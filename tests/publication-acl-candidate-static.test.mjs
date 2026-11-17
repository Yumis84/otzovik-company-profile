import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const sql=await readFile(new URL('../sql/20261117_publication_timeout_acl_REVIEW_CANDIDATE.sql',import.meta.url),'utf8');
test('candidate fails preflight if baseline function is missing before ALTER',()=>{
 assert.match(sql,/to_regprocedure\(signature\)/);assert.match(sql,/IF fn IS NULL THEN RAISE EXCEPTION/);
 assert(sql.indexOf('IF fn IS NULL')<sql.indexOf('ALTER FUNCTION'));
});
test('candidate does not contain a grant, revoke or create function statement',()=>{
 const code=sql.replace(/^\s*--.*$/gm,'');assert.doesNotMatch(code,/\b(?:GRANT|REVOKE|CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION)\b/i);
});
test('candidate checks owner, ACL and effective execute before commit',()=>{
 for(const term of ['p.proowner<>b.proowner','p.proacl IS DISTINCT FROM b.proacl',"'anon'","'authenticated'","'service_role'",'p.proconfig'])assert(sql.includes(term));
 assert(sql.indexOf('Function security drift')<sql.indexOf('COMMIT;'));
});
