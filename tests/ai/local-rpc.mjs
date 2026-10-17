// Disposable loopback Supabase only. Never links to hosted project or reads production secrets.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import pg from 'pg';
import {createClient} from '@supabase/supabase-js';
const cfg=JSON.parse(await fs.readFile('/tmp/otzovik-local-status.json','utf8'));
for(const [value,port]of [[cfg.API_URL,'54321'],[cfg.DB_URL,'54322']]){const u=new URL(value);assert(['127.0.0.1','localhost'].includes(u.hostname)&&u.port===port,'Disposable loopback only');}
const db=new pg.Client({connectionString:cfg.DB_URL});await db.connect();
const admin=createClient(cfg.API_URL,cfg.SERVICE_ROLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});const users=[];let count=0;const pass=s=>console.log('PASS AI LOCAL',++count,s);
try{
 assert.equal((await db.query("SELECT to_regclass('public.companies') t")).rows[0].t,null);
 const fixture=await fs.readFile(new URL('../fixtures/schema.sql',import.meta.url),'utf8');await db.query(fixture.slice(fixture.indexOf('CREATE TABLE public.companies')));
 await db.query('CREATE TABLE public.specialist_profiles(id uuid PRIMARY KEY,owner_user_id uuid REFERENCES auth.users,profile_status text DEFAULT \'draft\')');
 await db.query(await fs.readFile(new URL('../../sql/AI_CONSULTANT_V1_CANDIDATE.sql',import.meta.url),'utf8'));
 for(let i=0;i<2;i++){
  const email=`ai-fixture-${crypto.randomUUID()}@example.invalid`,password=crypto.randomBytes(24).toString('base64url');
  const created=await admin.auth.admin.createUser({email,password,email_confirm:true});assert(!created.error,created.error?.message);const client=createClient(cfg.API_URL,cfg.ANON_KEY,{auth:{persistSession:false,autoRefreshToken:false}});const signed=await client.auth.signInWithPassword({email,password});assert(!signed.error,signed.error?.message);assert(signed.data.session?.access_token);users.push({id:created.data.user.id,token:signed.data.session.access_token});
 }
 pass('two real Auth password sessions; emails preconfirmed by disposable admin, delivery NOT tested');
 const id=crypto.randomUUID(),sid=crypto.randomUUID();await db.query("INSERT INTO companies(id,slug,name) VALUES($1,'ai-fixture','AI Fixture')",[id]);await db.query("INSERT INTO company_memberships(company_id,user_id,role,verification_status) VALUES($1,$2,'owner','verified')",[id,users[0].id]);await db.query('INSERT INTO specialist_profiles(id,owner_user_id) VALUES($1,$2)',[sid,users[1].id]);
 await db.query("NOTIFY pgrst,'reload schema'");await new Promise(r=>setTimeout(r,1500));
 const rpc=async(user,name,body)=>{const r=await fetch(cfg.API_URL+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:cfg.ANON_KEY,Authorization:'Bearer '+(user?.token||cfg.ANON_KEY),'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});return {status:r.status,data:await r.json()};};
 const ref={profile_kind:'company',profile_id:id};const settings={enabled:false,greeting:'Привет',instructions:'Кратко',extra_information:'',position:'inline'};
 let r=await rpc(users[0],'get_my_ai_config',ref);assert.equal(r.status,200);assert.equal(r.data.version,0);
 r=await rpc(users[0],'save_my_ai_config',{...ref,expected_version:0,settings});assert.equal(r.status,200);assert.equal(r.data.version,1);assert.equal((await rpc(users[0],'get_my_ai_config',ref)).data.greeting,'Привет');pass('real JWT owner saves/reloads new RPC settings');
 r=await rpc(users[0],'save_my_ai_config',{...ref,expected_version:0,settings});assert.equal(r.status,409);assert.equal(r.data.code,'PT409');pass('PostgREST preserves explicit HTTP409 conflict');
 for(const u of [users[1],null]){r=await rpc(u,'get_my_ai_config',ref);assert([401,403].includes(r.status));assert.equal(r.data.code,'42501');}pass('foreign owner and anonymous RPC denied through real PostgREST');
 r=await rpc(users[0],'get_my_ai_snapshot',ref);assert.equal(r.status,503);assert.equal(r.data.code,'PT503');await db.query('DELETE FROM ai_private.platform');assert.equal((await rpc(users[0],'get_my_ai_snapshot',ref)).status,503);await db.query('INSERT INTO ai_private.platform VALUES(true,false)');pass('PostgREST HTTP503 kill switch and missing row fail closed');
 assert.equal((await rpc(users[0],'get_my_ai_snapshot',ref)).data,null);await db.query("INSERT INTO ai_private.snapshots(kind,profile_id,revision,payload) VALUES('company',$1,'verified-test-revision',$2)",[id,{name:'Synthetic published fixture'}]);assert.equal((await rpc(users[0],'get_my_ai_snapshot',ref)).data.revision,'verified-test-revision');assert.equal((await rpc(users[1],'get_my_ai_snapshot',{profile_kind:'specialist',profile_id:sid})).data,null);pass('explicit synthetic snapshot only; specialist draft returns no snapshot');
 r=await rpc(users[0],'save_my_ai_config',{...ref,expected_version:1,settings:{...settings,enabled:'invalid'}});assert.equal(r.status,400);assert.equal(r.data.code,'22023');await db.query("UPDATE company_memberships SET verification_status='revoked' WHERE company_id=$1",[id]);assert.equal((await rpc(users[0],'get_my_ai_config',ref)).status,403);pass('invalid type HTTP400 and live membership revocation HTTP403');
 await db.query(await fs.readFile(new URL('../../sql/AI_CONSULTANT_V1_DISABLE_CANDIDATE.sql',import.meta.url),'utf8'));assert.equal((await rpc(users[0],'save_my_ai_config',{...ref,expected_version:1,settings})).status,403);await db.query(await fs.readFile(new URL('../../sql/AI_CONSULTANT_V1_ENABLE_CANDIDATE.sql',import.meta.url),'utf8'));assert.equal((await db.query('SELECT enabled FROM ai_private.configs')).rows[0].enabled,false);pass('disable/enable under local deployment postgres retains profile disabled');
 console.log(`PASS ${count} NEW AI RPC real Auth/PostgREST groups; no hosted project, no provider calls`);
}finally{for(const u of users)await admin.auth.admin.deleteUser(u.id);await db.end();}
