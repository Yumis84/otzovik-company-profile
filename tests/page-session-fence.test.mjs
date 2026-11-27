import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createPageSessionFence} from '../company-session-fence.mjs';
const s=(id,exp=1)=>({user:{id:'A'},access_token:'x.'+Buffer.from(JSON.stringify({sub:'A',session_id:id,exp})).toString('base64url')+'.x'});
function fixture(){let cb,resolve,n=0;const f=createPageSessionFence({onAuthStateChange(x){cb=x},getSession(){return new Promise(r=>resolve=r)}},()=>n++);return {f,emit:(e,v)=>cb(e,v),resolve:v=>resolve({data:{session:v}}),count:()=>n}}
test('rotation preserves page; A B A never revives it',async()=>{const x=fixture(),p=x.f.start();x.resolve(s('A'));assert.equal(await p,true);x.emit('TOKEN_REFRESHED',s('A',2));assert.equal(x.f.current(),true);x.emit('SIGNED_IN',s('B'));x.emit('SIGNED_IN',s('A'));assert.equal(x.f.current(),false);assert.equal(x.count(),1)});
test('logout during initial read cannot revive page',async()=>{const x=fixture(),p=x.f.start();x.emit('SIGNED_OUT',null);x.resolve(s('A'));assert.equal(await p,false);assert.equal(x.count(),1)});
test('late success and rejection cannot update invalidated page',async()=>{const x=fixture(),p=x.f.start();x.resolve(s('A'));await p;let resolve,reject,writes=0;const a=new Promise(r=>resolve=r),b=new Promise((r,j)=>reject=j);const run=async q=>{try{await q;if(x.f.current())writes++}catch{if(x.f.current())writes++}finally{if(x.f.current())writes++}};const jobs=[run(a),run(b)];x.emit('SIGNED_OUT',null);resolve(1);reject(Error('late'));await Promise.all(jobs);assert.equal(writes,0)});
