import assert from 'node:assert/strict';
import {database,A,B} from './database.mjs';
const db=await database();let count=0;
const test=async(name,fn)=>{await fn();console.log('PASS',++count,name);};
const denied=(fn,code='42501')=>assert.rejects(fn,e=>e.code===code);
const create=(uid,slug,...rest)=>db.call(uid,'create_my_specialist_draft',['Test Specialist',slug,'Photographer',...rest]);
try{
let draft;
await test('create, load and edit private draft; all fields persist',async()=>{
 draft=await create(A,'master-one','Portraits','City','Initial description');
 assert.equal(draft.profile_status,'draft');
 const rows=await db.call(A,'get_my_specialists');assert.equal(rows.length,1);assert.equal(rows[0].description,'Initial description');
 await db.call(A,'update_my_specialist_draft',[draft.id,'New Name','Designer','Web','Online','Edited']);
 const [item]=await db.call(A,'get_my_specialists');assert.equal(item.display_name,'New Name');assert.equal(item.description,'Edited');assert.equal(item.slug,'master-one');
});
await test('foreign owner cannot discover or change draft',async()=>{
 assert.deepEqual(await db.call(B,'get_my_specialists'),[]);
 await denied(()=>db.call(B,'update_my_specialist_draft',[draft.id,'Stolen','Other']));
 assert.equal((await db.call(A,'get_my_specialists'))[0].display_name,'New Name');
});
await test('anonymous/no uid denied; direct table access and helper execute denied',async()=>{
 for(const name of ['get_my_specialists','create_my_specialist_draft','update_my_specialist_draft']){
 const args=name==='get_my_specialists'?[]:name==='create_my_specialist_draft'?['Anon','anon-one','Test']:[draft.id,'Anon','Test'];
 await denied(()=>db.call(null,name,args));
 await denied(()=>db.session(null,c=>c.query(`SELECT public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')})`,args),'anon'));
 }
 for(const role of ['anon','authenticated'])for(const table of ['specialist_profiles','profile_slug_registry'])for(const sql of [`SELECT * FROM ${table}`,`DELETE FROM ${table}`,`UPDATE ${table} SET slug='stolen'`,`INSERT INTO ${table}(slug) VALUES('stolen')`])await denied(()=>db.session(A,c=>c.query(sql),role));
 await denied(()=>db.session(A,c=>c.query('SELECT sync_profile_slug_registry()')));
});
await test('RLS remains fail closed even if SELECT granted accidentally',async()=>{
 await db.exec('GRANT SELECT ON specialist_profiles TO authenticated;');
 assert.equal((await db.session(B,c=>c.query('SELECT * FROM specialist_profiles'))).rows.length,0);
 await db.exec('REVOKE SELECT ON specialist_profiles FROM authenticated;');
});
await test('field boundaries consistent; whitespace and oversized values rejected',async()=>{
 for(const name of ['',' ','X','X'.repeat(151)])await denied(()=>db.call(A,'create_my_specialist_draft',[name,'bad-name','Test']),'22023');
 for(const profession of [null,'','  ','X'.repeat(121)]){
 await denied(()=>db.call(A,'create_my_specialist_draft',['Name','bad-job',profession]),'22023');
 await denied(()=>db.call(A,'update_my_specialist_draft',[draft.id,'Name',profession]),'22023');
 }
 for(const args of [['X'.repeat(161)],['OK','X'.repeat(121)],['OK','OK','X'.repeat(2001)]])await denied(()=>create(A,'bad-extra',...args),'22023');
 await create(A,'a'.repeat(63));
 for(const slug of ['a'.repeat(64),'ab','-bad','bad-','xn--abcd','admin','account','a.b','русский'])await denied(()=>create(A,slug),'22023');
 await db.call(A,'update_my_specialist_draft',[draft.id,'X'.repeat(150),'X'.repeat(120),'X'.repeat(160),'X'.repeat(120),'X'.repeat(2000)]);
});
await test('draft cannot publish, acquire company membership or trigger company publisher',async()=>{
 await denied(()=>db.session(A,c=>c.query("UPDATE specialist_profiles SET profile_status='published' WHERE id=$1",[draft.id])));
 await denied(()=>db.query("UPDATE specialist_profiles SET profile_status='published' WHERE id=$1",[draft.id]),'23514');
 assert.equal((await db.query('SELECT count(*)::int n FROM company_memberships')).rows[0].n,0);
 assert.equal((await db.query('SELECT count(*)::int n FROM test_publish_events')).rows[0].n,0);
 assert.equal((await db.query('SELECT count(*)::int n FROM companies')).rows[0].n,1);
});
await test('existing company slug and duplicate specialist slug rejected',async()=>{
 await denied(()=>create(A,'existing-company'),'23505');
 await denied(()=>create(B,'master-one'),'23505');
});
let company;
await test('company creation preserves contract, dedup, owner, audit and fallback address',async()=>{
 company=await db.call(B,'create_my_company',['Company','master-one',null,null,'Berlin']);
 assert.equal(company.company.slug,'master-one-2');assert.equal(company.company.profile_status,'ready');
 assert.equal(company.membership.role,'owner');assert.equal(company.company.website,company.company.public_url);
 assert.equal((await db.query("SELECT count(*)::int n FROM audit_log WHERE action='company_created'")).rows[0].n,1);
 await denied(()=>db.call(B,'create_my_company',['Company','different-slug',null,null,'Berlin']),'23505');
 const external=await db.call(B,'create_my_company',['External','external-company','https://example.org/']);assert.equal(external.company.website,'https://example.org/');
 await denied(()=>db.call(A,'create_my_company',['Duplicate website','different-site','https://example.org/']),'23505');
 const long=await db.call(B,'create_my_company',['Long','a'.repeat(63)]);assert.equal(long.company.slug.length,63);assert(long.company.slug.endsWith('-2'));
 await denied(()=>db.call(A,'create_my_company',['Bad','b'.repeat(64)]),'22023');
});
await test('company memberships verified-only, revoked/suspended/pending hidden',async()=>{
 assert((await db.call(B,'get_my_companies')).some(x=>x.company.id===company.company.id));
 for(const state of ['revoked','suspended','pending']){
 await db.query('UPDATE company_memberships SET verification_status=$1 WHERE company_id=$2',[state,company.company.id]);
 assert(!(await db.call(B,'get_my_companies')).some(x=>x.company.id===company.company.id));
 }
 assert.deepEqual(await db.call(A,'get_my_companies'),[]);
});
await test('registry covers direct writes, rename, delete, rollback and ON CONFLICT',async()=>{
 await denied(()=>db.query("INSERT INTO companies(slug,name) VALUES('master-one','Bypass')"),'23505');
 await denied(()=>db.query("UPDATE companies SET slug='master-one' WHERE slug='existing-company'"),'23505');
 await db.query("UPDATE companies SET slug='renamed-company' WHERE slug='existing-company'");await create(B,'existing-company');
 await db.query("DELETE FROM companies WHERE slug='renamed-company'");await create(B,'renamed-company');
 await db.exec("BEGIN; INSERT INTO companies(slug,name) VALUES('rolled-back','Temp'); ROLLBACK;");await create(B,'rolled-back');
 await db.query("INSERT INTO companies(id,slug,name) VALUES($1,'ignored-slug','Ignored') ON CONFLICT(id) DO NOTHING",[company.company.id]);await create(B,'ignored-slug');
 const check=await db.query("SELECT count(*)::int n FROM (SELECT slug FROM companies UNION ALL SELECT slug FROM specialist_profiles) x");assert.equal(check.rows[0].n,(await db.query('SELECT count(*)::int n FROM profile_slug_registry')).rows[0].n);
});
if(db.concurrent){
 await test('real concurrent company/specialist transactions: both insertion orders',async()=>{
  for(const first of ['company','specialist']){
   let signal;const inserted=new Promise(r=>signal=r);let release;const gate=new Promise(r=>release=r);
   const slug='race-'+first;
   const args=first==='company'?['Concurrent',slug]:['Concurrent',slug,'Test'];
   const fn=first==='company'?'create_my_company':'create_my_specialist_draft';
   const one=db.session(A,async c=>{const r=await c.query(`SELECT ${fn}(${args.map((_,i)=>'$'+(i+1)).join(',')}) data`,args);signal();await gate;return r.rows[0].data;});
   await inserted;
   const two=first==='company'?create(B,slug):db.call(B,'create_my_company',['Second',slug]);
   // Observe the second session waiting on the unique-index transaction lock.
   let blocked=false;
   for(let n=0;n<100;n++){
    const r=await db.query("SELECT count(*)::int n FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND pid<>pg_backend_pid()");
    if(r.rows[0].n){blocked=true;break;}
    await new Promise(r=>setTimeout(r,20));
   }
   release();await one;
   if(first==='company')await denied(()=>two,'23505');else assert.equal((await two).company.slug,slug+'-2');
   assert(blocked,'second transaction must actually overlap and wait');
  }
 });
 await test('simultaneous specialists: exactly one winner',async()=>{
  const r=await Promise.allSettled([create(A,'race-specialists'),create(B,'race-specialists')]);
  assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal(r.find(x=>x.status==='rejected').reason.code,'23505');
 });
}else console.log('SKIP multi-connection races: PGlite is single-session; required in PostgreSQL CI');
await test('security metadata: forced RLS, explicit auth, fixed search path and no public execute',async()=>{
 const r=await db.query("SELECT proname,prosecdef,proconfig FROM pg_proc WHERE proname IN ('create_my_specialist_draft','get_my_specialists','update_my_specialist_draft')");assert.equal(r.rows.length,3);
 for(const row of r.rows){assert.equal(row.prosecdef,true);assert(row.proconfig.includes('search_path=""'));}
 const tables=await db.query("SELECT relrowsecurity,relforcerowsecurity FROM pg_class WHERE relname IN ('specialist_profiles','profile_slug_registry')");for(const row of tables.rows){assert(row.relrowsecurity);assert(row.relforcerowsecurity);}
});
console.log(`PASS ${count} acceptance groups (${db.concurrent?'PostgreSQL concurrent':'PGlite SQL engine'})`);
}finally{await db.close();}
