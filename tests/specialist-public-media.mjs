import assert from 'node:assert/strict';
import {publishedPhotoLoader} from '../specialist-public-media.js';
const id='11111111-1111-4111-8111-111111111111',slug='public-test',endpoint='https://example.invalid/functions/v1/specialist-media-gateway';
let created=0,revoked=[],requests=[];
const urls={createObjectURL(){return 'blob:test-'+(++created);},revokeObjectURL(x){revoked.push(x);}};
const make=(fetcher,extra={})=>publishedPhotoLoader({endpoint,anonKey:'public-anon',fetcher,urls,...extra});
let loader=make(async(url,options)=>{requests.push({url,options});return new Response(new Blob(['image'],{type:'image/png'}));});
let image=await loader.load(slug,id);assert.equal(image.url,'blob:test-1');assert.equal(requests[0].url.searchParams.get('photo'),id);assert.equal(requests[0].url.searchParams.get('view'),'published');assert.equal(requests[0].options.headers.Authorization,'Bearer public-anon');assert.equal(requests[0].options.headers.apikey,'public-anon');assert.equal(requests[0].options.credentials,'omit');
image.release();image.release();assert.deepEqual(revoked,['blob:test-1']);
image=await loader.load(slug,id);loader.dispose();assert.deepEqual(revoked,['blob:test-1','blob:test-2']);assert.equal(await loader.load(slug,id),null);
for(const response of [()=>new Response('',{status:404}),()=>new Response('<svg/>',{headers:{'content-type':'image/svg+xml'}}),()=>new Response('oops',{headers:{'content-type':'text/html'}}),()=>new Response(new Blob([],{type:'image/png'})),()=>new Response(new Blob([new Uint8Array(10*1024*1024+1)],{type:'image/png'}))]){
 loader=make(async()=>response());assert.equal(await loader.load(slug,id),null);loader.dispose();
}
loader=make(async()=>{throw Error('network');});assert.equal(await loader.load(slug,id),null);assert.equal(await loader.load(slug,'../private'),null);
loader=make(async(_,options)=>new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(Error('abort')))),{timeout:5});assert.equal(await loader.load(slug,id),null);
let finish;loader=make(async()=>new Promise(resolve=>finish=resolve));const pending=loader.load(slug,id);loader.dispose();finish(new Response(new Blob(['late'],{type:'image/png'})));assert.equal(await pending,null);assert.equal(created,2);
console.log('PASS public media: public credential, POST, allowlisted MIME, 404/network/timeout, invalid ID, size limit, disposal race, URL release');
