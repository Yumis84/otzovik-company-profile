import assert from 'node:assert/strict';import fs from 'node:fs';import cp from 'node:child_process';import {approvedCompanyVersion,checkCompanyBytes,checkCompanyIntegrity} from '../scripts/company-integrity.mjs';
const root=new URL('../',import.meta.url),manifest=JSON.parse(fs.readFileSync(new URL('../docs/SPECIALIST_GATEWAY_HASHES_2026-10-27.json',import.meta.url)));
checkCompanyIntegrity(manifest);
for(const file of ['account-company-context.js','account-profile.css','account-profile.html']){
 const base=cp.execFileSync('git',['show',manifest.basis+':'+file],{cwd:root,encoding:'utf8'}),approved=approvedCompanyVersion(file,base);
 checkCompanyBytes(file,base,approved);assert.throws(()=>checkCompanyBytes(file,base,approved+'\n/* unexpected change */'),/Unexpected company change/);
}
console.log('PASS company guard rejects injected changes in both permitted paths and an unchanged path');
