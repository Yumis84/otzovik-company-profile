// OFFLINE SYNTHETIC HARNESS. No network, secrets, real identities or Supabase access.
// It is not a hosted issuer, MFA verifier, support authorizer or production store.
import {generateKeyPairSync,sign,verify,randomUUID} from 'node:crypto';
const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
const decode=x=>JSON.parse(Buffer.from(x,'base64url').toString());
const validId=s=>typeof s==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(s);
const assert=(v,m)=>{if(!v)throw Error(m)};
function pack(key,payload){const h=enc({alg:'EdDSA',typ:'JWT'}),p=enc(payload),msg=h+'.'+p;return msg+'.'+sign(null,Buffer.from(msg),key).toString('base64url');}
function unpack(key,token){try{const parts=token.split('.');assert(parts.length===3,'invalid');const [h,p,s]=parts;assert(decode(h).alg==='EdDSA'&&decode(h).typ==='JWT','invalid');assert(verify(null,Buffer.from(h+'.'+p),key,Buffer.from(s,'base64url')),'invalid');return decode(p)}catch{throw Error('invalid signature or token');}}
export function syntheticIssuer({now=()=>Math.floor(Date.now()/1000)}={}){
 const identity=generateKeyPairSync('ed25519'),issuer=generateKeyPairSync('ed25519'),operators=new Set(),revoked=new Set(),usedAssertions=new Set(),audit=[];
 function register(id){assert(validId(id),'invalid subject');operators.add(id);}
 function identityAssertion(subject,{mfa=true,age=0,aud='synthetic-operator-issuer'}={}){const time=now();return pack(identity.privateKey,{iss:'synthetic-idp',aud,sub:subject,aal:mfa?'aal2':'aal1',mfa_at:time-age,iat:time,exp:time+60,jti:randomUUID()});}
 function issue(assertion,profile,request){const time=now(),a=unpack(identity.publicKey,assertion);assert(a.iss==='synthetic-idp'&&a.aud==='synthetic-operator-issuer'&&validId(a.sub)&&operators.has(a.sub),'identity denied');assert(a.aal==='aal2'&&Number.isInteger(a.mfa_at)&&a.mfa_at<=time&&time-a.mfa_at<=120,'MFA required');assert(Number.isInteger(a.iat)&&a.iat<=time&&Number.isInteger(a.exp)&&a.exp>time&&typeof a.jti==='string'&&!usedAssertions.has(a.jti),'assertion expired or replay');assert(validId(profile)&&validId(request),'scope invalid');usedAssertions.add(a.jti);const jti=randomUUID(),claims={iss:'synthetic-issuer',aud:'synthetic-operator-gateway',sub:a.sub,profile,request,iat:time,exp:time+60,jti};audit.push({event:'issue',subject:a.sub,jti,at:time});return pack(issuer.privateKey,claims);}
 function validate(token,subject,profile,request){const time=now(),p=unpack(issuer.publicKey,token);assert(p.iss==='synthetic-issuer'&&p.aud==='synthetic-operator-gateway'&&p.sub===subject&&p.profile===profile&&p.request===request,'scope denied');assert(operators.has(p.sub)&&Number.isInteger(p.iat)&&p.iat<=time&&Number.isInteger(p.exp)&&p.exp>time&&p.exp-p.iat<=60&&!revoked.has(p.jti),'expired revoked or disabled');return {sub:p.sub,jti:p.jti};}
 function revoke(token){const p=unpack(issuer.publicKey,token);revoked.add(p.jti);audit.push({event:'revoke',subject:p.sub,jti:p.jti,at:now()});}
 function disable(id){operators.delete(id);audit.push({event:'disable',subject:id,at:now()});}
 return {register,identityAssertion,issue,validate,revoke,disable,audit};
}
export function syntheticSupport({now=()=>Math.floor(Date.now()/1000)}={}){
 const cases=new Map(),audit=[];
 function open(id,subject,requester,reference){assert([id,subject,requester].every(validId)&&typeof reference==='string'&&/^SYNTHETIC-[A-Z0-9-]{8,80}$/.test(reference),'invalid case');assert(!cases.has(id),'duplicate');cases.set(id,{id,subject,requester,reference,approvals:new Set(),status:'pending'});audit.push({event:'open',id,requester,at:now()});}
 function approve(id,reviewer){const c=cases.get(id);assert(c&&c.status==='pending'&&validId(reviewer)&&reviewer!==c.subject&&reviewer!==c.requester&&!c.approvals.has(reviewer),'approval denied');c.approvals.add(reviewer);audit.push({event:'review',id,reviewer,at:now()});}
 function close(id){const c=cases.get(id);assert(c&&c.status==='pending'&&c.approvals.size>=2,'two independent reviews required');c.status='reviewed-not-authorized';audit.push({event:'reviewed',id,at:now()});return {status:c.status,grantsAccess:false};}
 return {open,approve,close,audit};
}
export function evaluateDrain(evidence){
 // Worksheet validation only: no assertion can produce provider proof or unlock removal.
 const rows=Array.isArray(evidence?.writers)?evidence.writers:[];
 const missing=[];if(evidence?.environment!=='disposable-local')missing.push('environment');if(!evidence?.inventoryComplete||!rows.length)missing.push('inventory');
 for(const row of rows){if(!row.name||!row.freezeEvidence||!row.executionEvidence||!row.terminalEvidence)missing.push('writer:'+String(row.name||'unknown'));}
 return {worksheetComplete:missing.length===0,providerDrainVerified:false,allowDeletion:false,missing};
}
export async function syntheticAlert(metric,transport){assert(['critical_orphan','stale_begin'].includes(metric),'unsupported metric');assert(typeof transport==='function','transport required');const id=randomUUID();const r=await transport({id,metric});assert(r?.ack===id,'alert not acknowledged');return {id,delivered:true,synthetic:true};}
export function rollbackDryRun(state){assert(state?.environment==='disposable-local','local synthetic only');return {applied:false,steps:['close-admission','preserve-rls-fk-audit','verify-no-unknown-writers','review-ui-artifact','require-explicit-approval']};}
