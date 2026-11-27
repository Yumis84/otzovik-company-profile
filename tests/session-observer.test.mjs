import test from 'node:test';
import assert from 'node:assert/strict';
import {createSessionFence,createAuthSessionObserver,settleForSession} from '../company-session-fence.mjs';
test('focus sign-in does not redirect; logout and identity changes do',()=>{
 const changes=[],observe=createAuthSessionObserver(x=>changes.push(x)),s=(id,sid=id,exp=1)=>({user:{id},access_token:'x.'+Buffer.from(JSON.stringify({sub:id,session_id:sid,exp})).toString('base64url')+'.x'});
 observe('INITIAL_SESSION',s('A'));observe('SIGNED_IN',s('A'));observe('TOKEN_REFRESHED',s('A','A',2));
 assert.deepEqual(changes,[]);observe('SIGNED_OUT',null);observe('SIGNED_IN',s('B'));observe('SIGNED_IN',s('A'));assert.deepEqual(changes,[null,JSON.stringify(['B','B']),JSON.stringify(['A','A'])]);observe('SIGNED_IN',s('A','new'));assert.equal(changes.at(-1),JSON.stringify(['A','new']));
});
test('old success and actual rejection ignored across A B A',async()=>{
 const f=createSessionFence(),out=[],pending=[];
 function start(){let resolve,reject;const p=new Promise((a,b)=>{resolve=a;reject=b});pending.push(settleForSession(f,f.capture(),p,x=>out.push(x),e=>out.push(e.message)));return {resolve,reject}}
 f.transition('A');const a=start();f.transition(null);f.transition('B');const b=start();f.transition(null);f.transition('A');const c=start(),d=start();
 a.resolve('old A');b.reject(Error('old B'));c.resolve('new A');d.reject(Error('new error'));await Promise.all(pending);assert.deepEqual(out,['new A','new error']);
});
