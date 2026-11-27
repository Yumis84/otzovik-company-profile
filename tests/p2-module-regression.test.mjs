import test from 'node:test';
import assert from 'node:assert/strict';
import {selectVerifiedCompanyRow as select,CompanySelectionDeniedError as Denied} from '../company-context-selector.mjs';
import {publicationView as view,renderPublicationStatus,createPublicationController as controller} from '../publication-status-ui.mjs';
const a={company:{id:'a'},company_id:'a',membership:{role:'owner'}},b={company:{id:'b'},company_id:'b',membership:{role:'analyst'}};
for(const [name,fn] of Object.entries({
 'explicit match':()=>assert.equal(select([a,b],'b',{explicit:true}),b),
 'saved match':()=>assert.equal(select([a,b],'b'),b),
 'foreign explicit':()=>assert.throws(()=>select([a,b],'c',{explicit:true}),Denied),
 'stale saved':()=>assert.throws(()=>select([a,b],'c'),Denied),
 'empty explicit':()=>assert.throws(()=>select([a,b],'',{explicit:true}),Denied),
 'no preference':()=>assert.equal(select([a,b],null),a),
 'empty memberships':()=>assert.equal(select([],null),null),
 'invalid response':()=>assert.throws(()=>select(null,'a')),
 'mismatched row':()=>assert.throws(()=>select([{...a,company_id:'b'}],'a'),Denied),
 'missing role':()=>assert.throws(()=>select([{company:{id:'a'}}],'a'),Denied),
 'malformed status':()=>assert.equal(view({status:'toString'}).state,'unknown'),
 'failed retry':()=>assert.equal(view({status:'failed'}).retry,true),
 'queued not success':()=>assert.equal(view({status:'queued'}).success,false),
 'building not success':()=>assert.equal(view({status:'building'}).success,false),
 'published null URL':()=>assert.equal(view({status:'published',public_url:null}).publicUrl,null),
}))test(name,fn);
for(const url of ['https://example.com/company/a/','javascript:alert(1)','data:text/html,x','https://evil.example/','//evil.example','https://good.example@evil.example/company/a/'])test('suppress '+url,()=>assert.equal(view({status:'published',public_url:url}).publicUrl,null));
test('DOM renders text only',()=>{const children=[];const node={replaceChildren(){children.length=0},ownerDocument:{createElement(tag){return {tag}}},append(x){children.push(x)}};renderPublicationStatus(node,{status:'published',public_url:'https://evil.example/'});assert.deepEqual(children,[{tag:'span',textContent:'Опубликовано'}]);});
const id='12345678-1234-4234-8234-123456789abc';
const make=(rpc,makeRequestId=()=>id)=>controller({rpc,companyId:'a',makeRequestId,render:view});
test('foreign RPC response rejected',async()=>assert.rejects(make(async()=>({data:{company_id:'b',status:'published'}})).refresh(),/mismatch/));
test('invalid request UUID no RPC',async()=>{let n=0;const c=make(async()=>{n++},()=> 'bad');await assert.rejects(c.request(),/UUID/);assert.equal(n,0);assert.equal(c.busy,false)});
test('missing ACK rejects',async()=>{const c=make(async()=>({data:null}));await assert.rejects(c.request(),/acknowledged/);assert.equal(c.busy,false)});
test('busy and exact RPC arguments',async()=>{let release;const gate=new Promise(r=>release=r);const calls=[];const c=make(async(name,args)=>{calls.push([name,args]);if(calls.length===1){await gate;return {data:id}}return {data:{company_id:'a',status:'queued'}}});const pending=c.request();assert.deepEqual(await c.request(),{accepted:false,reason:'busy'});release();assert.equal((await pending).view.state,'queued');assert.deepEqual(calls,[['request_my_company_publication',{p_company_id:'a',p_request_id:id}],['get_my_company_publication_status',{p_company_id:'a'}]]);assert.equal(c.busy,false)});
