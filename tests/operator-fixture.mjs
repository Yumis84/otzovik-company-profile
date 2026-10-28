import assert from 'node:assert/strict';import crypto from 'node:crypto';import {createClient} from '@supabase/supabase-js';
// LOCAL-ONLY fixture issuer: real Auth sessions + local ephemeral signing secret.
// No production credential/issuer provisioning is performed or inferred.
export async function operatorFixture({api,anon,admin,db,jwtSecret,ok}){
 assert(['127.0.0.1','localhost'].includes(new URL(api).hostname));assert(jwtSecret,'Disposable local JWT_SECRET required');
 const clients=[];
 for(let i=0;i<2;i++){
  const email='operator-'+crypto.randomUUID()+'@example.test',password='Operator-'+crypto.randomUUID()+'!';
  const user=ok(await admin.auth.admin.createUser({email,password,email_confirm:true})).user;
  const c=createClient(api,anon,{auth:{persistSession:false,autoRefreshToken:false}});const login=ok(await c.auth.signInWithPassword({email,password}));
  const [,payload]=login.session.access_token.split('.');const header=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');const claims=JSON.parse(Buffer.from(payload,'base64url'));
  claims.role='specialist_operator';claims.exp=Math.floor(Date.now()/1000)+900;
  const token=header+'.'+Buffer.from(JSON.stringify(claims)).toString('base64url');
  const signed=token+'.'+crypto.createHmac('sha256',jwtSecret).update(token).digest('base64url');
  ok(await c.auth.setSession({access_token:signed,refresh_token:login.session.refresh_token}));assert.equal(ok(await c.auth.getUser()).user.id,user.id);
  await db.query('INSERT INTO specialist_operator_identities(user_id) VALUES($1)',[user.id]);clients.push(c);
 }
 return clients;
}
export async function approveErasure({owner,approver,profile,ok}){
 const confirmation=crypto.randomUUID();ok(await owner.rpc('confirm_my_specialist_erasure',{p_specialist_id:profile,p_confirmation_id:confirmation}));
 return ok(await approver.rpc('specialist_operator_authorize',{p_specialist_id:profile,p_confirmation_id:confirmation,p_request_id:null,p_purpose:'profile_erasure',p_ticket:'OTZ-LOCAL-TEST-00000001'})).authorization_id;
}
