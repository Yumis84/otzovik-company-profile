import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import pg from 'pg';
import {database,A,B} from './database.mjs';
const db=await database({editor:true});
const file=f=>fs.readFile(new URL('../'+f,import.meta.url),'utf8');
const O='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', T='ffffffff-ffff-4fff-8fff-ffffffffffff';
const query=(c,name,args)=>c.query('SELECT public.'+name+'('+args.map((_,i)=>'$'+(i+1)).join(',')+') data',args).then(r=>r.rows[0].data);
const op=(who,name,args=[])=>db.session(who,c=>query(c,name,args),'specialist_operator');
try {
 await db.exec("DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF; END $$; GRANT USAGE ON SCHEMA public,storage TO service_role; DROP TRIGGER specialist_object_integrity ON storage.objects;");
 for(const p of ['60_GATEWAY','65_GATEWAY_REMEDIATION','66_SPECIALIST_OPERATOR']) await db.exec(await file('sql/release/'+p+'_CANDIDATE.sql'));
 for(const p of ['20261106_specialist_publication_foundation_CANDIDATE.sql','20261106_specialist_slug_quarantine_CANDIDATE.sql','20261112_specialist_erasure_barrier_CANDIDATE.sql']) await db.exec(await file('sql/'+p));
 await db.query('INSERT INTO auth.users VALUES($1),($2)',[O,T]); await db.query('INSERT INTO specialist_operator_identities(user_id) VALUES($1),($2)',[O,T]);
 await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));
 if(db.concurrent){
  const raceId=(await db.call(B,'create_my_specialist_draft',['Racer','erasure-race','Master'])).id;
  const pool=new pg.Pool({connectionString:process.env.TEST_DATABASE_URL,max:2});
  const confirming=await pool.connect(),uploading=await pool.connect();
  try {
   await confirming.query('BEGIN'); await confirming.query('SET LOCAL ROLE authenticated');
   await confirming.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[B]);
   await confirming.query('SELECT public.confirm_my_specialist_erasure($1,$2)',[raceId,crypto.randomUUID()]);
   let settled=false;
   const competing=uploading.query('SELECT public.specialist_gateway_reserve($1,$2,$3,$4,$5,$6,$7,$8)',[B,raceId,crypto.randomUUID(),'portfolio','c'.repeat(64),'image/png',10,null]).then(()=>({}),error=>({error})).finally(()=>{settled=true});
   await new Promise(resolve=>setTimeout(resolve,150)); assert.equal(settled,false,'upload waits behind erasure confirmation');
   await confirming.query('COMMIT'); assert.equal((await competing).error?.code,'42501');
  } finally {await confirming.query('ROLLBACK').catch(()=>{});confirming.release();uploading.release();await pool.end();}
  console.log('PASS PostgreSQL concurrent erasure versus upload admission');
 }
 const id=(await db.call(A,'create_my_specialist_draft',['Erase','erase-sample','Master'])).id;
 const revision=(await db.query("INSERT INTO public.specialist_public_revisions(specialist_id,client_request_id,source_version,slug,display_name,profession) VALUES ($1,gen_random_uuid(),1,'erase-sample','Erase','Master') RETURNING revision_id",[id])).rows[0].revision_id;
 await db.query("INSERT INTO public.specialist_publication_state(specialist_id,state,published_revision_id) VALUES ($1,'published',$2)",[id,revision]);
 const request=crypto.randomUUID(), confirmation=crypto.randomUUID();
 await query(db,'specialist_gateway_reserve',[A,id,request,'portfolio','a'.repeat(64),'image/png',10,null]);
 await assert.rejects(db.call(B,'confirm_my_specialist_erasure',[id,confirmation]),e=>e.code==='42501');
 assert.equal((await db.query('SELECT state FROM public.specialist_publication_state WHERE specialist_id=$1',[id])).rows[0].state,'published');
 const c=await db.call(A,'confirm_my_specialist_erasure',[id,confirmation]);
 assert.equal(c.confirmation_id,confirmation); assert.equal((await db.call(A,'confirm_my_specialist_erasure',[id,confirmation])).confirmation_id,confirmation);
 assert.deepEqual((await db.query('SELECT state,published_revision_id FROM public.specialist_publication_state WHERE specialist_id=$1',[id])).rows[0],{state:'erasing',published_revision_id:null});
 assert.equal((await db.query('SELECT profile_status FROM specialist_profiles WHERE id=$1',[id])).rows[0].profile_status,'erasing');
 await assert.rejects(db.call(A,'update_my_specialist_draft',[id,'New','Master',null,null,null]),e=>e.code==='42501');
 await assert.rejects(query(db,'specialist_gateway_reserve',[A,id,crypto.randomUUID(),'portfolio','b'.repeat(64),'image/png',10,null]),e=>e.code==='42501');
 await assert.rejects(db.query('DELETE FROM auth.users WHERE id=$1',[A]),e=>['23503','23001'].includes(e.code));
 assert.equal((await db.query("SELECT count(*)::int n FROM specialist_slug_tombstones_v1 WHERE slug='erase-sample'")).rows[0].n,0,'failed account deletion must roll back tombstone');
 await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
 const auth=(await op(O,'specialist_operator_authorize',[id,confirmation,null,'profile_erasure','OTZ-TEST-00000001'])).authorization_id;
 assert((await op(T,'specialist_operator_plan_erasure',[A,id,auth])).planned);
 const proof={mode:'confirmed_erasure',authorization_id:auth,request_id:request,kind:'provider_terminal_no_late_writer',evidence_ref:'synthetic-fixture-writers-stopped',all_writers_stopped:true};
 const retire=phase=>op(T,'specialist_gateway_force_retire',[A,id,request,phase,'unused','Synthetic approved erasure',proof]);
 await retire('begin'); assert((await retire('finish')).retired); assert((await retire('finish')).retired);
 await db.call(A,'delete_my_specialist_draft',[id]);
 assert.equal((await db.query('SELECT count(*)::int n FROM specialist_public_revisions WHERE specialist_id=$1',[id])).rows[0].n,0);
 assert.equal((await db.query("SELECT count(*)::int n FROM specialist_slug_tombstones_v1 WHERE slug='erase-sample'")).rows[0].n,1);
 console.log('PASS erasure barrier: ownership, hide, repeat, writer denial, FK restrict, operator retire, cascade and tombstone');
} finally {await db.close();}
