import assert from 'node:assert/strict';
import {publicationView,renderPublicationStatus,createPublicationController} from '../publication-status-ui.mjs';
for(const [status,label,success,retry] of [['queued','? ??????? ?? ??????????',false,false],['building','????????? ???????',false,false],['published','????????????',true,false],['failed','?????? ??????????',false,true]]){
 const v=publicationView({status});assert.deepEqual([v.label,v.success,v.retry],[label,success,retry]);
}
for(const payload of [null,{}, {status:'published-ish'},{status:'published',public_url:'javascript:alert(1)'},{status:'queued',public_url:'https://valid.example/'}]){
 const v=publicationView(payload);assert(!v.publicUrl);assert(v.state==='published'||!v.success);
}
assert.equal(publicationView({status:'published',public_url:'https://example.com/company'}).publicUrl,'https://example.com/company');
const elements=[];const doc={createElement(tag){return {tag,textContent:'',href:'',target:'',rel:''}}};const node={ownerDocument:doc,replaceChildren(){elements.length=0},append(el){elements.push(el)}};
renderPublicationStatus(node,{status:'queued',public_url:'https://example.com/'});assert.equal(elements.length,1);
renderPublicationStatus(node,{status:'published',public_url:'https://example.com/company'});assert.equal(elements.length,2);assert.equal(elements[1].rel,'noopener noreferrer');
renderPublicationStatus(node,{status:'failed',public_url:'https://example.com/'});assert.equal(elements.length,1);
console.log('PASS publication UI: 4 states, fail-closed unknown, no premature links, valid published link only');

const companyId='4616c65b-5ebb-4c13-b2ef-24e2bc40d623';
const key='fa4e44c4-3909-4d8c-a6c5-3f74c95e0bb9';
const calls=[],shown=[];
let release;
const pending=new Promise(resolve=>release=resolve);
const ctl=createPublicationController({companyId,makeRequestId:()=>key,render:v=>{shown.push(v);return publicationView(v)},rpc:async(name,args)=>{
 calls.push([name,args]);if(name==='request_my_company_publication'){await pending;return {data:'attempt-1',error:null}};
 return {data:{company_id:companyId,status:'queued',public_url:null},error:null};
}});
const first=ctl.request();assert.equal(ctl.busy,true);assert.deepEqual(await ctl.request(),{accepted:false,reason:'busy'});
release();assert.equal((await first).accepted,true);assert.equal(ctl.busy,false);
assert.deepEqual(calls.map(x=>x[0]),['request_my_company_publication','get_my_company_publication_status']);
assert.equal(shown[0].status,'queued');assert.equal(shown[0].public_url,null);
let denied=false;const failed=createPublicationController({companyId,makeRequestId:()=>key,render:()=>{},rpc:async()=>({error:new Error('42501')})});
try{await failed.request()}catch(e){denied=e.message==='42501'}assert(denied);assert.equal(failed.busy,false);
const wrong=createPublicationController({companyId,makeRequestId:()=>key,render:()=>{},rpc:async(name)=>name==='request_my_company_publication'?{data:'attempt'}:{data:{company_id:'foreign',status:'published',public_url:'https://example.com'}}});
await assert.rejects(wrong.request(),/mismatch/);
console.log('PASS publication controller: canonical RPC, busy lock, server-ack, status company isolation, denied error');
