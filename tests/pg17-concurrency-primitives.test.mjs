import {test} from 'node:test';
import assert from 'node:assert/strict';
import {waitForBlocked,closeClients} from './pg17-concurrency-primitives.mjs';
test('barrier checks actual observer predicate',async()=>{
 let count=0;await waitForBlocked({observer:{async query(sql,params){assert.match(sql,/pg_blocking_pids/);assert.deepEqual(params,[7,8]);return {rows:[{blocked:++count===2}]}}},blockingPid:7,blockedPid:8,timeoutMs:500});assert.equal(count,2);
});
test('barrier fails instead of silently passing on timeout',async()=>assert.rejects(waitForBlocked({observer:{async query(){return {rows:[{blocked:false}]}}},blockingPid:7,blockedPid:8,timeoutMs:30}),/not observed/));
test('teardown attempts to close all connections even on errors',async()=>{let closed=0;await assert.rejects(closeClients([{async end(){closed++;throw Error('failure')}},{async end(){closed++}}]),/failed to close/);assert.equal(closed,2);});
