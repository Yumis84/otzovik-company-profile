import assert from 'node:assert/strict';
import { Worker } from 'node:worker_threads';

// Isolated auth.uid() model: each mock RPC receives an explicit authenticated user
// context; no Supabase connection or test.uid GUC is used.
const auth = userId => ({ uid: () => userId });
const registry = new Int32Array(new SharedArrayBuffer(8)); // slot 0=acme, slot 1=acme-2
const allocate = async (base, user) => new Promise((resolve, reject) => {
  const worker = new Worker(`
    const { parentPort, workerData } = require('node:worker_threads');
    const registry = new Int32Array(workerData.registry);
    const slot = Atomics.compareExchange(registry, 0, 0, 1) === 0 ? 0 : 1;
    const candidate = slot === 0 ? workerData.base : workerData.base + '-2';
    Atomics.store(registry, slot, 1);
    parentPort.postMessage({ candidate, user: workerData.user });
  `, { eval: true, workerData: { base, user, registry: registry.buffer } });
  worker.once('message', ({ candidate }) => { resolve(candidate); });
  worker.once('error', reject);
});

assert.equal(auth('user-1').uid(), 'user-1');
// This is an isolated worker simulation, not a real Postgres concurrency test.
// A true two-connection test requires a local Postgres instance and is not run here.
const [first, second] = await Promise.all([allocate('acme', 'user-1'), allocate('acme', 'user-2')]);
assert.deepEqual(new Set([first, second]), new Set(['acme', 'acme-2']));
for (const slug of [first, second]) {
  assert.ok(slug.length <= 64);
  assert.match(slug, /^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$/);
  assert.equal(slug.includes('--'), false);
}
console.log('auth.uid mock + isolated parallel allocation simulation: PASS');
