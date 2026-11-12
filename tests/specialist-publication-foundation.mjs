import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import pg from 'pg';
import {database,A,B} from './database.mjs';

const db=await database();
try {
 await db.exec(await fs.readFile(new URL('../sql/20261106_specialist_publication_foundation_CANDIDATE.sql',import.meta.url),'utf8'));
 await db.exec(await fs.readFile(new URL('../sql/20261106_specialist_slug_quarantine_CANDIDATE.sql',import.meta.url),'utf8'));
 await db.exec(await fs.readFile(new URL('../sql/20261112_specialist_revision_retention_CANDIDATE.sql',import.meta.url),'utf8'));
 const id=(await db.call(A,'create_my_specialist_draft',['Specialist','foundation-one','Master'])).id;
 const version=async()=>Number((await db.query('SELECT version FROM public.specialist_profiles WHERE id=$1',[id])).rows[0].version);
 assert.equal(await version(),1);
 await db.call(A,'update_my_specialist_draft',[id,'Specialist','Master',null,null,null]);
 assert.equal(await version(),1,'unchanged public fields do not advance version');
 await db.call(A,'update_my_specialist_draft',[id,'Specialist','Master','Builder','City','Description']);
 assert.equal(await version(),2);
 await assert.rejects(db.call(B,'update_my_specialist_draft',[id,'Foreign','Master',null,null,null]),e=>e.code==='42501');
 assert.equal(await version(),2);
 for(const slug of ['mail','vpn','hello--world'])
  await assert.rejects(db.call(B,'create_my_specialist_draft',['Other',slug,'Master']),e=>e.code==='22023');
 // Exercise FORCE RLS with a table/function owner that does not bypass RLS.
 await db.exec('CREATE ROLE publication_owner_fixture NOLOGIN NOSUPERUSER NOBYPASSRLS; ALTER TABLE public.specialist_reserved_slugs_v1 OWNER TO publication_owner_fixture; ALTER FUNCTION public.specialist_slug_policy_v1() OWNER TO publication_owner_fixture; ALTER TABLE public.specialist_slug_tombstones_v1 OWNER TO publication_owner_fixture; ALTER FUNCTION public.specialist_slug_quarantine_v1() OWNER TO publication_owner_fixture; ALTER FUNCTION public.specialist_slug_quarantine_purge_v1() OWNER TO publication_owner_fixture;');
 await assert.rejects(db.call(B,'create_my_specialist_draft',['Other','mail','Master']),e=>e.code==='22023','reserved list remains effective for a non-bypass owner');
 await db.call(B,'create_my_specialist_draft',['Other','allowed-two','Master']);
 // Specialist policy must not alter the existing company slug contract.
 await db.query("INSERT INTO public.companies(id,slug,name) VALUES (gen_random_uuid(),'mail','Company')");
 await db.query("DELETE FROM public.companies WHERE slug='mail'");
 await db.query("INSERT INTO public.companies(id,slug,name) VALUES (gen_random_uuid(),'mail','Company')");
 const tables=['specialist_public_revisions','specialist_publication_state','specialist_public_control','specialist_reserved_slugs_v1','specialist_slug_tombstones_v1'];
 for(const table of tables){
  const row=(await db.query("SELECT relrowsecurity,relforcerowsecurity FROM pg_class WHERE oid=$1::regclass",['public.'+table])).rows[0];
  assert.equal(row.relrowsecurity,true,table);assert.equal(row.relforcerowsecurity,true,table);
  for(const role of ['anon','authenticated','service_role'])
   for(const privilege of ['SELECT','INSERT','UPDATE','DELETE'])
    assert.equal((await db.query('SELECT has_table_privilege($1,$2,$3) AS allowed',[role,'public.'+table,privilege])).rows[0].allowed,false,role+':'+table+':'+privilege);
 }
 for(const fn of ['specialist_public_fields_version_v1()','specialist_slug_policy_v1()','specialist_revision_immutable_v1()','specialist_slug_quarantine_v1()','specialist_slug_quarantine_purge_v1()','specialist_revision_insert_lock_v1()','specialist_revision_retention_v1()'])
  for(const role of ['anon','authenticated','service_role'])
   assert.equal((await db.query('SELECT has_function_privilege($1,$2,$3) AS allowed',[role,'public.'+fn,'EXECUTE'])).rows[0].allowed,false,role+':'+fn);
 if(db.concurrent){
  const raceId=(await db.call(B,'create_my_specialist_draft',['Racer','race-claim','Master'])).id;
  const pool=new pg.Pool({connectionString:process.env.TEST_DATABASE_URL,max:2});
  const deleting=await pool.connect(),claiming=await pool.connect();
  try {
   await deleting.query('BEGIN');
   await deleting.query('DELETE FROM public.specialist_profiles WHERE id=$1',[raceId]);
   let settled=false;
   const claim=claiming.query("INSERT INTO public.companies(id,slug,name) VALUES (gen_random_uuid(),'race-claim','Racer')").then(()=>({}),error=>({error})).finally(()=>{settled=true;});
   await new Promise(resolve=>setTimeout(resolve,150));
   assert.equal(settled,false,'claim waits for uncommitted specialist deletion');
   await deleting.query('COMMIT');
   assert.equal((await claim).error?.code,'23505','committed tombstone blocks concurrent company claim');
  } finally {await deleting.query('ROLLBACK').catch(()=>{});deleting.release();claiming.release();await pool.end();}
  console.log('PASS PostgreSQL concurrent delete vs company slug claim');
 }
 assert.equal((await db.query('SELECT enabled FROM public.specialist_public_control')).rows[0].enabled,false);
 const rev=(await db.query("INSERT INTO public.specialist_public_revisions(specialist_id,client_request_id,source_version,slug,display_name,profession) VALUES ($1,gen_random_uuid(),2,'foundation-one','Specialist','Master') RETURNING revision_id",[id])).rows[0].revision_id;
 await assert.rejects(db.query('UPDATE public.specialist_public_revisions SET display_name=$1 WHERE specialist_id=$2',['Modified',id]),e=>e.code==='55000');
 await db.query("INSERT INTO public.specialist_publication_state(specialist_id,state,published_revision_id) VALUES ($1,'published',$2)",[id,rev]);
 for(let i=0;i<3;i++) await db.query("INSERT INTO public.specialist_public_revisions(specialist_id,client_request_id,source_version,slug,display_name,profession) VALUES ($1,gen_random_uuid(),2,'foundation-one','Specialist','Master')",[id]);
 assert.equal((await db.query('SELECT count(*)::int AS n FROM public.specialist_public_revisions WHERE specialist_id=$1',[id])).rows[0].n,2);
 assert.equal((await db.query('SELECT count(*)::int AS n FROM public.specialist_public_revisions WHERE specialist_id=$1 AND revision_id=$2',[id,rev])).rows[0].n,1,'published revision is retained');
 await db.exec('ALTER FUNCTION public.specialist_revision_insert_lock_v1() OWNER TO publication_owner_fixture');
 await assert.rejects(db.query("INSERT INTO public.specialist_public_revisions(specialist_id,client_request_id,source_version,slug,display_name,profession) VALUES ($1,gen_random_uuid(),2,'foundation-one','Specialist','Master')",[id]),e=>e.code==='42501','non-bypass retention owner must fail closed');
 await db.query('DELETE FROM auth.users WHERE id=$1',[A]);
 assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.specialist_public_revisions WHERE specialist_id=$1',[id])).rows[0].n),0);
 assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.specialist_publication_state WHERE specialist_id=$1',[id])).rows[0].n),0);
 const tomb=(await db.query('SELECT slug,hold_until FROM public.specialist_slug_tombstones_v1 WHERE slug=$1',['foundation-one'])).rows[0];
 assert.ok(tomb); assert.ok(new Date(tomb.hold_until).getTime()-Date.now()>89*86400*1000);
 await assert.rejects(db.call(B,'create_my_specialist_draft',['Other','foundation-one','Master']),e=>e.code==='23505');
 await assert.rejects(db.query("INSERT INTO public.companies(id,slug,name) VALUES (gen_random_uuid(),'foundation-one','Company')"),e=>e.code==='23505');
 await db.query("UPDATE public.specialist_slug_tombstones_v1 SET hold_until=clock_timestamp()-interval '1 second' WHERE slug='foundation-one'");
 await db.query("INSERT INTO public.companies(id,slug,name) VALUES (gen_random_uuid(),'foundation-one','Company')");
 assert.equal((await db.query("SELECT count(*)::int AS n FROM public.specialist_slug_tombstones_v1 WHERE slug='foundation-one'")).rows[0].n,0);
 await db.query("INSERT INTO public.specialist_slug_tombstones_v1 VALUES ('expired-name',clock_timestamp()-interval '1 second'), ('held-name',clock_timestamp()+interval '90 days')");
 assert.equal(Number((await db.query('SELECT public.specialist_slug_quarantine_purge_v1() AS n')).rows[0].n),1);
 assert.equal((await db.query("SELECT count(*)::int AS n FROM public.specialist_slug_tombstones_v1 WHERE slug='held-name'")).rows[0].n,1);
 console.log('PASS publication foundation: version, tenant denial, slug isolation, FORCE RLS, ACL, immutable revision and cascade; disposable SQL model only');
} finally {await db.close();}
