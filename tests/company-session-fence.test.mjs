import test from 'node:test';
import assert from 'node:assert/strict';
import {createSessionFence,clearCompanyStorage} from '../company-session-fence.mjs';
test('A B A rejects delayed success and error from both previous sessions',async()=>{
 const f=createSessionFence(),writes=[],pending=[];
 function start(label){const t=f.capture();let resolve;const p=new Promise(r=>resolve=r).then(value=>{if(f.current(t))writes.push(value)});pending.push(p);return ()=>resolve(label)}
 f.transition('A');const a=start('old A');f.transition(null);f.transition('B');const b=start('old B');f.transition(null);f.transition('A');const fresh=start('new A');a();b();fresh();await Promise.all(pending);assert.deepEqual(writes,['new A']);
});
test('logout invalidates pending ticket immediately',()=>{const f=createSessionFence();f.transition('A');const t=f.capture();f.transition(null);assert.equal(f.current(t),false)});
test('cleanup only company key in both stores',()=>{const l=new Map([['otzovik_active_company_id','A'],['other','keep']]),s=new Map(l);clearCompanyStorage({removeItem:k=>l.delete(k)},{removeItem:k=>s.delete(k)});assert.deepEqual([...l],[['other','keep']]);assert.deepEqual([...s],[['other','keep']])});
