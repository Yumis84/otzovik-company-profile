import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {createCabinet} from '../account-profile-core.js';
import {profileAdapter} from '../account-profile-adapters.js';
import {database,A,B} from './database.mjs';
const db=await database();
const names={get_my_companies:[],get_my_specialists:[],update_my_company_profile:['p_company_id','p_name','p_description','p_website','p_phone','p_city','p_email'],update_my_specialist_draft:['p_id','p_display_name','p_profession','p_specialization','p_city','p_description']};
let user=A,calls=[];
const client={auth:{getSession:async()=>({data:{session:user?{user:{id:user}}:null},error:null})},rpc:async(name,args={})=>{calls.push(name);assert(names[name]);assert.deepEqual(Object.keys(args).sort(),[...names[name]].sort());try{return {data:await db.call(user,name,names[name].map(n=>args[n])),error:null};}catch(error){return {data:null,error};}}};
const storage=()=>({values:{},setItem(k,v){this.values[k]=v;}});
try{
 const company=(await db.call(A,'create_my_company',['Shared Company','shared-company',null,null,'City',null])).company;
 const specialist=await db.call(A,'create_my_specialist_draft',['Shared Specialist','shared-specialist','Photographer']);
 for(const [kind,record,values] of [['company',company,{name:'Updated Company',description:'Text',website:null,phone:null,city:'City',email:null}],['specialist',specialist,{display_name:'Updated Specialist',profession:'Photographer',specialization:null,city:'City',description:'Text'}]]){
  const adapter=profileAdapter(kind),sessionStorage=storage(),localStorage=storage();
  const location={pathname:'/account-test',search:'?'+adapter.idKey+'='+record.id,replace(url){this.redirect=url;}};
  const cabinet=createCabinet({client,adapter,location,sessionStorage,localStorage});
  user=A;const loaded=await cabinet.load();assert.equal(loaded.kind,kind);assert.equal(loaded.id,record.id);assert(loaded.canEdit);
  assert.deepEqual(JSON.parse(sessionStorage.values.active_profile),{kind,id:record.id});
  assert.equal(localStorage.values.otzovik_active_company_id,kind==='company'?record.id:undefined);
  await cabinet.saveBasic(values);assert.equal((await cabinet.load()).name,values.name||values.display_name);
  await assert.rejects(()=>cabinet.saveBasic({...values,profile_status:'published'}),/полный набор/);
  user=B;const before=calls.length;await assert.rejects(()=>cabinet.saveBasic(values),{code:'42501'});assert.equal(cabinet.current,null);assert(!calls.slice(before).some(n=>n.startsWith('update_')));
  user=null;await assert.rejects(()=>cabinet.load(),/Войдите/);assert.equal(new URL(location.redirect,'https://test.invalid').searchParams.get('next'),'account-test.html'+location.search);
  user=A;for(const search of ['?'+adapter.idKey+'=bad','?'+adapter.idKey+'='+B,'?'+adapter.idKey+'='+record.id+'&'+adapter.otherIdKey+'='+record.id,'?'+adapter.idKey+'='+record.id+'&profile_kind='+ (kind==='company'?'specialist':'company')]){location.search=search;await assert.rejects(()=>cabinet.load());assert.equal(cabinet.current,null);}
  location.search='?'+adapter.idKey+'='+record.id;
  if(kind==='company'){
   await db.query("UPDATE company_memberships SET role='analyst' WHERE company_id=$1 AND user_id=$2",[record.id,A]);assert.equal((await cabinet.load()).canEdit,false);await assert.rejects(()=>cabinet.saveBasic(values),{code:'42501'});
   await db.query("UPDATE company_memberships SET verification_status='revoked' WHERE company_id=$1 AND user_id=$2",[record.id,A]);await assert.rejects(()=>cabinet.load(),{code:'42501'});
  }else{
   assert.equal(adapter.select([{...record,profile_status:"published"}],record.id),null);
   await db.query("UPDATE specialist_profiles SET owner_user_id=$2 WHERE id=$1",[record.id,B]);await assert.rejects(()=>cabinet.load(),{code:"42501"});
  }
  console.log('PASS shared controller + SQL adapter: '+kind);
 }
 // The immutable company source snapshot also guards legacy CSS/menu/auth code.
 const baseline=JSON.parse(await fs.readFile(new URL('./fixtures/company-source-hashes.json',import.meta.url),'utf8'));
 for(const [file,hash] of Object.entries(baseline))assert.equal(crypto.createHash('sha256').update(await fs.readFile(new URL('../'+file,import.meta.url))).digest('hex'),hash,'Company source changed: '+file);
 assert.throws(()=>profileAdapter('unknown'));assert.throws(()=>profileAdapter('__proto__'));
 assert(!profileAdapter('specialist').menu.some(([key])=>key==='branches'));
 console.log('PASS immutable company sources: '+Object.keys(baseline).length+'; typed navigation/unknown adapter');
}finally{await db.close();}
