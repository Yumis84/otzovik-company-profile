import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs/promises';
const html=await fs.readFile(new URL('../account-create-specialist.html',import.meta.url),'utf8');
const moduleSource=html.match(/<script type="module">([\s\S]*?)<\/script>/)?.[1];
assert(moduleSource);
const source=moduleSource.replace(/^import\b.*$/gm,'').replace('ms=8000','ms=20');
const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
const execute=new AsyncFunction('document','location','history','createClient','navigation','installValidation','validateForm','fieldError','createSavedSummary','sessionStorage','crypto','FormData',source);
function element(){return {disabled:false,hidden:true,textContent:'',checked:false,value:'',listeners:{},addEventListener(type,callback){this.listeners[type]=callback;},replaceChildren(){},append(){},setAttribute(){},removeAttribute(){}}}
async function run({session,rpc,id='',storage=new Map(),storageFault=''}){
 const nodes=new Map(),form=element(),inputs=new Map();
 form.elements={namedItem(name){if(!inputs.has(name))inputs.set(name,element());return inputs.get(name);}};
 const doc={getElementById(name){if(name==='preview')return form;if(!nodes.has(name))nodes.set(name,element());return nodes.get(name);},querySelector(){return element();},createElement(){return element();}};
 const location={search:id?'?id='+id:'',pathname:'/account-create-specialist.html',replace(value){this.redirect=value;}};
 const client={auth:{getSession:session},rpc};
 const MockFormData=class{get(name){return inputs.get(name)?.value??null;}};
 let uuid=0;const fail=method=>{if(storageFault===method)throw Error('Storage unavailable')};const store={get length(){fail('length');return storage.size},key(i){fail('key');return [...storage.keys()][i]??null},getItem(k){fail('getItem');return storage.get(k)??null},setItem(k,v){fail('setItem');storage.set(k,v)},removeItem(k){fail('removeItem');storage.delete(k)}};
 await execute(doc,location,{replaceState(){}},()=>client,()=>{},()=>{},()=>true,()=>{},()=>({load:async()=>{}}),store,{randomUUID(){return 'test-'+(++uuid);}},MockFormData);
 return {nodes,location,inputs,form,storage};
}
const never=()=>new Promise(()=>{});
test('hanging session fails closed and does not redirect or enable editing',async()=>{
 const r=await run({session:never,rpc:never});
 assert.equal(r.nodes.get('fields').disabled,true);assert.equal(r.nodes.get('save').disabled,true);
 assert.match(r.nodes.get('save-note').textContent,/Не удалось загрузить/);assert.equal(r.location.redirect,undefined);
});
test('publication status timeout fails closed',async()=>{
 const id='12345678-1234-4234-8234-123456789012';
 const r=await run({id,session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:name=>name==='get_my_specialists'?Promise.resolve({data:[{id,profile_status:'draft'}]}):never()});
 await new Promise(resolve=>setTimeout(resolve,35));
 assert.match(r.nodes.get('publication-status').textContent,/пока недоступно/);
 assert.equal(r.nodes.get('publication-publish').disabled,true);assert.equal(r.nodes.get('publication-unpublish').disabled,true);
});
test('unpublish clears only this profile request keys and stale replay rotates request id',async()=>{
 const id='12345678-1234-4234-8234-123456789012',prefix='specialist-publication:'+id+':';let state='published';const calls=[];
 const storage=new Map([[prefix+'1','old'],[prefix+'2','old2'],['specialist-publication:other:1','keep']]);
 const r=await run({id,storage,session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:async(name,args)=>{
  calls.push({name,args});if(name==='get_my_specialists')return {data:[{id,profile_status:'draft'}]};
  if(name==='get_my_specialist_publication_v1')return {data:{version:1,public_enabled:true,state,preview:{}}};
  if(name==='unpublish_my_specialist_v1'){state='unpublished';return {data:{published:false}};}
  if(name==='publish_my_specialist_v1')return {data:{published:false,replayed:true}};
  throw Error(name);
 }});
 await new Promise(resolve=>setTimeout(resolve,0));
 await r.nodes.get('publication-unpublish').listeners.click();
 assert.equal(storage.has(prefix+'1'),false);assert.equal(storage.has(prefix+'2'),false);assert.equal(storage.get('specialist-publication:other:1'),'keep');
 storage.set(prefix+'1','stale');r.nodes.get('publication-confirm').checked=true;
 await r.nodes.get('publication-publish').listeners.click();
 assert.match(r.nodes.get('publication-status').textContent,/Предыдущий запрос/);assert.equal(storage.has(prefix+'1'),false);
 assert.equal(calls.filter(x=>x.name==='publish_my_specialist_v1').length,1);
});
test('stale replay reloads actual newer published revision',async()=>{
 const id='12345678-1234-4234-8234-123456789012';let statusCalls=0;
 const r=await run({id,storage:new Map([['specialist-publication:'+id+':1','old-A']]),session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:async name=>{
  if(name==='get_my_specialists')return {data:[{id,profile_status:'draft'}]};
  if(name==='get_my_specialist_publication_v1'){statusCalls++;return {data:{version:1,public_enabled:true,state:'published',preview:{}}};}
  if(name==='publish_my_specialist_v1')return {data:{replayed:true,published:false}};throw Error(name);
 }});await new Promise(resolve=>setTimeout(resolve,0));r.nodes.get('publication-confirm').checked=true;await r.nodes.get('publication-publish').listeners.click();
 assert.equal(statusCalls,2);assert.match(r.nodes.get('publication-status').textContent,/Профиль опубликован/);assert.equal(r.nodes.get('publication-unpublish').disabled,false);
});
for(const fault of ['getItem','setItem'])test('publication storage '+fault+' failure releases busy without mutation',async()=>{
 const id='12345678-1234-4234-8234-123456789012';let writes=0;
 const r=await run({id,storageFault:fault,session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:async name=>{
  if(name==='get_my_specialists')return {data:[{id,profile_status:'draft'}]};if(name==='get_my_specialist_publication_v1')return {data:{version:1,public_enabled:true,state:'unpublished',preview:{}}};writes++;return {data:{published:true}};
 }});await new Promise(resolve=>setTimeout(resolve,0));r.nodes.get('publication-confirm').checked=true;await r.nodes.get('publication-publish').listeners.click();
 assert.equal(writes,0);assert.match(r.nodes.get('publication-status').textContent,/настройки браузера/);assert.equal(r.nodes.get('publication-publish').disabled,false);
});
test('successful unpublish remains success when storage cleanup fails',async()=>{
 const id='12345678-1234-4234-8234-123456789012';const r=await run({id,storageFault:'length',session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:async name=>{
  if(name==='get_my_specialists')return {data:[{id,profile_status:'draft'}]};if(name==='get_my_specialist_publication_v1')return {data:{version:1,public_enabled:true,state:'published',preview:{}}};if(name==='unpublish_my_specialist_v1')return {data:{published:false}};throw Error(name);
 }});await new Promise(resolve=>setTimeout(resolve,0));await r.nodes.get('publication-unpublish').listeners.click();assert.match(r.nodes.get('publication-status').textContent,/Профиль снят/);assert.equal(r.nodes.get('publication-unpublish').disabled,true);
});
for(const [code,message] of [['54000',/предел запросов/],['55000',/отключён/]])test('publication explains '+code,async()=>{
 const id='12345678-1234-4234-8234-123456789012';const r=await run({id,session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:async name=>{
  if(name==='get_my_specialists')return {data:[{id,profile_status:'draft'}]};if(name==='get_my_specialist_publication_v1')return {data:{version:1,public_enabled:true,state:'unpublished',preview:{}}};return {error:{code}};
 }});await new Promise(resolve=>setTimeout(resolve,0));r.nodes.get('publication-confirm').checked=true;await r.nodes.get('publication-publish').listeners.click();assert.match(r.nodes.get('publication-status').textContent,message);assert.doesNotMatch(r.nodes.get('publication-status').textContent,/Повторите/);
});
test('hanging owner profile lookup leaves form disabled',async()=>{
 const r=await run({session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:never,id:'12345678-1234-4234-8234-123456789012'});
 assert.equal(r.nodes.get('fields').disabled,true);assert.equal(r.nodes.get('save').disabled,true);
 assert.match(r.nodes.get('save-note').textContent,/Не удалось загрузить/);
});
test('session error is reported; missing session still redirects',async()=>{
 const a=await run({session:async()=>({error:Error('offline')}),rpc:never});
 assert.match(a.nodes.get('save-note').textContent,/Не удалось загрузить/);assert.equal(a.location.redirect,undefined);
 const b=await run({session:async()=>({data:{session:null}}),rpc:never});
 assert.match(b.location.redirect,/account-login\.html/);
});
test('successful authenticated create form becomes available',async()=>{
 const r=await run({session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:never});
 assert.equal(r.nodes.get('fields').disabled,false);assert.equal(r.nodes.get('save').disabled,false);
});
test('owner can reopen an existing draft after successful lookup',async()=>{
 const id='12345678-1234-4234-8234-123456789012';
 const r=await run({id,session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:name=>name==='get_my_specialists'?Promise.resolve({data:[{id,profile_status:'draft',display_name:'Owner',slug:'owner-test',profession:'Master'}]}):never()});
 assert.equal(r.inputs.get('display_name').value,'Owner');assert.equal(r.inputs.get('slug').readOnly,true);
 assert.equal(r.nodes.get('save').disabled,false);
});
test('late session response cannot enable a timed-out form',async()=>{
 let complete;const pending=new Promise(resolve=>{complete=resolve;});
 const r=await run({session:()=>pending,rpc:never});
 complete({data:{session:{user:{id:'owner'}}}});await new Promise(resolve=>setTimeout(resolve,10));
 assert.equal(r.nodes.get('save').disabled,true);assert.match(r.nodes.get('save-note').textContent,/Не удалось загрузить/);
});
test('synthetic create is not duplicated on concurrent submit; later save updates same profile',async()=>{
 const id='12345678-1234-4234-8234-123456789012';let resolveCreate;const calls=[];
 const r=await run({session:async()=>({data:{session:{user:{id:'owner'}}}}),rpc:(name,args)=>{
  calls.push({name,args});
  if(name==='create_my_specialist_draft')return new Promise(resolve=>{resolveCreate=resolve;});
  if(name==='update_my_specialist_draft')return Promise.resolve({data:{id,profile_status:'draft'}});
  return never();
 }});
 r.inputs.set('display_name',{value:'Test'});r.inputs.get('slug').value='person-one';r.inputs.set('profession',{value:'Master'});
 const submit=()=>r.form.listeners.submit({preventDefault(){}});
 const first=submit();await submit();assert.equal(calls.filter(x=>x.name==='create_my_specialist_draft').length,1);
 resolveCreate({data:{id,profile_status:'draft'}});await first;
 r.inputs.get('display_name').value='Updated';await submit();
 assert.equal(calls.filter(x=>x.name==='create_my_specialist_draft').length,1);
 assert.equal(calls.find(x=>x.name==='update_my_specialist_draft').args.p_id,id);
 assert.equal(r.nodes.get('save').disabled,false);
});

