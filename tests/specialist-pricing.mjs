import assert from 'node:assert/strict';import fs from 'node:fs/promises';import crypto from 'node:crypto';import {database,A,B} from './database.mjs';
export const migrationURL=new URL('../supabase/migrations/20261026040132_specialist_service_pricing_candidate.sql',import.meta.url);
const db=await database({editor:true});let count=0;
const test=async(name,fn)=>{await fn();console.log('PASS PRICING',++count,name);};
const reject=(fn,code)=>assert.rejects(fn,e=>e.code===code);
const a=await db.call(A,'create_my_specialist_draft',['Price A','price-a','Master']),b=await db.call(B,'create_my_specialist_draft',['Price B','price-b','Master']);
const old=(id=crypto.randomUUID(),from=null,to=null,currency='RUB',version=null,owner=A,profile=a.id)=>db.call(owner,'save_my_specialist_service',[profile,id,'Service','Description',from,to,currency,null,true,version]);
const v2=(x={},uid=A,profile=a.id)=>db.call(uid,'save_my_specialist_service_v2',[profile,x.id??crypto.randomUUID(),x.name??'Service',x.description??null,x.mode??'priced',x.unit??null,x.from??null,x.to??null,x.currency??'RUB',x.duration??null,x.active??true,x.version??null]);
try{
 const legacy=[];for(const [from,to]of [[null,null],[0,null],[null,9],[5,5],[2.123,4.567]])for(const currency of ['RUB','USD','EUR'])legacy.push(await old(undefined,from,to,currency));
 const before=(await db.query('SELECT * FROM specialist_services ORDER BY id')).rows;
 const defs=(await db.query("SELECT oid,proname,pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='public'::regnamespace")).rows;
 const company=(await db.query('SELECT row_to_json(c) data FROM companies c')).rows;
 await db.exec(await fs.readFile(migrationURL,'utf8'));
 await test('up migration preserves 15 historical price shapes/currencies/versions exactly',async()=>{
  const after=(await db.query('SELECT * FROM specialist_services ORDER BY id')).rows;
  assert.deepEqual(after.map(({price_mode,price_unit,...r})=>r),before);assert(after.every(r=>r.price_mode===null&&r.price_unit===null));
  assert.deepEqual((await db.query('SELECT row_to_json(c) data FROM companies c')).rows,company);
  const now=(await db.query("SELECT oid,proname,pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='public'::regnamespace")).rows;
  for(const d of defs.filter(x=>x.proname!=='save_my_specialist_service'))assert.deepEqual(now.find(x=>x.oid===d.oid),d);
 });
 await test('owner capability is read-only; foreign/anon/internal/direct tables fail closed',async()=>{
  assert.deepEqual(await db.call(A,'get_my_specialist_service_pricing',[a.id]),{schema_version:2});
  await reject(()=>db.call(B,'get_my_specialist_service_pricing',[a.id]),'42501');await reject(()=>db.call(null,'get_my_specialist_service_pricing',[a.id]),'42501');
  await reject(()=>v2({from:1},B),'42501');await reject(()=>v2({from:1},null),'42501');
  await reject(()=>db.session(null,c=>c.query('SELECT public.get_my_specialist_service_pricing($1)',[a.id]),'anon'),'42501');
  await reject(()=>db.session(A,c=>c.query("SELECT public.specialist_service_pricing_save_internal($1,$2,'Name',NULL,'priced',NULL,1,NULL,'RUB',NULL,true,NULL,false)",[a.id,crypto.randomUUID()])),'42501');
  await reject(()=>db.session(A,c=>c.query('SELECT * FROM public.specialist_services')),'42501');
 });
 await test('all six units, zero, both one-sided prices, exact and range roundtrip',async()=>{
  for(const unit of ['service','hour','lesson','day','square_meter','project']){const r=await v2({unit,from:0,to:3.12,currency:'EUR'});assert.equal(r.price_unit,unit);assert.equal(r.version,1);assert.equal(r.currency,'EUR');}
  for(const x of [{from:0},{to:0},{from:5,to:5},{from:2,to:3}]){const r=await v2(x);assert.equal(r.price_mode,'priced');assert.equal(r.price_unit,null);}
  const r=await v2({mode:'negotiated',unit:'hour'});assert.equal(r.price_from,null);assert.equal(r.price_mode,'negotiated');
  assert.equal((await v2({mode:'unspecified'})).price_mode,'unspecified');
 });
 await test('incompatible and non-finite values reject atomically',async()=>{
  const before=(await db.query('SELECT count(*) n FROM specialist_services')).rows;
  for(const x of [{},{mode:'negotiated',from:0},{mode:'unspecified',to:1},{from:4,to:3},{from:-1},{to:100000001},{from:'NaN'},{from:'Infinity'},{to:'-Infinity'},{from:1,unit:'week'},{from:1,currency:'GBP'},{from:1,mode:'other'},{from:1.123}])await reject(()=>v2(x),'22023');
  assert.deepEqual((await db.query('SELECT count(*) n FROM specialist_services')).rows,before);
  await reject(()=>db.query("INSERT INTO specialist_services(specialist_id,name,price_mode) VALUES($1,'Wrong','priced')",[a.id]),'23514');
 });
 await test('v1 preserves extended metadata; changed prices map mode and CAS increments once',async()=>{
  let r=await v2({mode:'negotiated',unit:'hour',currency:'USD'});
  r=await old(r.id,null,null,'USD',r.version);assert.equal(r.version,2);assert.equal(r.price_mode,'negotiated');assert.equal(r.price_unit,'hour');
  r=await old(r.id,null,null,'EUR',r.version);assert.equal(r.price_mode,'negotiated');assert.equal(r.currency,'EUR');assert.equal(r.version,3);
  r=await old(r.id,10,null,'USD',r.version);assert.equal(r.version,4);assert.equal(r.price_mode,'priced');assert.equal(r.price_unit,'hour');
  r=await old(r.id,null,null,'USD',r.version);assert.equal(r.version,5);assert.equal(r.price_mode,'unspecified');
  r=await v2({id:r.id,version:r.version,mode:'priced',from:0,unit:'project',currency:'EUR'});assert.equal(r.version,6);
  await reject(()=>old(r.id,9,null,'RUB',3),'PT409');assert.equal((await db.call(A,'get_my_specialist_services',[a.id])).find(x=>x.id===r.id).currency,'EUR');
  const n=await old();assert.equal(n.price_mode,null);assert.equal(n.price_unit,null);
 });
 await test('service theft, deleted record and invalid update do not partially write',async()=>{
  const r=await v2({from:2});
  await reject(()=>v2({id:r.id,from:5},B,b.id),'42501');
  await reject(()=>v2({id:r.id,version:r.version,from:1,to:0}),'22023');
  assert.equal((await db.call(A,'get_my_specialist_services',[a.id])).find(x=>x.id===r.id).version,1);
  await db.call(A,'delete_my_specialist_service',[a.id,r.id,r.version]);
  await reject(()=>v2({id:r.id,from:1,version:1}),'PT409');
 });
 await test('real overlapping v1/v2 saves have one winner and no extra version increment',async()=>{
  if(!db.concurrent){console.log('SKIP overlapping connections: PGlite serializes; require PostgreSQL');return;}
  const r=await v2({from:2});const results=await Promise.allSettled([old(r.id,4,null,'RUB',1),v2({id:r.id,version:1,from:6,unit:'day'})]);
  assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(results.find(x=>x.status==='rejected').reason.code,'PT409');
  assert.equal((await db.call(A,'get_my_specialist_services',[a.id])).find(x=>x.id===r.id).version,2);
 });
 await test('quota remains50 and parent draft-only security survives',async()=>{
  await db.query("INSERT INTO specialist_services(specialist_id,name) SELECT $1,'Fill' FROM generate_series(1,50-(SELECT count(*)::int FROM specialist_services WHERE specialist_id=$1))",[a.id]);
  await reject(()=>v2({from:1}),'54000');await reject(()=>old(),'54000');
  await db.query("UPDATE specialist_profiles SET profile_status='ready' WHERE id=$1",[b.id]).catch(async()=>{await db.query("ALTER TABLE specialist_profiles DROP CONSTRAINT specialist_profiles_status_check");await db.query("UPDATE specialist_profiles SET profile_status='ready' WHERE id=$1",[b.id]);});
  await reject(()=>v2({from:1},B,b.id),'42501');
 });
 await test('rollback refuses data loss; UI-off v1 still works; guarded down preserves legacy values',async()=>{
  const snapshot=(await db.query('SELECT * FROM specialist_services ORDER BY id')).rows;
  const rollback=await fs.readFile(new URL('../sql/specialist-service-pricing-rollback-CANDIDATE.sql',import.meta.url),'utf8');
  await reject(()=>db.exec(rollback),'55000');await db.exec('ROLLBACK');
  assert.deepEqual((await db.query('SELECT * FROM specialist_services ORDER BY id')).rows,snapshot);
  const r=snapshot.find(x=>x.specialist_id===a.id);
  const v=await old(r.id,r.price_from,r.price_to,r.currency,r.version);assert.equal(v.version,r.version+1);
  // Test-only metadata clearing to satisfy destructive down guard. Never a rollout step.
  await db.query('UPDATE specialist_services SET price_mode=NULL,price_unit=NULL');
  const beforeDown=(await db.query('SELECT * FROM specialist_services ORDER BY id')).rows.map(({price_mode,price_unit,...r})=>r);
  await db.exec(rollback);assert.deepEqual((await db.query('SELECT * FROM specialist_services ORDER BY id')).rows,beforeDown);
  assert.equal((await db.query("SELECT count(*)::int n FROM pg_proc WHERE proname='save_my_specialist_service_v2'")).rows[0].n,0);
 });
 console.log('PASS pricing SQL groups',count,'engine',db.concurrent?'PostgreSQL multiconnection':'PGlite');
}finally{await db.close();}
