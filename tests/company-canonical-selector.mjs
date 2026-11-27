import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {selectVerifiedCompanyRow,CompanySelectionDeniedError} from '../company-context-selector.mjs';
const A='4616c65b-5ebb-4c13-b2ef-24e2bc40d623',B='f1d3c93b-20e6-4a3c-9a54-36a947a55fb2';
const rows=[{company:{id:A},membership:{role:'owner'}},{company:{id:B},membership:{role:'analyst'}}];
assert.equal(selectVerifiedCompanyRow(rows,B,{explicit:true}).company.id,B);
assert.throws(()=>selectVerifiedCompanyRow(rows,'foreign',{explicit:true}),CompanySelectionDeniedError);
assert.equal(selectVerifiedCompanyRow(rows,'foreign',{explicit:false}).company.id,A);
assert.equal(selectVerifiedCompanyRow([]),null);
assert.throws(()=>selectVerifiedCompanyRow({unexpected:true}),/Invalid company membership/);
assert.equal(selectVerifiedCompanyRow([{company:{id:A}}]),null);
for(const name of ['profile','branches','services','media','reviews','sources','analytics','notifications','ai-assistant','billing']){
 const html=fs.readFileSync(new URL('../account-'+name+'.html',import.meta.url),'utf8');
 assert.equal(html.includes("from './company-context-selector.mjs'"),true,name);
 assert.equal(html.includes('const pickCompanyRow=rows=>selectVerifiedCompanyRow('),true,name);
 assert.equal(html.includes('saveCompanyId(urlCompanyId)'),false,name);
 for(const [,code] of html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)){
  const stripped=code.replace(/import\s*\{[^}]+\}\s*from\s*['"`][^'"`]+['"`];?/g,'');
  new vm.Script('async function __syntax(){'+stripped+'}',{filename:name});
 }
 console.log('PASS canonical company selector + inline JS syntax',name);
}
console.log('PASS selector denial, membership, empty/malformed and 10 pages');
