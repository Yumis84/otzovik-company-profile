import assert from 'node:assert/strict';import fs from 'node:fs/promises';import {chromium} from 'playwright';
import {database,A,B} from './database.mjs';import {buildPages} from '../scripts/build-pages.mjs';
await buildPages();const db=await database({editor:true});await db.exec(await fs.readFile(new URL('../docs/specialist-contact-channels-candidate.sql',import.meta.url),'utf8'));
const browser=await chromium.launch({headless:true,...(process.platform==='win32'?{channel:'msedge'}:{})});
const ctx=await browser.newContext();let user=A,fail=null,slow=null,calls=[];const errors=[];
const keys={
 create_my_specialist_draft:['p_display_name','p_slug','p_profession','p_specialization','p_city','p_description'],
 update_my_specialist_draft:['p_id','p_display_name','p_profession','p_specialization','p_city','p_description'],
 get_my_specialists:[],get_my_specialist_services:['p_specialist_id'],
 save_my_specialist_service:['p_specialist_id','p_service_id','p_name','p_description','p_price_from','p_price_to','p_currency','p_duration_minutes','p_is_active','p_version'],
 get_my_specialist_media:['p_specialist_id'],get_my_specialist_settings:['p_specialist_id'],
 save_my_specialist_settings:['p_specialist_id','p_phone','p_email','p_website','p_work_formats','p_service_area','p_qualifications','p_version'],
 list_my_specialist_channels:['p_specialist_id'],save_my_specialist_channels:['p_specialist_id','p_version','p_channels']
};
await ctx.route('**/*',async route=>{
 const u=new URL(route.request().url());
 if(u.hostname==='cdn.jsdelivr.net'){
  let stub=await fs.readFile(new URL('./browser-client-stub.js',import.meta.url),'utf8');
  stub=stub.replace('upload:async path','list:async()=>({data:[],error:null}),upload:async path');
  return route.fulfill({contentType:'text/javascript',body:stub});
 }
 if(u.origin==='https://cabinet.test'&&/^\/account-[a-z-]+\.(html|js|css)$/.test(u.pathname))return route.fulfill({contentType:u.pathname.endsWith('.js')?'text/javascript':u.pathname.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(new URL('../_site'+u.pathname,import.meta.url),'utf8')});
 return route.abort();
});
await ctx.exposeBinding('testSession',()=>user?{user:{id:user}}:null);
await ctx.exposeBinding('testRPC',async(_,name,args={})=>{
 calls.push({name,args});assert(keys[name],'Unexpected RPC '+name);
 if(fail===name)throw Error('offline');if(slow===name)await new Promise(r=>setTimeout(r,200));
 try{return {data:await db.call(user,name,keys[name].map(k=>k==='p_channels'?JSON.stringify(args[k]):args[k])),error:null};}catch(e){return {data:null,error:{code:e.code,message:e.message}};}
});
const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
const open=path=>page.goto('https://cabinet.test/'+path),ready=()=>page.locator('#fields:not([disabled])').waitFor();
const note=page.locator('#save-note');let id,count=0;
const test=async(name,fn)=>{await fn();console.log('PASS UX',++count,name);};
try{
 await test('create validates exact fields, stays as editable saved id, no duplicate create',async()=>{
  await open('account-create-specialist.html');await ready();await page.locator('#save').click();assert.equal(await page.locator('[name=display_name]').getAttribute('aria-invalid'),'true');assert.equal(await page.evaluate(()=>document.activeElement.name),'display_name');
  await page.locator('[name=display_name]').fill('UX специалист');await page.locator('[name=profession]').fill('Фотограф');await page.locator('[name=slug]').fill('admin');await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.name),'slug');
  await page.locator('[name=slug]').fill('ux-specialist');await page.locator('[name=city]').fill('Калининград');await page.locator('#save').click();await note.filter({hasText:'Сохранено.'}).waitFor();
  id=new URL(page.url()).searchParams.get('id');assert(id);assert(await page.locator('[name=slug]').isEditable()===false);assert.equal(await page.locator('.editor-nav a').count(),5);
  await page.locator('#save').click();await note.filter({hasText:'Сохранено.'}).waitFor();assert.equal((await db.call(A,'get_my_specialists')).length,1);assert.equal(calls.filter(c=>c.name==='create_my_specialist_draft').length,1);
 });
 await test('edit/reopen updates context and retains input after offline; mobile and desktop',async()=>{
  await page.locator('[name=display_name]').fill('UX обновлённый');await page.locator('[name=description]').fill('Описание сохранено');
  fail='update_my_specialist_draft';await page.locator('#save').click();await note.filter({hasText:'Не удалось подтвердить'}).waitFor();assert.equal(await page.locator('[name=display_name]').inputValue(),'UX обновлённый');assert(await page.locator('#save').isEnabled());fail=null;
  slow='update_my_specialist_draft';await page.locator('#save').click();assert(await page.locator('#save').isDisabled());await note.filter({hasText:'Сохранено.'}).waitFor();slow=null;assert.equal(new URL(page.url()).searchParams.get('id'),id);assert.equal(await page.locator('#specialist-context strong').textContent(),'UX обновлённый');
  await page.reload();await ready();assert.equal(await page.locator('[name=description]').inputValue(),'Описание сохранено');
  for(const width of [390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
  if(process.env.UX_SCREENSHOT_DIR)await page.screenshot({path:process.env.UX_SCREENSHOT_DIR+'/ux-profile-desktop.png',fullPage:true});
  assert.equal(await page.getByRole('link',{name:'К списку профилей',exact:true}).getAttribute('href'),'account-home.html');
 });
 await test('services focus invalid range/name/duration and persist valid values',async()=>{
  await open('account-specialist-services.html?id='+id);await ready();await page.locator('#name').fill('  ');await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.id),'name');
  await page.locator('#name').fill('Консультация');await page.locator('#price-from').fill('2000');await page.locator('#price-to').fill('1000');await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.id),'price-to');assert.equal(await page.locator('#price-to').getAttribute('aria-invalid'),'true');
  await page.locator('#price-to').fill('3000');await page.locator('#duration').fill('0');await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.id),'duration');assert.equal((await db.call(A,'get_my_specialist_services',[id])).length,0);
  await page.locator('#duration').fill('60');await page.locator('#description').fill('Что входит, подготовка и результат');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Услуга сохранена'}).waitFor();const rows=await db.call(A,'get_my_specialist_services',[id]);assert.equal(rows[0].duration_minutes,60);await page.reload();await ready();await page.getByRole('button',{name:'Изменить',exact:true}).click();assert.equal(await page.locator('#price-to').inputValue(),'3000');assert.equal(await page.locator('#description').inputValue(),rows[0].description);await page.locator('#price-to').fill('1');await page.locator('#save').click();assert.equal(await page.locator('#price-to').getAttribute('aria-invalid'),'true');await page.getByRole('button',{name:'Изменить',exact:true}).click();assert.equal(await page.locator('#price-to').getAttribute('aria-invalid'),null);assert(await page.locator('#price-to').evaluate(e=>e.checkValidity()));
 });
 await test('contact email error focuses field; city/territory and qualifications remain distinct and saved',async()=>{
  await db.call(A,'save_my_specialist_settings',[id,null,null,null,['online'],'Область','Курсы фотографии',0]);
  await open('account-specialist-contacts.html?id='+id);await ready();await page.locator('#email').fill('bad');const before=await db.call(A,'get_my_specialist_settings',[id]);await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.id),'email');assert.equal(await page.locator('#email').getAttribute('aria-invalid'),'true');assert.deepEqual(await db.call(A,'get_my_specialist_settings',[id]),before);
  await page.locator('#email').fill('name@mail.ru');await page.locator('#area').fill('Калининград и область');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();await page.reload();await ready();assert.equal(await page.locator('#qualifications').inputValue(),'Курсы фотографии');assert.equal(await page.locator('#area').inputValue(),'Калининград и область');assert.equal((await db.call(A,'get_my_specialists'))[0].city,'Калининград');
  await page.setViewportSize({width:390,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));if(process.env.UX_SCREENSHOT_DIR)await page.screenshot({path:process.env.UX_SCREENSHOT_DIR+'/ux-contacts-mobile.png',fullPage:true});
 });
 await test('media empty and HEIC errors focus file without upload; guidance is present',async()=>{
  await open('account-specialist-media.html?id='+id);await ready();await page.locator('#save').click();assert.equal(await page.evaluate(()=>document.activeElement.id),'file');assert.equal(await page.locator('#file').getAttribute('aria-invalid'),'true');
  await page.locator('#file').setInputFiles({name:'photo.heic',mimeType:'image/heic',buffer:Buffer.from('not a photo')});await page.locator('#save').click();await page.locator('#status').filter({hasText:'Проверьте формат'}).waitFor();assert.equal(await page.evaluate(()=>document.activeElement.id),'file');assert.equal((await db.call(A,'get_my_specialist_media',[id])).length,0);assert.equal(await page.getByText(/HEIC с телефона/).count(),1);
 });
 await test('foreign draft and invalid id still fail closed',async()=>{
  user=B;await open('account-create-specialist.html?id='+id);await note.filter({hasText:'недоступен'}).waitFor();assert(await page.locator('#save').isDisabled());user=A;await open('account-create-specialist.html?id=invalid');await note.filter({hasText:'Некорректная'}).waitFor();assert(await page.locator('#save').isDisabled());
 });
 assert.deepEqual(errors,[]);console.log('UX RESULT',count,'groups PASS; isolated SQL, simulated Auth/Storage, no hosted writes');
}finally{await browser.close();await db.close();}
