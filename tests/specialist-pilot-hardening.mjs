import assert from 'node:assert/strict';import fs from 'node:fs/promises';import crypto from 'node:crypto';import {database,A,B} from './database.mjs';
const db=await database({editor:true}),file=f=>fs.readFile(new URL('../'+f,import.meta.url),'utf8'),O='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',T='ffffffff-ffff-4fff-8fff-ffffffffffff';
let n=0;const test=async(name,fn)=>{await fn();console.log('PASS PILOT SQL',++n,name);},denied=(fn,code)=>assert.rejects(fn,e=>!code||e.code===code);
const query=(c,name,args)=>c.query('SELECT public.'+name+'('+args.map((_,i)=>'$'+(i+1)).join(',')+') data',args).then(r=>r.rows[0].data);
const root=(name,args=[])=>query(db,name,args),op=(who,name,args=[])=>db.session(who,c=>query(c,name,args),'specialist_operator');
try{
 await db.exec("DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF; END $$; GRANT USAGE ON SCHEMA public,storage TO service_role; DROP TRIGGER specialist_object_integrity ON storage.objects;");
 for(const p of ['60_GATEWAY','65_GATEWAY_REMEDIATION','66_SPECIALIST_OPERATOR'])await db.exec(await file('sql/release/'+p+'_CANDIDATE.sql'));
 await db.query('INSERT INTO auth.users VALUES($1),($2)',[O,T]);await db.query('INSERT INTO specialist_operator_identities(user_id) VALUES($1),($2)',[O,T]);
 if(process.env.PILOT_CATALOG_PATH)await fs.writeFile(process.env.PILOT_CATALOG_PATH,JSON.stringify((await db.query("SELECT oid::regprocedure::text signature,md5(pg_get_functiondef(oid)) definition_md5,has_function_privilege('anon',oid,'EXECUTE') anon_execute,has_function_privilege('authenticated',oid,'EXECUTE') auth_execute,has_function_privilege('service_role',oid,'EXECUTE') service_execute,has_function_privilege('specialist_operator',oid,'EXECUTE') operator_execute FROM pg_proc WHERE pronamespace='public'::regnamespace AND (proname LIKE 'specialist_%' OR proname LIKE '%specialist%') ORDER BY 1")).rows,null,2));
 await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));
 const p=await db.call(A,'create_my_specialist_draft',['Pilot','pilot','Master']),id=p.id,rid=crypto.randomUUID();
 const reserve=(request,profile=id)=>root('specialist_gateway_reserve',[A,profile,request,'portfolio','a'.repeat(64),'image/png',10,null]);
 const confirmed=crypto.randomUUID();let authorization;
 const proof=(request,mode='confirmed_erasure',auth=authorization)=>({mode,authorization_id:auth,request_id:request,kind:'provider_terminal_no_late_writer',evidence_ref:'isolated-fixture:all-writers-joined:'+request,all_writers_stopped:true});
 const retire=(request,phase,pr=proof(request),who=T)=>op(who,'specialist_gateway_force_retire',[A,id,request,phase,'forged-actor-label','Synthetic approved erasure',pr]);
 await test('Edge credentials cannot authorize, force-retire, inventory or orphan cleanup',async()=>{
  for(const name of ['specialist_operator_authorize','specialist_operator_plan_erasure','specialist_gateway_force_retire','specialist_gateway_erasure_inventory','specialist_operator_cleanup_orphan'])assert.equal((await db.query("SELECT has_function_privilege('service_role',oid,'EXECUTE') ok FROM pg_proc WHERE proname=$1",[name])).rows[0].ok,false);
  assert.equal((await db.query("SELECT rolbypassrls OR rolcanlogin OR rolcreaterole unsafe FROM pg_roles WHERE rolname='specialist_operator'")).rows[0].unsafe,false);
  for(const table of ['specialist_operator_identities','specialist_erasure_confirmations','specialist_erasure_authorizations','specialist_upload_audit'])for(const role of ['service_role','specialist_operator','authenticated','anon'])assert.equal((await db.query("SELECT has_table_privilege($1,$2,'SELECT,INSERT,UPDATE,DELETE') ok",[role,table])).rows[0].ok,false);
 });
 await db.exec("CREATE POLICY accidental_operator ON storage.objects FOR ALL TO specialist_operator USING(true) WITH CHECK(true)");
 await test('owner confirmation, registered identity and independent approval are required',async()=>{
  await denied(()=>db.call(B,'confirm_my_specialist_erasure',[id,confirmed]),'42501');
  await denied(()=>op(A,'specialist_operator_authorize',[id,confirmed,null,'profile_erasure','OTZ-TEST-00000001']),'42501');
  await denied(()=>op(O,'specialist_operator_authorize',[id,confirmed,null,'profile_erasure','OTZ-TEST-00000001']),'42501');
  await db.call(A,'confirm_my_specialist_erasure',[id,confirmed]);
  authorization=(await op(O,'specialist_operator_authorize',[id,confirmed,null,'profile_erasure','OTZ-TEST-00000001'])).authorization_id;
 });
 await test('ready media rejects quarantine mode and self-approval; actor derives from verified identity',async()=>{
  const r=await reserve(rid);await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[r.object_name,{size:10,mimetype:'image/png'}]);await root('specialist_gateway_finish',[A,id,rid]);
  await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
  await denied(()=>retire(rid,'begin',proof(rid,'quarantine_retire')),'42501');
  await denied(()=>retire(rid,'begin',proof(rid),O),'42501');await retire(rid,'begin');
  assert.equal((await db.query("SELECT actor FROM specialist_upload_audit WHERE request_id=$1 AND action='operator_begin'",[rid])).rows[0].actor,T);
  await denied(()=>retire(rid,'finish'),'PT409');
  assert.equal((await db.session(O,c=>c.query("DELETE FROM storage.objects WHERE name=$1",[r.object_name]),'specialist_operator')).rowCount,0);
  assert.equal((await db.session(T,c=>c.query("DELETE FROM storage.objects WHERE name=$1",[r.object_name]),'specialist_operator')).rowCount,1);
  await retire(rid,'finish');assert((await retire(rid,'finish')).retired);
 });
 await test('two-phase legacy plan creates stable IDs and never deletes or changes ready media',async()=>{
  const path=id+'/portfolio/'+crypto.randomUUID()+'.png';await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,{size:10,mimetype:'image/png'}]);
  await db.query('UPDATE specialist_upload_control SET deletions_enabled=false');
  const plan=await op(T,'specialist_operator_plan_erasure',[A,id,authorization]),again=await op(T,'specialist_operator_plan_erasure',[A,id,authorization]);
  assert(plan.planned);assert.equal(plan.reservations[0].id,again.reservations[0].id);assert.equal((await db.query("SELECT count(*)::int n FROM storage.objects WHERE name=$1",[path])).rows[0].n,1);
  const request=plan.reservations[0].id;assert.equal((await db.query('SELECT state FROM specialist_upload_reservations WHERE id=$1',[request])).rows[0].state,'ready');
  await retire(request,'begin');await db.session(T,c=>c.query("DELETE FROM storage.objects WHERE name=$1",[path]),'specialist_operator');await retire(request,'finish');
 });
 let orphanRequest,orphanProfile,path;
 await test('create audited tombstone, delete profile, then reproduce late orphan severity critical',async()=>{
  await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));orphanProfile=(await db.call(A,'create_my_specialist_draft',['Orphan','pilot-orphan','Master'])).id;orphanRequest=crypto.randomUUID();
  const r=await reserve(orphanRequest,orphanProfile);path=r.object_name;await root('specialist_gateway_reject',[A,orphanProfile,orphanRequest,413]);await db.call(A,'delete_my_specialist_draft',[orphanProfile]);
  await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,{size:10,mimetype:'image/png'}]);await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
  const m=await root('specialist_gateway_metrics');assert.equal(m.severity,'critical');assert(m.critical_orphan);
 });
 await test('post-deletion cleanup is narrowly authorized, audited, idempotent and has no caller path',async()=>{
  await denied(()=>op(O,'specialist_operator_authorize',[id,null,orphanRequest,'orphan_cleanup','OTZ-TEST-00000002']),'42501');
  const auth=(await op(O,'specialist_operator_authorize',[orphanProfile,null,orphanRequest,'orphan_cleanup','OTZ-TEST-00000002'])).authorization_id,pr=proof(orphanRequest,'orphan_cleanup',auth);
  await denied(()=>op(O,'specialist_operator_cleanup_orphan',[orphanRequest,'begin',pr]),'42501');
  await op(T,'specialist_operator_cleanup_orphan',[orphanRequest,'begin',pr]);await denied(()=>op(T,'specialist_operator_cleanup_orphan',[orphanRequest,'finish',pr]),'PT409');
  assert.equal((await db.session(T,c=>c.query("DELETE FROM storage.objects WHERE name=$1",[path]),'specialist_operator')).rowCount,1);
  assert((await op(T,'specialist_operator_cleanup_orphan',[orphanRequest,'finish',pr])).deleted);assert((await op(T,'specialist_operator_cleanup_orphan',[orphanRequest,'finish',pr])).deleted);
  assert((await op(T,'specialist_operator_cleanup_orphan',[orphanRequest,'begin',pr])).deleted);
  assert.equal((await db.query("SELECT count(*)::int n FROM specialist_upload_audit WHERE request_id=$1 AND action='orphan_begin'",[orphanRequest])).rows[0].n,1);
  assert.equal((await root('specialist_gateway_metrics')).critical_orphan,false);
  assert.equal((await db.query("SELECT count(*)::int n FROM specialist_upload_audit WHERE request_id=$1 AND action='orphan_finish'",[orphanRequest])).rows[0].n,1);
  await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,{size:10,mimetype:'image/png'}]);
  await denied(()=>op(T,'specialist_operator_cleanup_orphan',[orphanRequest,'begin',pr]),'PT409');
  assert.equal((await db.session(T,c=>c.query("DELETE FROM storage.objects WHERE name=$1",[path]),'specialist_operator')).rowCount,0,'Completed proof must not leave Storage permission open');
  await db.query("DELETE FROM storage.objects WHERE name=$1",[path]); // deliberate trust-violation teardown in tiny fixture

 });
 await test('20 terminal failures reuse slots; unknown/TTL retains quota and warning severity',async()=>{
  await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));
  for(let i=0;i<20;i++){const request=crypto.randomUUID();await reserve(request);await root('specialist_gateway_reject',[A,id,request,413]);assert.equal((await reserve(request)).upload_allowed,false);}
  const unknown=crypto.randomUUID();await reserve(unknown);for(const status of [408,409,500])await denied(()=>root('specialist_gateway_reject',[A,id,unknown,status]),'22023');
  await db.query("UPDATE specialist_upload_reservations SET expires_at=now()-interval '1 day' WHERE id=$1",[unknown]);const m=await root('specialist_gateway_metrics');assert.equal(m.severity,'warning');assert(m.warning_quarantine&&!m.critical_orphan);
  for(let i=1;i<19;i++)await reserve(crypto.randomUUID());
  if(db.concurrent){const r=await Promise.allSettled([reserve(crypto.randomUUID()),reserve(crypto.randomUUID())]);assert.equal(r.filter(x=>x.status==='fulfilled').length,1);}else await reserve(crypto.randomUUID());await denied(()=>reserve(crypto.randomUUID()),'54000');
  const extra=id+'/portfolio/'+crypto.randomUUID()+'.png';await db.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[extra,{size:10,mimetype:'image/png'}]);
  const over=await root('specialist_gateway_metrics');assert(over.critical_over_quota&&over.alert);assert.equal(over.severity,'critical');assert.equal(over.over_quota_profiles,1);await db.query("DELETE FROM storage.objects WHERE name=$1",[extra]);
 });
 await test('audited erasure clears Auth cascade FK, operator registry revocation closes access',async()=>{
  await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));await denied(()=>db.query('DELETE FROM auth.users WHERE id=$1',[A]),'23503');
  for(const {id:request}of (await db.query('SELECT id FROM specialist_upload_reservations WHERE specialist_id=$1',[id])).rows){await retire(request,'begin');await retire(request,'finish');}
  await db.query('DELETE FROM auth.users WHERE id=$1',[A]);assert.equal((await db.query('SELECT count(*)::int n FROM specialist_profiles WHERE id=$1',[id])).rows[0].n,0);
  await db.query('UPDATE specialist_operator_identities SET enabled=false WHERE user_id=$1',[T]);await denied(()=>op(T,'specialist_gateway_erasure_inventory',[A,id]),'42501');
 });
 console.log('PILOT SQL RESULT',n,'PASS; synthetic Auth/Storage; PG concurrency='+db.concurrent);
}finally{await db.close();}
