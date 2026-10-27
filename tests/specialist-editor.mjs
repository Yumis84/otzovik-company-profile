import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import {database,A,B} from './database.mjs';
const db=await database({editor:true});let count=0;
const test=async(name,fn)=>{await fn();console.log('PASS EDITOR',++count,name);};
const denied=(fn,code='42501')=>assert.rejects(fn,e=>e.code===code);
let a,b,service,media;const sid=crypto.randomUUID();
try{
 a=await db.call(A,'create_my_specialist_draft',['Owner','editor-owner','Master']);b=await db.call(B,'create_my_specialist_draft',['Other','editor-other','Master']);
 await test('service create/update/read and stale-version rejection',async()=>{
  service=await db.call(A,'save_my_specialist_service',[a.id,sid,'Photo service','Private',10,20,'RUB',60]);assert.equal(service.version,1);
  service=await db.call(A,'save_my_specialist_service',[a.id,sid,'Photo edited',null,20,30,'RUB',90,false,1]);assert.equal(service.version,2);
  await denied(()=>db.call(A,'save_my_specialist_service',[a.id,sid,'Stale',null,null,null,'RUB',null,true,1]),'40001');
  assert.equal((await db.call(A,'get_my_specialist_services',[a.id]))[0].name,'Photo edited');
  await denied(()=>db.call(A,'save_my_specialist_service',[a.id,crypto.randomUUID(),'X',null,20,10]),'23514');
 });
 await test('foreign child id, foreign profile, company id and anon denied',async()=>{
  for(const id of [a.id,'33333333-3333-4333-8333-333333333333'])for(const name of ['get_my_specialist_services','get_my_specialist_settings','get_my_specialist_media'])await denied(()=>db.call(B,name,[id]));
  await denied(()=>db.call(B,'save_my_specialist_service',[b.id,sid,'Stolen']));
  await denied(()=>db.call(null,'get_my_specialist_services',[a.id]));
  await denied(()=>db.call(A,'update_my_company_profile',[a.id,'Wrong kind']));
  for(const table of ['specialist_services','specialist_settings','specialist_media'])for(const sql of [`SELECT * FROM ${table}`,`DELETE FROM ${table}`])await denied(()=>db.session(A,c=>c.query(sql)));
 });
 await test('contacts private by default; formats and HTTPS bounded; stale save denied',async()=>{
  const empty=await db.call(A,'get_my_specialist_settings',[a.id]);assert.equal(empty.contact_visibility,'private');assert.equal(empty.version,0);
  const row=await db.call(A,'save_my_specialist_settings',[a.id,'Private phone','private@example.test','https://example.test',['online','onsite'],'City','Self declared',0]);assert.equal(row.contact_visibility,'private');
  await denied(()=>db.call(A,'save_my_specialist_settings',[a.id,null,null,'javascript:alert(1)',[],null,null,1]),'23514');
  await denied(()=>db.call(A,'save_my_specialist_settings',[a.id,null,null,null,['bad'],null,null,1]),'23514');
  await denied(()=>db.call(A,'save_my_specialist_settings',[a.id]),'40001');
  assert.equal((await db.call(A,'get_my_specialist_settings',[a.id])).phone,'Private phone');
 });
 await test('separate Storage owner policy; malformed/cross-kind paths denied',async()=>{
  for(const path of [a.id+'/avatar/'+crypto.randomUUID()+'.webp','33333333-3333-4333-8333-333333333333/avatar/'+crypto.randomUUID()+'.webp',a.id+'/../x.webp']){
   if(path.startsWith(a.id+'/avatar/'))await denied(()=>db.session(B,c=>c.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,'{}')",[path])));
   else await denied(()=>db.session(A,c=>c.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,'{}')",[path])));
  }
  const path=a.id+'/avatar/'+crypto.randomUUID()+'.webp';await db.session(A,c=>c.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,{size:100,mimetype:'image/webp'}]));
  assert.equal((await db.session(B,c=>c.query('SELECT * FROM storage.objects'))).rows.length,0);
  media=await db.call(A,'register_my_specialist_media',[a.id,path,'avatar','My avatar']);
  assert.equal((await db.call(A,'register_my_specialist_media',[a.id,path,'avatar','Updated caption'])).id,media.id);
  await denied(()=>db.call(B,'register_my_specialist_media',[b.id,path,'avatar']),'22023');
  await denied(()=>db.call(B,'delete_my_specialist_media',[a.id,media.id]));
 });
 await test('helper RPCs reject malformed, foreign and company paths without UUID errors',async()=>{
  for(const user of [A,B])for(const path of ['bad/avatar/x.png','',null,'33333333-3333-4333-8333-333333333333/avatar/'+crypto.randomUUID()+'.png'])for(const rpc of ['can_manage_specialist_object','can_upload_specialist_object'])assert.equal(await db.call(user,rpc,[path]),false);
  const own=a.id+'/portfolio/'+crypto.randomUUID()+'.png';
  for(const rpc of ['can_manage_specialist_object','can_upload_specialist_object']){
   assert.equal(await db.call(A,rpc,[own]),true);
   assert.equal(await db.call(B,rpc,[own]),false);
  }
 });
 await test('server rejects oversized/unsafe MIME; one avatar and file quota',async()=>{
  for(const meta of [{size:5242881,mimetype:'image/png'},{size:100,mimetype:'image/svg+xml'}]){const path=a.id+'/portfolio/'+crypto.randomUUID()+'.png';await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,meta]);await denied(()=>db.call(A,'register_my_specialist_media',[a.id,path,'portfolio']),'22023');}
  const path=a.id+'/avatar/'+crypto.randomUUID()+'.png';await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,{size:100,mimetype:'image/png'}]);await denied(()=>db.call(A,'register_my_specialist_media',[a.id,path,'avatar']),'23505');
  await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) SELECT 'specialist-media',$1||'/portfolio/'||gen_random_uuid()||'.png','{}' FROM generate_series(1,greatest(0,20-(SELECT count(*)::int FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=$1)))",[a.id]);
  await denied(()=>db.session(A,c=>c.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,'{}')",[a.id+'/portfolio/'+crypto.randomUUID()+'.png'])),'54000');
  await denied(()=>db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,'{}')",[a.id+'/portfolio/'+crypto.randomUUID()+'.png']),'54000');
  for(const role of ['anon','authenticated'])assert.equal((await db.query("SELECT has_function_privilege($1,'public.enforce_specialist_object_integrity()','EXECUTE') allowed",[role])).rows[0].allowed,false);
 });
 await test('draft quota, explicit deletion releases slug; files block deletion',async()=>{
  await denied(()=>db.call(A,'delete_my_specialist_draft',[a.id]),'55000');
  await db.call(B,'delete_my_specialist_draft',[b.id]);assert(!(await db.query('SELECT * FROM profile_slug_registry WHERE slug=$1',['editor-other'])).rows.length);
  for(let i=0;i<10;i++)await db.call(B,'create_my_specialist_draft',['Quota','quota-'+i,'Master']);
  await denied(()=>db.call(B,'create_my_specialist_draft',['Quota','quota-extra','Master']),'54000');
 });
 await test('disable then enable preserves data and restores only owner access',async()=>{
  const before=await db.call(A,'get_my_specialist_services',[a.id]);
  await db.exec(await fs.readFile(new URL('../sql/20261017_specialist_editor_DISABLE_CANDIDATE.sql',import.meta.url),'utf8'));
  await denied(()=>db.call(A,'get_my_specialist_services',[a.id]));
  await db.exec(await fs.readFile(new URL('../sql/20261017_specialist_editor_ENABLE_CANDIDATE.sql',import.meta.url),'utf8'));
  assert.deepEqual(await db.call(A,'get_my_specialist_services',[a.id]),before);
  await denied(()=>db.call(B,'get_my_specialist_services',[a.id]));
  await denied(()=>db.call(null,'get_my_specialist_services',[a.id]));
  await denied(()=>db.session(A,c=>c.query('SELECT * FROM specialist_services')));
  assert.equal((await db.session(B,c=>c.query('SELECT * FROM storage.objects'))).rows.length,0);
 });
 await test('security metadata and static UI isolation',async()=>{
  for(const table of ['specialist_services','specialist_settings','specialist_media']){const r=(await db.query('SELECT relforcerowsecurity FROM pg_class WHERE oid=$1::regclass',[table])).rows[0];assert(r.relforcerowsecurity);}
  for(const f of ['account-specialist-services.js','account-specialist-media.js','account-specialist-contacts.js','account-specialist-api.js']){const src=await fs.readFile(new URL('../'+f,import.meta.url),'utf8');assert(!/get_my_compan|p_company_id|active_company_id|company-media/.test(src));assert(!src.includes('innerHTML'));}
  const p=(await db.query("SELECT public, file_size_limit FROM storage.buckets WHERE id='specialist-media'")).rows[0];assert.equal(p.public,false);assert.equal(Number(p.file_size_limit),5242880);
 });
 console.log('PASS',count,'editor security groups (SQL fixture; real Storage tested separately in LOCAL stack)');
}finally{await db.close();}
