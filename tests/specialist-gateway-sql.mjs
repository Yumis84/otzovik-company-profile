import assert from 'node:assert/strict';import fs from 'node:fs/promises';import crypto from 'node:crypto';import {database,A,B} from './database.mjs';
const db=await database({editor:true});let n=0;const test=async(name,fn)=>{await fn();console.log('PASS GATEWAY SQL',++n,name);};
const file=f=>fs.readFile(new URL('../'+f,import.meta.url),'utf8');const denied=(fn,code)=>assert.rejects(fn,e=>!code||e.code===code);
try{
 await db.exec("DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF; END $$; GRANT USAGE ON SCHEMA public,storage TO service_role;");
 // Only a historical isolated fixture has the rejected managed trigger. Never install it hosted.
 await db.exec('DROP TRIGGER specialist_object_integrity ON storage.objects');
 await db.exec(await file('sql/20261027_specialist_upload_gateway_CANDIDATE.sql'));
 await db.exec(await file('sql/release/65_GATEWAY_REMEDIATION_CANDIDATE.sql'));await db.exec(await file('sql/release/66_SPECIALIST_OPERATOR_CANDIDATE.sql'));
 const id=(await db.call(A,'create_my_specialist_draft',['Gateway','gateway-sql','Master'])).id;
 const reserve=(rid,profile=id,owner=A)=>db.query("SELECT public.specialist_gateway_reserve($1,$2,$3,'portfolio',$4,'image/png',10,null) data",[owner,profile,rid,'a'.repeat(64)]).then(x=>x.rows[0].data);
 await test('disabled by default and private service-only ACL',async()=>{
  assert.equal((await db.call(A,'get_my_specialist_upload_capability',[id])).enabled,false);await denied(()=>reserve(crypto.randomUUID()),'55000');
  for(const role of ['authenticated','anon'])for(const name of ['specialist_gateway_reserve','specialist_gateway_finish','specialist_gateway_begin_delete','specialist_gateway_finish_delete','specialist_gateway_reconcile']){
   assert.equal((await db.query("SELECT has_function_privilege($1,oid,'EXECUTE') allowed FROM pg_proc WHERE proname=$2",[role,name])).rows[0].allowed,false);
  }
  await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));
 });
 let rid=crypto.randomUUID();
 await test('one-shot reservation, replay, foreign profile and changed payload',async()=>{
  const r=await reserve(rid);assert.equal(r.upload_allowed,true);assert.equal((await reserve(rid)).upload_allowed,false);
  await denied(()=>reserve(rid,id,B),'42501');
  await denied(()=>db.query("SELECT public.specialist_gateway_reserve($1,$2,$3,'portfolio',$4,'image/png',10,null)",[A,id,rid,'b'.repeat(64)]),'PT409');
  await denied(()=>db.call(A,'delete_my_specialist_draft',[id]),'55000');
  await denied(()=>db.query('DELETE FROM specialist_profiles WHERE id=$1',[id]),(db.concurrent?'23503':'23001'));
 });
 await test('unknown and expired uploads never release slots automatically',async()=>{
  await db.query("UPDATE specialist_upload_reservations SET expires_at=now()-interval '1 day' WHERE id=$1",[rid]);assert.equal((await reserve(rid)).upload_allowed,false);
  await denied(()=>db.query('SELECT specialist_gateway_finish($1,$2,$3)',[A,id,rid]),'PT409');
  const rows=(await db.query('SELECT specialist_gateway_reconcile($1,$2) data',[A,id])).rows[0].data;assert(rows[0].expired);assert(!rows[0].object_exists);
 });
 await test('20 reserved slots, competing transactions have one final winner',async()=>{
  for(let i=1;i<19;i++)await reserve(crypto.randomUUID());
  if(db.concurrent){const results=await Promise.allSettled([reserve(crypto.randomUUID()),reserve(crypto.randomUUID())]);assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(results.find(x=>x.status==='rejected').reason.code,'54000');}
  else {await reserve(crypto.randomUUID());await denied(()=>reserve(crypto.randomUUID()),'54000');}
  assert.equal((await db.query('SELECT count(*)::int n FROM specialist_upload_reservations')).rows[0].n,20);
 });
 await test('Storage insert/update/delete remain denied under accidental permissive grants',async()=>{
  await db.exec("CREATE POLICY accidental_all ON storage.objects FOR ALL TO authenticated USING(true) WITH CHECK(true); GRANT UPDATE ON storage.objects TO authenticated");
  const path=id+'/portfolio/'+crypto.randomUUID()+'.png';await denied(()=>db.session(A,c=>c.query("INSERT INTO storage.objects(bucket_id,name) VALUES('specialist-media',$1)",[path])),'42501');
  await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[id+'/portfolio/'+rid+'.png',{size:10,mimetype:'image/png'}]);
  assert.equal((await db.session(A,c=>c.query("UPDATE storage.objects SET name='stolen' WHERE bucket_id='specialist-media'"))).rowCount,0);
  assert.equal((await db.session(A,c=>c.query("DELETE FROM storage.objects WHERE bucket_id='specialist-media'"))).rowCount,0);
  await db.exec('DROP POLICY accidental_all ON storage.objects');
 });
 await test('recover acknowledged object, failed delete keeps metadata, dry-run and tombstone retry',async()=>{
  const media=(await db.query('SELECT specialist_gateway_finish($1,$2,$3) data',[A,id,rid])).rows[0].data;
  const r=(await db.query('SELECT specialist_gateway_begin_delete($1,$2,$3) data',[A,id,media.object_name])).rows[0].data;
  await denied(()=>db.query('SELECT specialist_gateway_finish_delete($1,$2,$3)',[A,id,r.id]),'PT409');
  assert.equal((await db.query('SELECT count(*)::int n FROM specialist_media')).rows[0].n,1);
  const before=(await db.query('SELECT count(*)::int n FROM specialist_upload_reservations')).rows[0].n;await db.query('SELECT specialist_gateway_reconcile($1,$2)',[A,id]);assert.equal((await db.query('SELECT count(*)::int n FROM specialist_upload_reservations')).rows[0].n,before);
  await db.query("DELETE FROM storage.objects WHERE bucket_id='specialist-media'");await db.query('SELECT specialist_gateway_finish_delete($1,$2,$3)',[A,id,r.id]);await db.query('SELECT specialist_gateway_finish_delete($1,$2,$3)',[A,id,r.id]);
  assert.equal((await reserve(rid)).state,'deleted');
 });
 await test('disable/enable retains existing private data and denies fresh work',async()=>{
  await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));await denied(()=>reserve(crypto.randomUUID()),'55000');assert.equal((await db.call(A,'get_my_specialist_upload_capability',[id])).enabled,false);
  await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));assert.equal((await db.call(A,'get_my_specialist_upload_capability',[id])).enabled,true);assert.equal((await db.query('SELECT count(*)::int n FROM specialist_upload_reservations')).rows[0].n,20);
 });
 console.log('GATEWAY SQL RESULT',n,'PASS; real concurrency='+db.concurrent+'; no hosted writes');
}finally{await db.close();}
