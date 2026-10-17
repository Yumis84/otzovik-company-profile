import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import http from 'node:http';
import pg from 'pg';
import {createClient} from '@supabase/supabase-js';
import {build} from 'esbuild';
import {chromium} from 'playwright';
import {migrationSQL} from '../scripts/specialist-migration.mjs';
import {buildPages} from '../scripts/build-pages.mjs';
const cfg=JSON.parse(await fs.readFile('/tmp/otzovik-local-status.json','utf8'));
const api=cfg.API_URL,anon=cfg.ANON_KEY,service=cfg.SERVICE_ROLE_KEY;
for(const url of [api,cfg.DB_URL])assert(['127.0.0.1','localhost'].includes(new URL(url).hostname),'Loopback target required');
assert.equal(new URL(api).port,'54321');assert.equal(new URL(cfg.DB_URL).port,'54322');
assert(anon&&service,'Local legacy keys required');
const db=new pg.Client({connectionString:cfg.DB_URL});await db.connect();
const ok=r=>{assert(!r.error,r.error?.message);return r.data;};
const client=()=>createClient(api,anon,{auth:{persistSession:false,autoRefreshToken:false}});
const admin=createClient(api,service,{auth:{persistSession:false,autoRefreshToken:false}});
let count=0;const test=async(name,fn)=>{await fn();console.log('PASS LOCAL',++count,name);};
let browser,server;
try{
 assert.equal((await db.query("SELECT to_regclass('public.companies') t")).rows[0].t,null,'Disposable fresh database required');
 // Use real Auth roles/schema/uid(), replacing only the old unit-test harness prefix.
 const fixture=await fs.readFile(new URL('./fixtures/schema.sql',import.meta.url),'utf8');
 await db.query(fixture.slice(fixture.indexOf('CREATE TABLE public.companies')));
 for(const f of ['company-rpcs-before.sql','company-edit-before.sql'])await db.query(await fs.readFile(new URL('./fixtures/'+f,import.meta.url),'utf8'));
 const snapshot=JSON.parse(await fs.readFile(new URL('./fixtures/company-stack-snapshot.json',import.meta.url),'utf8'));
 for(const table of ['company_locations','company_services','company_media']){
  const cols=snapshot.columns.filter(c=>c.table===table).map(c=>`${c.name} ${c.type}${c.default?' DEFAULT '+c.default:''}${c.notnull?' NOT NULL':''}`);
  await db.query(`CREATE TABLE public.${table} (${cols.join(',')}); ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY;`);
 }
 for(const c of snapshot.extra.constraints)await db.query(`ALTER TABLE public.${c.table} ADD CONSTRAINT ${c.name} ${c.definition}`);
 await db.query('CREATE SCHEMA media_internal; GRANT USAGE ON SCHEMA media_internal TO anon,authenticated;');
 for(const def of snapshot.extra.helpers)await db.query(def);
 for(const f of snapshot.functions)await db.query(f.definition);
 for(const p of [...snapshot.policies,...snapshot.extra.policies])await db.query(`CREATE POLICY "${p.policyname}" ON ${p.schemaname}.${p.tablename} AS ${p.permissive} FOR ${p.cmd} TO ${p.roles.join(',')} ${p.qual?'USING ('+p.qual+')':''} ${p.with_check?'WITH CHECK ('+p.with_check+')':''}`);
 await db.query('GRANT SELECT,INSERT,UPDATE,DELETE ON public.company_media TO authenticated; GRANT SELECT ON public.company_memberships TO authenticated;');
 // Limit subsidiary RPCs to authenticated just as the cabinet's API contract requires.
 for(const f of snapshot.functions){const r=await db.query("SELECT oid::regprocedure::text signature FROM pg_proc WHERE proname=$1 AND pronamespace='public'::regnamespace",[f.name]);for(const row of r.rows)await db.query(`REVOKE ALL ON FUNCTION ${row.signature} FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION ${row.signature} TO authenticated;`);}
 await db.query(await migrationSQL());
 ok(await admin.storage.createBucket('company-media',{public:false}));
 await db.query("NOTIFY pgrst,'reload schema'");
 await new Promise(r=>setTimeout(r,1500));
 console.log('LOCAL stack: real Auth/PostgREST/Storage; synthetic data; production publisher replaced by SQL sentinel');
 const password='Acceptance-'+crypto.randomUUID()+'!';const emails=['owner-'+Date.now()+'@example.test','other-'+Date.now()+'@example.test'];
 const a=client(),b=client(),anonymous=client();let uidA,uidB,draft,company;
 const mailBase=cfg.INBUCKET_URL||cfg.MAILPIT_URL||'http://127.0.0.1:54324';
 assert(['127.0.0.1','localhost'].includes(new URL(mailBase).hostname));
 async function confirmation(email){
  for(let i=0;i<30;i++){
   const res=await fetch(mailBase+'/api/v1/messages');const list=await res.json();
   const m=(list.messages||[]).find(m=>(m.To||[]).some(t=>t.Address===email));
   if(m){const msg=await (await fetch(mailBase+'/api/v1/message/'+m.ID)).json();const text=(msg.Text||'')+' '+(msg.HTML||'');const link=text.match(/https?:\/\/[^\s"<>]*\/auth\/v1\/verify\?[^\s"<>]+/);assert(link,'Confirmation URL in local email');const url=link[0].replaceAll('&amp;','&');assert(['127.0.0.1','localhost'].includes(new URL(url).hostname));return url;}
   await new Promise(r=>setTimeout(r,1000));
  }throw Error('Local confirmation email not received');
 }
 await buildPages();
 const sdk=await build({stdin:{contents:"export {createClient} from '@supabase/supabase-js'",resolveDir:process.cwd()},bundle:true,format:'esm',platform:'browser',write:false});
 browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const ctx=await browser.newContext({viewport:{width:390,height:844}});const page=await ctx.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 page.on('response',async r=>{if(r.url().startsWith(api+'/auth/')&&r.status()>=400){try{const d=await r.json();console.log('LOCAL Auth diagnostic',r.status(),d.error_code||d.code||'',d.msg||d.message||d.error_description||'');}catch{console.log('LOCAL Auth response unreadable',r.status());}}});
 page.on('requestfailed',r=>{if(r.url().startsWith(api))console.log('LOCAL request failed',new URL(r.url()).pathname,r.failure()?.errorText);});
 server=http.createServer(async(req,res)=>{
  try{
   const u=new URL(req.url,'http://127.0.0.1:4173');
   if(u.pathname==='/supabase-sdk.js'){res.writeHead(200,{'content-type':'text/javascript'});res.end(sdk.outputFiles[0].text);return;}
   if(!/^\/account-[a-z-]+\.(html|js|css)$/.test(u.pathname)){res.writeHead(404);res.end();return;}
   const text=await fs.readFile(new URL('../_site'+u.pathname,import.meta.url),'utf8');
   const body=text.replaceAll('https://rzhlcszqtuhkhfibygnk.supabase.co',api).replaceAll('sb_publishable_yhqWJ1eWUznBkqKwPogTrw_xCdCbFA-',anon).replaceAll('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm','/supabase-sdk.js');
   res.writeHead(200,{'content-type':u.pathname.endsWith('.js')?'text/javascript':u.pathname.endsWith('.css')?'text/css':'text/html; charset=utf-8'});res.end(body);
  }catch{res.writeHead(500);res.end('Local fixture failed');}
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(4173,'127.0.0.1',resolve);});
 await ctx.route('**/*',route=>{const u=new URL(route.request().url());return [api,'http://127.0.0.1:4173'].includes(u.origin)?route.continue():route.abort();});
 page.on('console',msg=>{if(/CORS|Access to fetch|Local Network Access/.test(msg.text()))console.log('LOCAL browser network policy:',msg.text().replace(/https?:[^\s'"]+/g,x=>{try{return new URL(x).origin+new URL(x).pathname;}catch{return '[url]';}}));});
 const open=path=>page.goto('http://127.0.0.1:4173/'+path);
 async function login(email){await open('account-login.html');await page.locator('#email').fill(email);await page.locator('#password').fill(password);await page.locator('#submit').click();try{await page.waitForURL('**/account-home.html');}catch{throw Error('Browser login failed: '+await page.locator('#status').innerText()+'; page errors: '+errors.join('; '));}}
 await test('two real Auth signups, email confirmation through Mailpit, password login',async()=>{
  for(const [c,email] of [[a,emails[0]],[b,emails[1]]]){
   if(c===a){await open('account-login.html');await page.locator('#signupTab').click();await page.locator('#email').fill(email);await page.locator('#password').fill(password);await page.locator('#submit').click();await page.locator('#status').filter({hasText:'Проверьте почту'}).waitFor();}else{const signup=ok(await c.auth.signUp({email,password}));assert.equal(signup.session,null);}
   assert((await c.auth.signInWithPassword({email,password})).error);
   if(c===a){await page.goto(await confirmation(email));await page.waitForURL('**/account-create-profile.html');await open('account-home.html');await page.locator('#logout').click();await page.waitForURL('**/account-login.html');}else{const confirm=await fetch(await confirmation(email),{redirect:'manual'});assert.equal(confirm.status,303);}
   ok(await c.auth.signInWithPassword({email,password}));
  }
  uidA=ok(await a.auth.getUser()).user.id;uidB=ok(await b.auth.getUser()).user.id;
 });
 await test('empty account and PostgREST owner draft create/edit/read with real JWT',async()=>{
  assert.deepEqual(ok(await a.rpc('get_my_specialists')),[]);assert.deepEqual(ok(await a.rpc('get_my_companies')),[]);
  draft=ok(await a.rpc('create_my_specialist_draft',{p_display_name:'Local Specialist',p_slug:'local-specialist',p_profession:'Master'}));
  for(let i=0;i<2;i++)ok(await a.rpc('update_my_specialist_draft',{p_id:draft.id,p_display_name:'Local Edited',p_profession:'Master',p_description:'Persisted'}));
  const rows=ok(await a.rpc('get_my_specialists'));assert.equal(rows.length,1);assert.equal(rows[0].description,'Persisted');
 });
 await test('foreign and anonymous RPC/table access denied, including direct writes and registry',async()=>{
  assert.deepEqual(ok(await b.rpc('get_my_specialists')),[]);
  assert((await b.rpc('update_my_specialist_draft',{p_id:draft.id,p_display_name:'Stolen',p_profession:'Other'})).error);
  for(const c of [b,anonymous])for(const table of ['specialist_profiles','profile_slug_registry']){
   const read=await c.from(table).select('*');assert.equal(read.error?.code,'42501');
   assert.equal((await c.from(table).update({slug:'stolen'}).eq('slug','local-specialist')).error?.code,'42501');
   assert.equal((await c.from(table).insert({slug:'stolen'})).error?.code,'42501');
   assert.equal((await c.from(table).delete().eq('slug','local-specialist')).error?.code,'42501');
  }
  assert((await anonymous.rpc('get_my_specialists')).error);
  assert((await anonymous.rpc('create_my_specialist_draft',{p_display_name:'Anon',p_slug:'anon-master',p_profession:'Master'})).error);
  assert((await anonymous.rpc('update_my_specialist_draft',{p_id:draft.id,p_display_name:'Anon',p_profession:'Other'})).error);
 });
 await test('company create/edit and shared address collision through PostgREST',async()=>{
  ok(await a.rpc('create_my_company',{p_name:'Local Company',p_slug:'local-company'}));
  company=ok(await a.rpc('get_my_companies'))[0].company;
  ok(await a.rpc('update_my_company_profile',{p_company_id:company.id,p_name:'Company Edited',p_website:null,p_phone:null,p_email:null,p_city:'City',p_description:'Company persisted'}));
  assert.equal(ok(await a.rpc('get_my_companies'))[0].company.description,'Company persisted');
  assert((await b.rpc('create_my_specialist_draft',{p_display_name:'Other Master',p_slug:company.slug,p_profession:'Master'})).error);
  const results=await Promise.all([a,b].map(c=>c.rpc('create_my_specialist_draft',{p_display_name:'Race Master',p_slug:'local-race',p_profession:'Master'})));
  assert.equal(results.filter(r=>!r.error).length,1);
 });
 await test('real company branch/service RPC create, list and archive/publish',async()=>{
  for(const kind of ['location','service']){
   const params=kind==='location'?{p_address:'Street 1',p_city:'City'}:{};
   const item=ok(await a.rpc('create_my_company_'+kind,{p_company_id:company.id,p_name:'Local '+kind,...params}));
   assert(ok(await a.rpc('get_my_company_'+kind+'s',{p_company_id:company.id})).some(x=>x.id===item.id));
   for(const action of ['archive','publish'])ok(await a.rpc('manage_my_company_'+kind,{p_company_id:company.id,['p_'+kind+'_id']:item.id,p_action:action}));
   assert((await b.rpc('get_my_company_'+kind+'s',{p_company_id:company.id})).error);
  }
 });
 await test('real private Storage upload, registration and signed read; foreign write denied',async()=>{
  const name=company.id+'/logo/acceptance.png';const bytes=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=','base64');
  ok(await a.storage.from('company-media').upload(name,bytes,{contentType:'image/png'}));
  assert((await b.storage.from('company-media').upload(company.id+'/logo/foreign.png',bytes,{contentType:'image/png'})).error);
  assert((await anonymous.storage.from('company-media').download(name)).error);
  ok(await a.rpc('register_my_company_media',{p_company_id:company.id,p_storage_object_name:name,p_media_type:'logo'}));
  const signed=ok(await a.storage.from('company-media').createSignedUrl(name,60));const res=await fetch(signed.signedUrl);assert(res.ok);assert.deepEqual(Buffer.from(await res.arrayBuffer()),bytes);
  assert.equal(ok(await a.from('company_media').select('*')).length,1);
  assert.deepEqual(ok(await b.from('company_media').select('*')),[]);
 });
 await test('pending/revoked company member denied without losing private specialist',async()=>{
  for(const status of ['pending','revoked']){
   await db.query('UPDATE company_memberships SET verification_status=$1 WHERE company_id=$2 AND user_id=$3',[status,company.id,uidA]);
   assert.deepEqual(ok(await a.rpc('get_my_companies')),[]);
   assert((await a.rpc('create_my_company_service',{p_company_id:company.id,p_name:'Denied'})).error);
   assert((await a.rpc('update_my_company_profile',{p_company_id:company.id,p_name:'Denied',p_website:null,p_phone:null,p_email:null,p_city:null,p_description:null})).error);
   assert((await a.storage.from('company-media').upload(company.id+'/logo/denied-'+status+'.png',Buffer.from('x'),{contentType:'image/png'})).error);
   assert(ok(await a.rpc('get_my_specialists')).some(x=>x.id===draft.id));
  }
  await db.query("UPDATE company_memberships SET verification_status='verified' WHERE company_id=$1 AND user_id=$2",[company.id,uidA]);
 });
 await test('real browser login → chooser → specialist create → home → edit → reload → relogin',async()=>{
  await login(emails[0]);await page.getByText('Local Edited',{exact:true}).waitFor();
  await open('account-create-profile.html');await page.locator('a[href="account-create-specialist.html"]').click();
  await page.locator('[name=display_name]').fill('Browser Specialist');await page.locator('[name=slug]').fill('browser-specialist');await page.locator('[name=profession]').fill('Master');await page.locator('#save').click();await page.waitForURL('**/account-home.html');
  const row=ok(await a.rpc('get_my_specialists')).find(x=>x.slug==='browser-specialist');assert(row);
  await open('account-create-specialist.html?id='+row.id);await page.locator('#save:not([disabled])').waitFor();await page.locator('[name=description]').fill('Browser persisted');await page.locator('#save').click();await page.waitForURL('**/account-home.html');
  await page.locator('#logout').click();await page.waitForURL('**/account-login.html');await login(emails[0]);
  await open('account-create-specialist.html?id='+row.id);await page.locator('#save:not([disabled])').waitFor();assert.equal(await page.locator('[name=description]').inputValue(),'Browser persisted');
  await page.reload();await page.locator('#save:not([disabled])').waitFor();assert.equal(await page.locator('[name=description]').inputValue(),'Browser persisted');assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await open('account-home.html');await page.locator('#logout').click();await page.waitForURL('**/account-login.html');await login(emails[1]);await open('account-create-specialist.html?id='+row.id);await page.getByText(/Черновик не найден или недоступен/).waitFor();assert(await page.locator('#save').isDisabled());
 });
 await test('real browser company edit, branch/service save and photo upload',async()=>{
  await open('account-home.html');await page.locator('#logout').click();await page.waitForURL('**/account-login.html');await login(emails[0]);
  await open('account-profile.html?company_id='+company.id);await page.locator('#profile-fields:not([disabled])').waitFor();await page.locator('#description').fill('Browser company persisted');await page.locator('#save').click();await page.locator('#save-state').filter({hasText:'Изменения сохранены'}).waitFor();
  await page.reload();await page.locator('#profile-fields:not([disabled])').waitFor();assert.equal(await page.locator('#description').inputValue(),'Browser company persisted');
  await open('account-branches.html?company_id='+company.id);await page.locator('#new-name').fill('Browser Branch');await page.locator('#new-address').fill('Street 2');await page.locator('#new-city').fill('City');await page.locator('#branch-submit:not([disabled])').waitFor();await page.locator('#branch-submit').click();await page.locator('#branches').getByText('Browser Branch',{exact:true}).waitFor();
  await open('account-services.html?company_id='+company.id);await page.locator('#svc-name').fill('Browser Service');await page.locator('#svc-submit').click();await page.locator('#services').getByText('Browser Service',{exact:true}).waitFor();
  await open('account-media.html?company_id='+company.id);await page.locator('#active-company-name').filter({hasText:'Company Edited'}).waitFor();
  const png=await page.evaluate(()=>{const c=document.createElement('canvas');c.width=c.height=4;return c.toDataURL('image/png').split(',')[1];});
  await page.locator('#media-file').setInputFiles({name:'browser.png',mimeType:'image/png',buffer:Buffer.from(png,'base64')});await page.locator('#media-state').filter({hasText:'Фотография загружена и опубликована'}).waitFor();
  assert(ok(await a.from('company_media').select('*')).some(x=>x.storage_object_name.endsWith('.webp')));
 });
 assert.deepEqual(errors,[]);
 await test('private drafts remain absent from publisher and rollback preserves data',async()=>{
  const before=(await db.query('SELECT count(*)::int n FROM specialist_profiles')).rows[0].n;
  assert((await db.query("SELECT count(*)::int n FROM test_publish_events e JOIN specialist_profiles s ON s.id=e.company_id")).rows[0].n===0);
  await db.query('REVOKE EXECUTE ON FUNCTION public.get_my_specialists() FROM authenticated');
  assert((await a.rpc('get_my_specialists')).error);assert.equal((await db.query('SELECT count(*)::int n FROM specialist_profiles')).rows[0].n,before);
  await db.query('GRANT EXECUTE ON FUNCTION public.get_my_specialists() TO authenticated');
 });
 console.log(`PASS LOCAL ${count} real Supabase groups. Hosted email deliverability/CDN/publisher: NOT RUN.`);
}finally{if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));await db.end();}
