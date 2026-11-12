import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import {createClient} from '@supabase/supabase-js';
import {operatorFixture} from './operator-fixture.mjs';
import {planSpecialistErasure,prepareSpecialistErasure} from '../server/specialist-media-operator.js';
export async function erasureLocalChecks({admin,db,api,anon,jwtSecret,ok,test}){
 assert(['127.0.0.1','localhost'].includes(new URL(api).hostname));
 for(const f of ['20261106_specialist_publication_foundation_CANDIDATE.sql','20261106_specialist_slug_quarantine_CANDIDATE.sql','20261112_specialist_erasure_barrier_CANDIDATE.sql'])
  await db.query(await fs.readFile(new URL('../sql/'+f,import.meta.url),'utf8'));
 await db.query("NOTIFY pgrst,'reload schema'"); await new Promise(r=>setTimeout(r,1500));
 await test('real local Auth, Edge and Storage erasure barrier with operator retirement',async()=>{
  const email='barrier-'+crypto.randomUUID()+'@example.test',password='Test-'+crypto.randomUUID()+'!';
  const user=ok(await admin.auth.admin.createUser({email,password,email_confirm:true})).user;
  const owner=createClient(api,anon,{auth:{persistSession:false,autoRefreshToken:false}});
  ok(await owner.auth.signInWithPassword({email,password}));
  const slug='barrier-'+crypto.randomUUID().slice(0,12);
  const profile=ok(await owner.rpc('create_my_specialist_draft',{p_display_name:'Barrier test',p_slug:slug,p_profession:'Master'}));
  const session=ok(await owner.auth.getSession()).session;
  const bytes=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=','base64');
  async function upload(){return fetch(api+'/functions/v1/specialist-media-gateway',{method:'POST',headers:{apikey:anon,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify({action:'upload',specialist_id:profile.id,request_id:crypto.randomUUID(),kind:'portfolio',mime:'image/png',data:bytes.toString('base64'),caption:'synthetic'})});}
  const response=await upload();assert.equal(response.status,200,await response.text());
  assert((await admin.auth.admin.deleteUser(user.id)).error,'reservation must restrict account deletion');
  const confirmation=crypto.randomUUID();ok(await owner.rpc('confirm_my_specialist_erasure',{p_specialist_id:profile.id,p_confirmation_id:confirmation}));
  assert.equal((await db.query('SELECT state FROM specialist_publication_state WHERE specialist_id=$1',[profile.id])).rows[0].state,'erasing');
  assert((await owner.rpc('update_my_specialist_draft',{p_specialist_id:profile.id,p_display_name:'Changed',p_profession:'Master'})).error);
  assert.notEqual((await upload()).status,200,'no new upload after erasure confirmation');
  const [approver,operator]=await operatorFixture({api,anon,admin,db,jwtSecret,ok});
  const authorization=ok(await approver.rpc('specialist_operator_authorize',{p_specialist_id:profile.id,p_confirmation_id:confirmation,p_request_id:null,p_purpose:'profile_erasure',p_ticket:'OTZ-LOCAL-BARRIER-00000001'})).authorization_id;
  await db.query(await fs.readFile(new URL('../sql/release/DISABLE_MEDIA_CANDIDATE.sql',import.meta.url),'utf8'));
  const plan=await planSpecialistErasure({operator,owner:user.id,profile:profile.id,authorization});assert.equal(plan.reservations.length,1);
  const proofs=Object.fromEntries(plan.reservations.map(r=>[r.id,{kind:'provider_terminal_no_late_writer',mode:'confirmed_erasure',authorization_id:authorization,request_id:r.id,evidence_ref:'isolated-test:writer-finished:'+r.id,all_writers_stopped:true}]));
  const result=await prepareSpecialistErasure({operator,owner:user.id,profile:profile.id,authorization,plan,reason:'Synthetic local barrier check',proofs});assert(result.media_erased);
  ok(await admin.auth.admin.deleteUser(user.id));
  assert.equal((await db.query('SELECT count(*)::int n FROM specialist_profiles WHERE id=$1',[profile.id])).rows[0].n,0);
  assert.equal((await db.query('SELECT count(*)::int n FROM specialist_slug_tombstones_v1 WHERE slug=$1',[slug])).rows[0].n,1);
  assert.equal((await db.query("SELECT count(*)::int n FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=$1",[profile.id])).rows[0].n,0);
 });
}
