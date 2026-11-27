import assert from 'node:assert/strict';
import {createCompanyPublicHandler} from '../server/staging-company-public-profile.js';
const data=new TextEncoder().encode('<!doctype html><title>Staging fixture</title>');
const digest=Buffer.from(await crypto.subtle.digest('SHA-256',data)).toString('hex');
const id='4616c65b-5ebb-4c13-b2ef-24e2bc40d623',revision='a'.repeat(64),bucket='company-publication-artifacts-staging';
let mode='ok',calls=[];
const handler=createCompanyPublicHandler({serviceKey:'fixture-key',fetchImpl:async(url,init)=>{
 calls.push({url,init});assert.ok(url.startsWith('https://salmcnhexlftrgtiryyo.supabase.co/'));assert.equal(init.redirect,'error');
 if(url.includes('/rpc/')){
  if(mode==='hidden')return Response.json(null);
  return Response.json({bucket:mode==='wrong-bucket'?'specialist-media':bucket,company_id:id,revision,object_name:id+'/'+revision+'/index.html',sha256:digest,content_type:'text/html; charset=utf-8'});
 }
 return new Response(mode==='tampered'?'different':mode==='oversized'?new Uint8Array(5242881):data);
}});
const request=(path='alpha/',method='GET')=>new Request('https://fixture.test/functions/v1/company-public-profile/'+path,{method});
let response=await handler(request());assert.equal(response.status,200);assert.match(await response.text(),/Staging fixture/);assert.equal(response.headers.get('Cache-Control'),'no-store');assert.equal(response.headers.get('X-Content-Type-Options'),'nosniff');console.log('PASS staged RPC -> bound Storage object -> actual SHA256 -> HTML response');
for(const [m,status] of [['hidden',404],['wrong-bucket',503],['tampered',503],['oversized',503]]){mode=m;response=await handler(request());assert.equal(response.status,status)}
mode='ok';for(const path of ['ALPHA/','alpha/%2e%2e/secrets','alpha/profile.json?company_id=foreign','alpha/media/../secrets'])assert.equal((await handler(request(path))).status,404);
assert.equal((await handler(request('alpha/','POST'))).status,405);assert.equal((await handler(request('alpha/','HEAD'))).status,200);
console.log('PASS hidden, foreign bucket, changed/oversize bytes, traversal/query/method rejection and HEAD');
assert.ok(calls.every(x=>!x.url.includes('rzhlcszqtuhkhfibygnk')));console.log('PASS transport always staging, no production/external redirects');
