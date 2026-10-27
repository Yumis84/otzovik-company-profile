import assert from 'node:assert/strict';import fs from 'node:fs/promises';import crypto from 'node:crypto';import {database,A,B} from './database.mjs';
const db=await database({editor:true}),file=f=>fs.readFile(new URL('../'+f,import.meta.url),'utf8');let n=0;
const test=async(name,fn)=>{await fn();console.log('PASS REMEDIATION SQL',++n,name);},denied=(fn,code)=>assert.rejects(fn,e=>!code||e.code===code);
try{
 await db.exec("DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF; END $$; GRANT USAGE ON SCHEMA public,storage TO service_role; DROP TRIGGER specialist_object_integrity ON storage.objects;");
 await db.exec(await file('sql/release/60_GATEWAY_CANDIDATE.sql'));await db.exec(await file('sql/release/65_GATEWAY_REMEDIATION_CANDIDATE.sql'));await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));
 const p=await db.call(A,'create_my_specialist_draft',['Remediation','remediation','Master']),id=p.id;
 const q=(name,args)=>db.query('SELECT public.'+name+'('+args.map((_,i)=>'$'+(i+1)).join(',')+') data',args).then(r=>r.rows[0].data);
 const reserve=rid=>q('specialist_gateway_reserve',[A,id,rid,'portfolio','a'.repeat(64),'image/png',10,null]);
 const proof=rid=>({kind:'provider_terminal_no_late_writer',request_id:rid,evidence_ref:'isolated-fixture:never-issued-'+rid,all_writers_stopped:true});
 const retire=(rid,phase,pf=proof(rid),owner=A)=>q('specialist_gateway_force_retire',[owner,id,rid,phase,'isolated-test-operator','Synthetic fixture no live writer',pf]);
 await test('service-only endpoints and audit append-only to API roles',async()=>{
  for(const role of ['anon','authenticated'])for(const name of ['specialist_gateway_reject','specialist_gateway_force_retire','specialist_gateway_metrics','specialist_gateway_erasure_inventory'])assert.equal((await db.query("SELECT has_function_privilege($1,oid,'EXECUTE') allowed FROM pg_proc WHERE proname=$2",[role,name])).rows[0].allowed,false);
  for(const role of ['anon','authenticated','service_role'])assert.equal((await db.query("SELECT has_table_privilege($1,'specialist_upload_audit','INSERT,UPDATE,DELETE') allowed",[role])).rows[0].allowed,false);
 });
 await test('20 definite failures release slots, audit and retired replay never admits upload',async()=>{
  for(let i=0;i<20;i++){const rid=crypto.randomUUID();await reserve(rid);assert((await q('specialist_gateway_reject',[A,id,rid,413])).retired);assert.equal((await reserve(rid)).upload_allowed,false);}
  const r=await reserve(crypto.randomUUID());assert(r.upload_allowed);await q('specialist_gateway_reject',[A,id,r.id,415]);
  assert.equal((await q('specialist_gateway_metrics',[])).definite_rejections,21);
 });
 let unknown=crypto.randomUUID();
 await test('408/409/500, expiry, missing proof and wrong tenant cannot retire quarantine',async()=>{
  await reserve(unknown);for(const code of [408,409,500])await denied(()=>q('specialist_gateway_reject',[A,id,unknown,code]),'22023');
  await db.query("UPDATE specialist_upload_reservations SET expires_at=now()-interval '1 day' WHERE id=$1",[unknown]);
  await denied(()=>retire(unknown,'begin'),'55000');await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
  await denied(()=>retire(unknown,'begin',{}),'22023');await denied(()=>retire(unknown,'begin',{...proof(unknown),kind:'ttl_expired'}),'22023');await denied(()=>retire(unknown,'begin',proof(unknown),B),'42501');
  assert.equal((await q('specialist_gateway_metrics',[])).quarantined,1);assert((await q('specialist_gateway_metrics',[])).alert);
  await denied(()=>db.query('DELETE FROM auth.users WHERE id=$1',[A]),'23503');
 });
 await test('late object blocks release; audited operator cleanup detaches FK and is idempotent',async()=>{
  const path=id+'/portfolio/'+unknown+'.png';
  await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,{size:10,mimetype:'image/png'}]); // synthetic late write, not production API
  await denied(()=>q('specialist_gateway_reject',[A,id,unknown,413]),'PT409');await retire(unknown,'begin');
  await denied(()=>retire(unknown,'finish'),'PT409');
  await db.query("DELETE FROM storage.objects WHERE bucket_id='specialist-media' AND name=$1",[path]); // tiny SQL fixture only; real suite uses Storage.remove
  assert((await retire(unknown,'finish')).retired);assert((await retire(unknown,'finish')).retired);
  assert.equal((await db.query("SELECT count(*)::int n FROM specialist_upload_audit WHERE request_id=$1",[unknown])).rows[0].n,2);
 });
 await test('upload switch off leaves deletion working; missing object metadata and data retained on failure',async()=>{
  await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));const r=await reserve(crypto.randomUUID());
  await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[r.object_name,{size:10,mimetype:'image/png'}]);
  await q('specialist_gateway_finish',[A,id,r.id]);await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
  const cap=await db.call(A,'get_my_specialist_upload_capability',[id]);assert(!cap.enabled&&cap.deletions_enabled);
  await denied(()=>reserve(crypto.randomUUID()),'55000');await q('specialist_gateway_begin_delete',[A,id,r.object_name]);
  await denied(()=>q('specialist_gateway_finish_delete',[A,id,r.id]),'PT409');
  await db.query("DELETE FROM storage.objects WHERE name=$1",[r.object_name]);await q('specialist_gateway_finish_delete',[A,id,r.id]);
 });
 await test('unexpected late orphan is observable and still consumes quota; no silent garbage collector',async()=>{
  const rid=crypto.randomUUID();await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));const r=await reserve(rid);await q('specialist_gateway_reject',[A,id,rid,400]);
  await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[r.object_name,{size:10,mimetype:'image/png'}]); // deliberately violates trusted terminal-response guarantee
  assert.equal((await q('specialist_gateway_metrics',[])).late_orphan_objects,1);assert((await q('specialist_gateway_metrics',[])).alert);
  for(let i=0;i<19;i++)await reserve(crypto.randomUUID());await denied(()=>reserve(crypto.randomUUID()),'54000');
  await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
  await retire(rid,'begin');assert.equal((await db.query('SELECT specialist_id FROM specialist_upload_reservations WHERE id=$1',[rid])).rows[0].specialist_id,id);
  await denied(()=>retire(rid,'finish'),'PT409');
  await db.query("DELETE FROM storage.objects WHERE name=$1",[r.object_name]); // synthetic teardown only
  assert((await retire(rid,'finish')).retired);assert.equal((await q('specialist_gateway_metrics',[])).late_orphan_objects,0);
 });
 await test('operator retirement permits Auth cascade without bypassing FK or deleting audit',async()=>{
  await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
  const rows=(await db.query("SELECT id FROM specialist_upload_reservations WHERE specialist_id=$1",[id])).rows;
  for(const r of rows){await retire(r.id,'begin');await retire(r.id,'finish');}
  await db.query('DELETE FROM auth.users WHERE id=$1',[A]);assert.equal((await db.query('SELECT count(*)::int n FROM specialist_profiles WHERE id=$1',[id])).rows[0].n,0);
  assert((await db.query('SELECT count(*)::int n FROM specialist_upload_audit')).rows[0].n>0);
 });
 if(process.env.REMEDIATION_CATALOG_PATH)await fs.writeFile(process.env.REMEDIATION_CATALOG_PATH,JSON.stringify((await db.query("SELECT oid::regprocedure::text signature,md5(pg_get_functiondef(oid)) definition_md5 FROM pg_proc WHERE pronamespace='public'::regnamespace AND (proname LIKE 'specialist_gateway_%' OR proname='get_my_specialist_upload_capability') ORDER BY 1")).rows,null,2));
 console.log('REMEDIATION SQL RESULT',n,'PASS; real concurrency='+db.concurrent+'; synthetic Auth/Storage fixture');
}finally{await db.close();}
