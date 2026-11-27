import fs from 'node:fs';import cp from 'node:child_process';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {approvedCompanyVersion,checkCompanyBytes} from '../scripts/company-integrity.mjs';
const root=new URL('../',import.meta.url),read=p=>fs.readFileSync(new URL(p,root),'utf8'),git=(...args)=>cp.execFileSync('git',args,{cwd:root,encoding:'utf8'});
const p=JSON.parse(read('docs/review/pr55-208fc49/exact-transformations.json')),hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const base=git('show',p.baseline_commit+':'+p.file),target=git('show',p.target_source_commit+':'+p.file);
function transform(input,edits=p.replacements){assert.equal(hash(input),p.baseline_sha256,'Unapproved baseline');for(const r of edits){assert.equal(input.split(r.old).length,2,'Nonunique/missing anchor '+r.id);input=input.replace(r.old,r.new);}assert.equal(hash(input),p.target_sha256,'Unapproved result');return input;}
assert.equal(p.replacements.length,9);assert.equal(Buffer.byteLength(target),p.target_bytes);assert.equal(transform(base),target);
for(let i=0;i<p.replacements.length;i++){
 const altered=structuredClone(p.replacements);altered[i].old+='/* injected */';assert.throws(()=>transform(base,altered),/anchor/);
 const mutation=structuredClone(p.replacements);mutation[i].new+='/* injected */';assert.throws(()=>transform(base,mutation),/anchor|Unapproved result/);
}
assert.throws(()=>transform(base+'\n/* injected */'),/baseline/);
assert.notEqual(hash(target+'\n/* injected */'),p.target_sha256);
const manifest=JSON.parse(read('docs/SPECIALIST_GATEWAY_HASHES_2026-10-27.json'));
assert.equal(approvedCompanyVersion(p.file,git('show',manifest.basis+':'+p.file)),base,'Proposal starts from current approved guard output');
assert.throws(()=>checkCompanyBytes(p.file,git('show',manifest.basis+':'+p.file),target),/Unexpected company change/,'Live gate must remain closed before approval');
for(const f of manifest.companySource.files.filter(f=>f!==p.file))assert.equal(git('show',p.baseline_commit+':'+f),git('show',p.target_source_commit+':'+f),f);
console.log('PASS proposal: exact nine transformations / final12464-byte SHA; 9 altered anchors +9 changed replacements rejected; extra bytes rejected; other32 company files identical; existing live guard still rejects unapproved PR55');
