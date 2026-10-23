// Manual actual Auth/PostgREST/browser checks. Only approved staging; no SQL/schema changes.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {chromium} from 'playwright';
const cfg=JSON.parse(await fs.readFile(process.env.OTZOVIK_TEST_CONFIG,'utf8'));assert.equal(cfg.url,'https://salmcnhexlftrgtiryyo.supabase.co');
const base=process.env.OTZOVIK_TEST_PREVIEW;assert(/^https:\/\/[a-z0-9-]+\.otzovik-cabinet-dev\.pages\.dev$/.test(base));
const output=process.env.OTZOVIK_TEST_OUTPUT;assert(output);await fs.mkdir(output,{recursive:true});
const browser=await chromium.launch({headless:true,...(process.env.TEST_BROWSER_CHANNEL?{channel:process.env.TEST_BROWSER_CHANNEL}:{}),args:process.env.TEST_PREVIEW_IP?['--host-resolver-rules=MAP '+new URL(base).hostname+' '+process.env.TEST_PREVIEW_IP]:[]});
const ctx=await browser.newContext();await ctx.route('**/*',r=>[base,cfg.url].includes(new URL(r.request().url()).origin)?r.continue():r.abort());
const page=await ctx.newPage(),errors=[],passes=[],writes=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{const p=new URL(r.url()).pathname;if(r.url().startsWith(cfg.url)&&/\/rpc\/(?:create|update|save|delete|register)_/.test(p))writes.push(p);});
const rpc=async(name,args={})=>page.evaluate(async({name,args})=>{const {sb}=await import('./account-specialist-api.js');const r=await sb.rpc(name,args);if(r.error){const e=Error(r.error.code+': '+r.error.message);throw e;}return r.data;},{name,args});
const attempt=async(name,args={})=>page.evaluate(async({name,args})=>{const {sb}=await import('./account-specialist-api.js');const r=await sb.rpc(name,args);return {data:r.data,code:r.error?.code};},{name,args});
const ready=()=>page.locator('#fields:not([disabled])').waitFor();
const pass=s=>{passes.push(s);console.log('PASS HOSTED UX',passes.length,s);};
const slug='ux-check-'+Date.now();let id,before,selected=false;
async function login(user){await page.goto(base+'/account-login');await page.locator('#email').fill(user.email);await page.locator('#password').fill(user.password);await page.locator('#submit').click();await page.waitForURL(/\/account-home(?:\.html)?$/);}
try{
 for(const user of cfg.users){
  await login(user);const list=await rpc('get_my_specialists');
  if(list.filter(x=>x.profile_status==='draft').length<3){before=list;selected=true;break;}
  await page.evaluate(async()=>{const {sb}=await import('./account-specialist-api.js');await sb.auth.signOut();});
 }
 assert(selected,'No free synthetic draft slot; no existing draft was modified');
 const probe=await attempt('delete_my_specialist_draft',{p_specialist_id:crypto.randomUUID()});assert.equal(probe.code,'42501','Existing cleanup RPC must be available before creating a fixture');
 await fs.writeFile(output+'/ux-hosted-before.json',JSON.stringify(before));
 await page.goto(base+'/account-create-specialist');await ready();await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.name),'display_name');assert.equal(await page.locator('[name=display_name]').getAttribute('aria-invalid'),'true');
 await page.locator('[name=display_name]').fill('UX временный специалист');await page.locator('[name=slug]').fill(slug);await page.locator('[name=profession]').fill('Фотограф');await page.locator('[name=city]').fill('Калининград');await page.locator('#save').click();await page.locator('#save-note').filter({hasText:'Сохранено.'}).waitFor();id=new URL(page.url()).searchParams.get('id');assert(id);assert.equal(await page.locator('.editor-nav a').count(),5);assert(!(await page.locator('[name=slug]').isEditable()));pass('create validates field, actual RPC saves, stays in editor with id and update mode');
 await page.locator('[name=description]').fill('Небольшое описание без обязательного порога длины.');await page.locator('#save').click();await page.locator('#save-note').filter({hasText:'Сохранено.'}).waitFor();await page.reload();await ready();assert.equal(await page.locator('[name=description]').inputValue(),'Небольшое описание без обязательного порога длины.');assert.equal((await rpc('get_my_specialists')).filter(x=>x.slug===slug).length,1);assert.equal(new URL(page.url()).searchParams.get('id'),id);pass('edit/reload remains same profile; no duplicate creation and no 100-character requirement');
 for(const width of [390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:output+'/ux-profile-'+width+'.png',fullPage:true});}
 await page.getByRole('link',{name:'К списку профилей',exact:true}).click();await page.waitForURL(/\/account-home(?:\.html)?$/);pass('explicit return works; profile mobile/desktop layout checked');
 await page.goto(base+'/account-specialist-services?id='+id);await ready();await page.locator('#name').fill('Консультация');await page.locator('#price-from').fill('2000');await page.locator('#price-to').fill('1000');await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.id),'price-to');assert.equal((await rpc('get_my_specialist_services',{p_specialist_id:id})).length,0);await page.locator('#price-to').fill('3000');await page.locator('#description').fill('Что входит, подготовка и результат');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Услуга сохранена'}).waitFor();await page.reload();await ready();await page.getByRole('button',{name:'Изменить',exact:true}).click();assert.equal(await page.locator('#description').inputValue(),'Что входит, подготовка и результат');pass('service invalid range focuses exact field, valid service persists and reopens');
 await page.goto(base+'/account-specialist-contacts?id='+id);await ready();await page.locator('#email').fill('bad');await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.id),'email');assert.equal((await rpc('get_my_specialist_settings',{p_specialist_id:id})).version,0);await page.locator('#email').fill('name@mail.ru');await page.locator('#area').fill('Калининградская область');await page.locator('#qualifications').fill('Тестовые курсы');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();await page.reload();await ready();assert.equal(await page.locator('#qualifications').inputValue(),'Тестовые курсы');assert.equal(await page.locator('#area').inputValue(),'Калининградская область');assert.equal((await rpc('get_my_specialists')).find(x=>x.id===id).city,'Калининград');pass('email validation prevents writes; qualifications and territory persist separately from city');
 for(const width of [390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:output+'/ux-contacts-'+width+'.png',fullPage:true});}
 await page.goto(base+'/account-specialist-media?id='+id);await ready();await page.locator('#file').setInputFiles({name:'photo.heic',mimeType:'image/heic',buffer:Buffer.from('test')});await page.locator('#save').click();await page.locator('#status').filter({hasText:'Проверьте формат'}).waitFor();assert.equal(await page.evaluate(()=>document.activeElement.id),'file');assert.equal((await rpc('get_my_specialist_media',{p_specialist_id:id})).length,0);pass('HEIC guidance and focused error; no test photo uploaded');
 assert.deepEqual(errors,[]);assert(writes.every(p=>p.includes('specialist')));pass('zero page errors, no company/publication requests');
}finally{
 if(selected){
  // Find by unique nonce even if the create reply was interrupted.
  const list=await rpc('get_my_specialists');const created=list.filter(x=>x.slug===slug);
  assert(created.length<=1);for(const row of created){assert.equal(row.display_name,'UX временный специалист');assert.equal(row.profile_status,'draft');await rpc('delete_my_specialist_draft',{p_specialist_id:row.id});}
  assert.deepEqual(await rpc('get_my_specialists'),before);pass('temporary draft, service and settings removed through existing owner RPC; original profiles unchanged');
 }
 await fs.writeFile(output+'/ux-hosted-result.json',JSON.stringify({preview:base,passes,errors},null,2));await browser.close();
}
