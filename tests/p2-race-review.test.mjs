import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {selectVerifiedCompanyRow as select,CompanySelectionDeniedError as Denied} from '../company-context-selector.mjs';
import {validatePublicProfileUrl,publicationView} from '../publication-status-ui.mjs';
const proposal=JSON.parse(readFileSync(new URL('./p2-company-race-review.json',import.meta.url),'utf8'));
const sources=new Map();
for(const [i,e] of proposal.edits.entries())test('anchor '+(i+1)+' '+e.path,()=>{
 const s=sources.get(e.path)??readFileSync(new URL('../'+e.path,import.meta.url),'utf8');
 assert.equal(s.split(e.old).length-1,e.count);
 sources.set(e.path,s.split(e.old).join(e.new));
});
test('no legacy selector in transformed review sources',()=>{
 assert.equal(sources.size,11);
 for(const [path,s] of sources){assert.doesNotMatch(s,/found\s*\|\|\s*list\[0\]/,path);assert.match(s,/selectVerifiedCompanyRow\(/,path)}
 assert.equal((sources.get('account-media.html').match(/selectVerifiedCompanyRow\(/g)||[]).length,2);
});
const row={company:{id:'A'},membership:{role:'owner'}};
for(const query of ['?company_id=','?company_id=B'])test('captured explicit survives asynchronous URL mutation '+query,async()=>{
 let search=query;const params=new URLSearchParams(search);const id=params.get('company_id');const explicit=id!==null;const requested=explicit?id:'A';
 await Promise.resolve().then(()=>{search=''});
 assert.throws(()=>select([row],requested,{explicit}),Denied);
});
test('stale saved company denied for different user',()=>assert.throws(()=>select([{company:{id:'B'},membership:{role:'owner'}}],'A'),Denied));
const origin='https://example.test',url=origin+'/functions/v1/company-public-profile/demo-company/';
test('future approved route accepted only by validator',()=>{assert.equal(validatePublicProfileUrl(url,origin),url);assert.equal(publicationView({status:'published',public_url:url}).publicUrl,null)});
for(const bad of [url+'?x=1',url+'#x',url.replace('https:','http:'),url.replace('example.test','evil.test'),url.replace('example.test','user@example.test'),origin+'/company/demo/',origin+'/functions/v1/company-public-profile/%2e%2e/','javascript:alert(1)'])test('reject '+bad,()=>assert.equal(validatePublicProfileUrl(bad,origin),null));
