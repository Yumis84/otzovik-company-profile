import fs from 'node:fs';import {checkCompanyIntegrity} from '../scripts/company-integrity.mjs';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const cwd=new URL('../',import.meta.url),read=p=>fs.readFileSync(new URL(p,cwd));
const manifest=JSON.parse(read('docs/SPECIALIST_GATEWAY_HASHES_2026-10-27.json'));
for(const {file,sha256}of manifest.files){const bytes=read(file).toString('utf8').replace(/\r\n/g,'\n');assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),sha256,file);}
checkCompanyIntegrity(manifest);
assert(!fs.existsSync(new URL('supabase/migrations',cwd)));
console.log('PASS integrity: canonical hashes '+manifest.files.length+', company blobs '+manifest.companySource.files.length+', no automatic migrations');
