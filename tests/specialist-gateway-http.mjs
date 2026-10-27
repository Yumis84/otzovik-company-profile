import assert from 'node:assert/strict';import {isDefiniteStorageRejection,createMediaGateway} from '../server/specialist-media-gateway.js';
let n=0;const test=async(name,fn)=>{await fn();console.log('PASS GATEWAY HTTP',++n,name);};
await test('terminal JSON 4xx accepted, 408/409/5xx and legacy embedded uncertainty rejected',async()=>{
 for(const status of [400,401,403,404,413,415,429])assert(await isDefiniteStorageRejection(new Response(JSON.stringify({statusCode:status}),{status})));
 for(const status of [200,408,409,500,503])assert.equal(await isDefiniteStorageRejection(new Response(JSON.stringify({statusCode:status}),{status})),false);
 for(const body of [{statusCode:500},{statusCode:408},{statusCode:409},{code:'DatabaseTimeout'},{code:'InternalError'}])assert.equal(await isDefiniteStorageRejection(new Response(JSON.stringify(body),{status:400})),false);
 assert.equal(await isDefiniteStorageRejection(new Response('<html>Proxy error</html>',{status:413})),false);
});
const owner='11111111-1111-4111-8111-111111111111',profile='33333333-3333-4333-8333-333333333333',rid='44444444-4444-4444-8444-444444444444';
const body={action:'upload',specialist_id:profile,request_id:rid,kind:'portfolio',mime:'image/png',data:'iVBORw0KGgo=',caption:null};
const request=()=>new Request('http://unit.invalid',{method:'POST',headers:{Authorization:'Bearer unit.token','Content-Type':'application/json'},body:JSON.stringify(body)});
await test('definite rejection calls authenticated-scope retirement exactly once',async()=>{
 const calls=[];const gateway=createMediaGateway({url:'http://loopback.test',anonKey:'public-fixture',serviceKey:'private-fixture',fetcher:async(url,options)=>{
  calls.push(url);if(url.endsWith('/auth/v1/user'))return Response.json({id:owner});
  if(url.endsWith('/specialist_gateway_reserve'))return Response.json({object_name:profile+'/portfolio/'+rid+'.png',state:'uploading',upload_allowed:true});
  if(url.endsWith('/specialist_gateway_reject')){assert.equal(JSON.parse(options.body).p_owner,owner);return Response.json({retired:true});}
  return new Response(JSON.stringify({statusCode:413,error:'EntityTooLarge'}),{status:413});
 }});
 const result=await gateway(request());assert.equal(result.status,422);assert((await result.json()).reservation_released);assert.equal(calls.filter(x=>x.includes('/storage/')).length,1);assert.equal(calls.filter(x=>x.endsWith('/specialist_gateway_reject')).length,1);
});
await test('network failure and ambiguous status never issue retirement or retry Storage',async()=>{
 for(const failure of [408,409,500,'network']){
  let writes=0;const gateway=createMediaGateway({url:'http://loopback.test',anonKey:'public-fixture',serviceKey:'private-fixture',fetcher:async(url)=>{
   if(url.endsWith('/auth/v1/user'))return Response.json({id:owner});
   if(url.endsWith('/specialist_gateway_reserve'))return Response.json({object_name:profile+'/portfolio/'+rid+'.png',state:'uploading',upload_allowed:true});
   assert(!url.endsWith('/specialist_gateway_reject'));writes++;if(failure==='network')throw Error('Injected network failure');return new Response(JSON.stringify({statusCode:failure}),{status:failure});
  }});assert([409,503].includes((await gateway(request())).status));assert.equal(writes,1);
 }
});
console.log('GATEWAY HTTP RESULT',n,'PASS; deterministic unit injection only');
