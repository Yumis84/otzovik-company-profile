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
async function run({session,rpc,id=''}){
 const nodes=new Map(),form=element(),inputs=new Map();
 form.elements={namedItem(name){if(!inputs.has(name))inputs.set(name,element());return inputs.get(name);}};
 const doc={getElementById(name){if(name==='preview')return form;if(!nodes.has(name))nodes.set(name,element());return nodes.get(name);},querySelector(){return element();},createElement(){return element();}};
 const location={search:id?'?id='+id:'',pathname:'/account-create-specialist.html',replace(value){this.redirect=value;}};
 const client={auth:{getSession:session},rpc};
 const MockFormData=class{get(name){return inputs.get(name)?.value??null;}};
 await execute(doc,location,{replaceState(){}},()=>client,()=>{},()=>{},()=>true,()=>{},()=>({load:async()=>{}}),{getItem(){return null;}},{randomUUID(){return 'test';}},MockFormData);
 return {nodes,location,inputs,form};
}
const never=()=>new Promise(()=>{});
test('hanging session fails closed and does not redirect or enable editing',async()=>{
 const r=await run({session:never,rpc:never});
 assert.equal(r.nodes.get('fields').disabled,true);assert.equal(r.nodes.get('save').disabled,true);
 assert.match(r.nodes.get('save-note').textContent,/Не удалось загрузить/);assert.equal(r.location.redirect,undefined);
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
