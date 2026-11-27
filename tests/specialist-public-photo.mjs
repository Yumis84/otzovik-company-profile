import assert from 'node:assert/strict';
import {createMediaGateway} from '../server/specialist-media-gateway.js';
const id='11111111-1111-4111-8111-111111111111';
const path=id+'/portfolio/'+id+'.png';
const key='fixture',headers={apikey:'public-fixture'};
const make=(fetcher)=>createMediaGateway({url:'https://stage.invalid',anonKey:'fixture-anon',serviceKey:key,fetcher});
const req=(photo=id)=>new Request('https://edge.invalid/?view=published&slug=demo&photo='+photo,{method:'POST',headers});
for(const [resolved,status] of [[null,404],['../invalid',404],[path,200]]){
 let reads=0;
 const result=await make(async(url,opts)=>{
  if(url.endsWith('/resolve_public_specialist_photo_v1')){
   assert.deepEqual(JSON.parse(opts.body),{p_slug:'demo',p_photo:id});return Response.json(resolved);
  }
  assert.equal(url,'https://stage.invalid/storage/v1/object/authenticated/specialist-media/'+path);reads++;
  return new Response(new Uint8Array([1,2]),{headers:{'Content-Type':'image/png','Content-Length':'2'}});
 })(req());
 assert.equal(result.status,status);assert.equal(reads,status===200?1:0);assert.equal(result.headers.get('cache-control'),'no-store');
}
assert.equal((await make(()=>assert.fail())(req('invalid'))).status,404);
assert.equal((await make(()=>{throw Error('offline')})(req())).status,503);
assert.equal((await make(()=>assert.fail())(new Request('https://edge.invalid/',{method:'POST',body:'{}'}))).status,401);
for(const [mime,data,status] of [['image/svg+xml','PHN2Zz4=',415],['image/png','AA==',415],['image/png','A'.repeat(6990508),413]]){
 const handler=make(async url=>{assert(url.endsWith('/auth/v1/user'));return Response.json({id});});
 const res=await handler(new Request('https://edge.invalid/',{method:'POST',headers:{Authorization:'Bearer fixture'},body:JSON.stringify({action:'upload',kind:'portfolio',request_id:id,specialist_id:id,mime,data,caption:null})}));
 assert.equal(res.status,status);
}
console.log('PASS public photo: current reference, absent or invalid reference, no cached bytes, network failure, owner auth gate, upload MIME/signature/size');
