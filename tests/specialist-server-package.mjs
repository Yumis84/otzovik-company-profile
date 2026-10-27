import assert from 'node:assert/strict';import fs from 'node:fs/promises';import {database,A} from './database.mjs';import {serverPackage} from '../scripts/specialist-server-package.mjs';
const db=await database();const file=f=>fs.readFile(new URL('../'+f,import.meta.url),'utf8');let n=0;const test=async(name,fn)=>{await fn();console.log('PASS PACKAGE',++n,name);};
try{
 await db.exec("DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF; END $$; CREATE SCHEMA storage; CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]); CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text UNIQUE,metadata jsonb); ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY; GRANT USAGE ON SCHEMA storage TO authenticated,service_role; GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO authenticated; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon,authenticated,service_role;");
 const pins=JSON.parse(await file('docs/SPECIALIST_GATEWAY_PRODUCTION_BASELINE_2026-10-27.json'));
 for(const f of pins.functions){await db.exec(f.definition);await db.exec('REVOKE ALL ON FUNCTION public.'+f.signature+' FROM PUBLIC,anon,authenticated,service_role; GRANT EXECUTE ON FUNCTION public.'+f.signature+' TO service_role,authenticated;');}
 let preflight=await file(serverPackage[0]);preflight=preflight.slice(preflight.indexOf('DO $preflight$'),preflight.indexOf("END $preflight$;")+"END $preflight$;".length);
 // Only Storage's policy baseline is intentionally different in this tiny SQL fixture.
 // The exact original file was ALSO executed read-only against actual production.
 const fixturePolicyHash=(await db.query("SELECT md5('') h")).rows[0].h;const fixturePreflight=preflight.replace(pins.storage_policies_md5,fixturePolicyHash);
 await test('production core definitions/schema pins; fixture-bound policy hash',async()=>{await db.exec(fixturePreflight);});
 await test('unexpected ACL and definition drift stop before any schema installation',async()=>{
  await db.exec('GRANT EXECUTE ON FUNCTION public.get_my_specialists() TO anon');await assert.rejects(()=>db.exec(fixturePreflight),/ACL drift/);await db.exec('REVOKE EXECUTE ON FUNCTION public.get_my_specialists() FROM anon');
  await db.exec("COMMENT ON FUNCTION public.get_my_specialists() IS 'comment does not alter function definition'");await db.exec(fixturePreflight);
  await db.exec("ALTER FUNCTION public.get_my_specialists() SET search_path=public");await assert.rejects(()=>db.exec(fixturePreflight),/function drift/);await db.exec(pins.functions.find(f=>f.signature==='get_my_specialists()').definition);
 });
 await test('split package assembles without managed trigger and stays disabled',async()=>{
  for(const f of serverPackage.slice(1)){
   if(f.includes('30_MEDIA'))await db.query("INSERT INTO storage.buckets VALUES('specialist-media','specialist-media',false,5242880,ARRAY['image/png','image/jpeg','image/webp'])");
   await db.exec(await file(f));
  }
  assert.equal((await db.query("SELECT count(*)::int n FROM pg_trigger WHERE tgname='specialist_object_integrity'")).rows[0].n,0);
  assert.equal((await db.query('SELECT enabled FROM specialist_upload_control')).rows[0].enabled,false);
  for(const name of ['get_my_specialist_services','save_my_specialist_settings','list_my_specialist_channels'])assert.equal((await db.query("SELECT has_function_privilege('authenticated',oid,'EXECUTE') allowed FROM pg_proc WHERE proname=$1",[name])).rows[0].allowed,false);
  console.log('CORE CANDIDATE MD5',(await db.query("SELECT md5(pg_get_functiondef('public.create_my_specialist_draft(text,text,text,text,text,text)'::regprocedure)) h")).rows[0].h);
 });
 await test('explicit capability enable/disable, no records dropped and baseline replay rejected',async()=>{
  await assert.rejects(()=>db.exec(fixturePreflight),/drift|pristine/);
  for(const m of ['SERVICES','SETTINGS','CHANNELS'])await db.exec(await file('sql/release/ENABLE_'+m+'_CANDIDATE.sql'));await db.exec(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));
  if(process.env.GATEWAY_CATALOG_PATH){const rows=(await db.query("SELECT oid::regprocedure::text signature,md5(pg_get_functiondef(oid)) definition_md5,prosecdef,proconfig,has_function_privilege('anon',oid,'EXECUTE') anon_execute,has_function_privilege('authenticated',oid,'EXECUTE') auth_execute,has_function_privilege('service_role',oid,'EXECUTE') service_execute FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE '%specialist%' ORDER BY oid::regprocedure::text")).rows;await fs.writeFile(process.env.GATEWAY_CATALOG_PATH,JSON.stringify({engine:'PostgreSQL17 isolated fixture',phase:'all enabled before disable tests',functions:rows},null,2));}
  const p=await db.call(A,'create_my_specialist_draft',['Package','package-test','Master']);assert.equal((await db.call(A,'get_my_specialist_upload_capability',[p.id])).enabled,true);
  for(const m of ['SERVICES','SETTINGS','CHANNELS'])await db.exec(await file('sql/release/DISABLE_'+m+'_CANDIDATE.sql'));await db.exec(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));
  assert((await db.call(A,'get_my_specialists')).some(x=>x.id===p.id));
 });
 await test('pinned core rollback and core switch preserve all data',async()=>{
  const before=(await db.query('SELECT count(*)::int n FROM specialist_profiles')).rows[0].n;
  await db.exec(await file('sql/release/RESTORE_CORE_CREATE_CANDIDATE.sql'));
  assert.equal((await db.query("SELECT md5(pg_get_functiondef('public.create_my_specialist_draft(text,text,text,text,text,text)'::regprocedure)) h")).rows[0].h,pins.functions.find(f=>f.signature.startsWith('create_')).md5);
  assert.equal((await db.query('SELECT count(*)::int n FROM specialist_profiles')).rows[0].n,before);
  await db.exec(await file('sql/release/DISABLE_CORE_CREATE_CANDIDATE.sql'));await assert.rejects(()=>db.call(A,'create_my_specialist_draft',['Disabled','disabled-core','Master']));
  await db.exec(await file('sql/release/ENABLE_CORE_CREATE_CANDIDATE.sql'));assert((await db.call(A,'create_my_specialist_draft',['Restored','restored-core','Master'])).id);
 });
 console.log('PACKAGE RESULT',n,'PASS; actual production baseline read-only result is separate');
}finally{await db.close();}
