import assert from 'node:assert/strict';import fs from 'node:fs/promises';import {chromium} from 'playwright';
import {database,A} from './database.mjs';import {buildPages} from '../scripts/build-pages.mjs';
await buildPages();const db=await database({editor:true});
await db.exec(await fs.readFile(new URL('../docs/specialist-contact-channels-candidate.sql',import.meta.url),'utf8'));
const a=await db.call(A,'create_my_specialist_draft',['Compact contacts','compact-channels','Master']);
const browser=await chromium.launch({headless:true,...(process.platform==='win32'?{channel:'msedge'}:{})});
const ctx=await browser.newContext();let missing=false,offline=false,hold=false;const errors=[];
await ctx.route('**/*',async route=>{
 const u=new URL(route.request().url());
 if(u.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'text/javascript',body:await fs.readFile(new URL('./browser-client-stub.js',import.meta.url),'utf8')});
 if(u.origin==='https://cabinet.test'&&/^\/account-[a-z-]+\.(html|js|css)$/.test(u.pathname))return route.fulfill({contentType:u.pathname.endsWith('.js')?'text/javascript':u.pathname.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(new URL('../_site'+u.pathname,import.meta.url),'utf8')});
 return route.abort();
});
await ctx.exposeBinding('testSession',()=>({user:{id:A}}));
await ctx.exposeBinding('testRPC',async(_,name,args={})=>{
 if(missing&&name==='list_my_specialist_channels')return {data:null,error:{code:'PGRST202',message:'missing'}};
 if(offline&&name==='save_my_specialist_channels')return {data:null,error:{code:'NETWORK',message:'Offline'}};
 if(hold&&name==='save_my_specialist_channels')await new Promise(r=>setTimeout(r,300));
 const keys={get_my_specialists:[],get_my_specialist_settings:['p_specialist_id'],save_my_specialist_settings:['p_specialist_id','p_phone','p_email','p_website','p_work_formats','p_service_area','p_qualifications','p_version'],list_my_specialist_channels:['p_specialist_id'],save_my_specialist_channels:['p_specialist_id','p_version','p_channels']}[name];assert(keys,'Unexpected RPC '+name);
 try{return {data:await db.call(A,name,keys.map(k=>k==='p_channels'?JSON.stringify(args[k]):args[k])),error:null};}catch(e){return {data:null,error:{code:e.code,message:e.message}};}
});
const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
const url='https://cabinet.test/account-specialist-contacts.html?id='+a.id,root=page.locator('#specialist-channels');
const input=kind=>root.locator('input[data-kind='+kind+']').first(),save=page.locator('#save'),note=page.locator('#status');
const read=()=>db.call(A,'list_my_specialist_channels',[a.id]);
const payload=rows=>rows.map(({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public})=>({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public}));
async function ready(){await page.goto(url);await page.locator('#fields:not([disabled])').waitFor();}
async function saved(){await save.click();await note.filter({hasText:'Контакты сохранены'}).waitFor();}
let count=0;const test=async(name,fn)=>{await fn();console.log('PASS FIXED CONTACTS BROWSER',++count,name);};
try{
 await test('one form, fixed optional labels, single black save; empty fields create no contacts',async()=>{
  await ready();assert.equal(await page.locator('#email').getAttribute('placeholder'),'name@mail.ru');assert.equal(await page.locator('#email').inputValue(),'');assert.equal(await page.locator('#website').getAttribute('placeholder'),'Ссылка профиля — после публикации');assert.equal(await page.locator('#website').inputValue(),'');assert.equal(await page.locator('#phone').inputValue(),'+7');assert.equal(await input('whatsapp').inputValue(),'+7');assert.equal(await page.locator('form').count(),1);assert.equal(await root.locator('select,button').count(),0);assert.equal(await root.locator('input').count(),6);assert.equal(await page.locator('#website').count(),1);
  assert.equal(await save.evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(16, 24, 40)');
  await input('telegram').fill('   ');await saved();assert.equal((await read()).channels.length,0);assert.equal((await db.call(A,'get_my_specialist_settings',[a.id])).phone??null,null);assert.equal((await db.call(A,'get_my_specialist_settings',[a.id])).website??null,null);assert.equal((await db.call(A,'get_my_specialist_settings',[a.id])).email??null,null);
  assert.equal(await page.locator('.editor-nav a').count(),5);assert.equal(await page.getByText('Все разделы',{exact:true}).count(),0);
 });
 await test('editable prefixes; foreign numbers survive reopen; bare +7 stores no contact',async()=>{
  await page.locator('#phone').fill('+491234567890');await input('whatsapp').fill('+491234567890');await saved();await ready();
  assert.equal(await page.locator('#phone').inputValue(),'+491234567890');assert.equal(await input('whatsapp').inputValue(),'+491234567890');
  await page.locator('#phone').fill('');await page.locator('#email').focus();assert.equal(await page.locator('#phone').inputValue(),'+7');
  await input('whatsapp').fill('');await page.locator('#email').focus();assert.equal(await input('whatsapp').inputValue(),'+7');
  await saved();await ready();assert.equal((await read()).channels.length,0);assert.equal((await db.call(A,'get_my_specialist_settings',[a.id])).phone??null,null);
  await page.locator('#phone').fill(' +7 ');await input('whatsapp').fill(' +7 ');await saved();assert.equal((await read()).channels.length,0);assert.equal((await db.call(A,'get_my_specialist_settings',[a.id])).phone??null,null);
 });
 await test('all optional kinds plus site/phone save and reopen; cosmetic URL normalization',async()=>{
  const values={telegram:'@Yumis_test',whatsapp:'+79991234567',max:'https://max.ru/u/CaseToken',vk:' Https://VK.com/id123 ',ok:'https://ok.ru/profile/123',portfolio:'HtTpS://Example.com/CaseSensitive?A=B'};
  for(const [kind,value] of Object.entries(values))await input(kind).fill(value);
  await page.locator('#website').fill(' HtTpS://пример.рф/SiteCase?A=B ');await page.locator('#phone').fill('+79990000000');await saved();await ready();
  assert.equal((await read()).channels.length,6);assert.equal(await input('vk').inputValue(),'https://VK.com/id123');assert.equal(await page.locator('#website').inputValue(),'https://пример.рф/SiteCase?A=B');
  for(const width of [320,390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
  if(process.env.CHANNEL_SCREENSHOT_DIR){await page.setViewportSize({width:390,height:1000});await page.screenshot({path:process.env.CHANNEL_SCREENSHOT_DIR+'/fixed-mobile.png',fullPage:true});}
 });
 await test('invalid links block both RPCs; blank field deletes only that contact',async()=>{
  const before=await read(),settings=await db.call(A,'get_my_specialist_settings',[a.id]);
  await page.locator('#phone').fill('+79991111111');await input('whatsapp').fill('66667666');await save.click();assert.equal(await input('whatsapp').getAttribute('aria-invalid'),'true');assert.deepEqual(await read(),before);assert.deepEqual(await db.call(A,'get_my_specialist_settings',[a.id]),settings);
  await input('whatsapp').fill('');await saved();await ready();assert.equal(await input('whatsapp').inputValue(),'+7');assert.equal((await read()).channels.length,5);
  await page.locator('#website').fill('javascript:alert(1)');await save.click();assert.equal(await page.locator('#website').getAttribute('aria-invalid'),'true');assert.equal((await read()).channels.length,5);await ready();
 });
 await test('previous multiple contacts, website channels and hidden metadata survive',async()=>{
  let data=await read();const old=payload(data.channels);old[0].label='<img src=x onerror=alert(1)>';old[0].is_preferred=true;old[0].accepts_inquiries=true;
  old.push({...old[0],id:crypto.randomUUID(),value_raw:'@extra_test',label:'extra',is_preferred:false});old.push({...old[0],id:crypto.randomUUID(),kind:'website',value_raw:'https://oldsite.ru/Case',label:'old site',is_preferred:false});
  await db.call(A,'save_my_specialist_channels',[a.id,data.version,JSON.stringify(old)]);await ready();
  assert.equal(await root.locator('input[data-kind=telegram]').count(),2);assert.equal(await page.locator('#other-links a').count(),1);assert.equal(await page.locator('#contacts-form img').count(),0);
  await input('telegram').fill('@updated_test');await saved();data=await read();assert.deepEqual(data.channels.map(r=>r.id),old.map(r=>r.id));assert.equal(data.channels[0].label,old[0].label);assert(data.channels[0].is_preferred&&data.channels[0].accepts_inquiries);
  assert.equal(data.channels.at(-1).value_raw,'https://oldsite.ru/Case');
  await root.locator('input[data-kind=telegram]').last().fill('https://t.me/updated_test');await save.click();assert.equal(await root.locator('input[data-kind=telegram]').last().getAttribute('aria-invalid'),'true');await ready();
 });
 await test('partial failure is explicit; retry retains input, versions and prevents double submit',async()=>{
  await page.locator('#phone').fill('+79992222222');await input('telegram').fill('@retry_test');offline=true;await save.click();await note.filter({hasText:'Основные поля сохранены, но'}).waitFor();assert.equal(await input('telegram').inputValue(),'@retry_test');
  const version=(await db.call(A,'get_my_specialist_settings',[a.id])).version;offline=false;hold=true;await save.click();assert.equal(await save.isEnabled(),false);await note.filter({hasText:'Контакты сохранены'}).waitFor();hold=false;assert.equal((await db.call(A,'get_my_specialist_settings',[a.id])).version,version);
  const current=await read();await db.call(A,'save_my_specialist_channels',[a.id,current.version,'[]']);await save.click();await note.filter({hasText:'Обновите'}).waitFor();assert.equal(await input('telegram').inputValue(),'@retry_test');
 });
 await test('custom named links add repeatedly, stay inert, save/reopen/edit/delete',async()=>{
  await ready();const box=page.locator('#other-links'),title=box.locator('#other-link-name'),urlInput=box.locator('#other-link-url'),add=box.getByRole('button',{name:'Добавить ссылку',exact:true});
  const version=(await read()).version;
  await add.click();assert.equal(await box.locator('li').count(),0);assert.equal(await title.getAttribute('aria-invalid'),'true');
  await title.fill('Мой блог');await urlInput.fill('javascript:alert(1)');await add.click();assert.equal(await box.locator('li').count(),0);
  await urlInput.fill(' Https://Example.com/MyBlog?A=B ');await add.click();assert.equal(await box.locator('li').count(),1);assert.equal(await title.inputValue(),'');assert.equal(await urlInput.inputValue(),'');assert.equal((await read()).version,version);
  await title.fill('<img src=x onerror=alert(1)>');await urlInput.fill('https://gallery.ru/work');await add.click();assert.equal(await box.locator('li').count(),2);assert.equal(await box.locator('img').count(),0);
  await title.fill('Дубль');await urlInput.fill('https://example.com/MyBlog?A=B');await add.click();assert.equal(await box.locator('li').count(),2);assert.equal(await urlInput.getAttribute('aria-invalid'),'true');
  await title.fill('');await urlInput.fill('');await saved();await ready();
  assert.equal(await box.locator('li').count(),2);const link=box.getByRole('link',{name:'Мой блог',exact:true});assert.equal(await link.getAttribute('href'),'https://example.com/MyBlog?A=B');assert.equal(await link.getAttribute('rel'),'noopener noreferrer nofollow');
  const original=(await read()).channels;
  await box.getByRole('button',{name:'Изменить ссылку Мой блог',exact:true}).click();await title.fill('Мой журнал');await urlInput.fill('https://example.com/Updated');await box.getByRole('button',{name:'Применить изменения',exact:true}).click();await saved();await ready();
  assert.equal((await read()).channels[0].id,original[0].id);assert.equal(await box.getByRole('link',{name:'Мой журнал',exact:true}).count(),1);
  await box.getByRole('button',{name:'Удалить ссылку Мой журнал',exact:true}).click();await saved();await ready();assert.equal(await box.locator('li').count(),1);
  // Direct Save includes a completed composer, but rejects incomplete input.
  await title.fill('Следующая');const before=await read();await save.click();assert.deepEqual(await read(),before);
  await urlInput.fill('https://next.ru/work');offline=true;await save.click();await note.filter({hasText:'не сохранены'}).waitFor();assert.equal(await box.locator('li').count(),2);offline=false;await saved();await ready();assert.equal(await box.locator('li').count(),2);
  for(const width of [320,390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
 });
 await test('custom links share 20-contact limit, with deletion freeing a slot',async()=>{
  const data=await read(),many=Array.from({length:20},(_,i)=>({id:crypto.randomUUID(),kind:'website',value_raw:'https://site'+i+'.ru',label:'Ссылка '+i,is_preferred:false,accepts_inquiries:false,is_public:false}));
  await db.call(A,'save_my_specialist_channels',[a.id,data.version,JSON.stringify(many)]);await ready();
  const box=page.locator('#other-links');await box.locator('#other-link-name').fill('Ещё');await box.locator('#other-link-url').fill('https://more.ru');await box.getByRole('button',{name:'Добавить ссылку',exact:true}).click();assert.equal(await box.locator('li').count(),20);await box.locator('[role=status]').filter({hasText:'20 контактов'}).waitFor();
  await box.getByRole('button',{name:'Удалить ссылку Ссылка 0',exact:true}).click();await box.getByRole('button',{name:'Добавить ссылку',exact:true}).click();assert.equal(await box.locator('li').count(),20);await saved();assert.equal((await read()).channels.length,20);
 });
 await test('missing channels RPC leaves old settings usable without false all-saved message',async()=>{
  missing=true;await ready();assert.equal(await input('telegram').isEnabled(),false);assert.equal(await save.isEnabled(),true);await page.locator('#phone').fill('+79993333333');await save.click();await note.filter({hasText:'недоступны и не изменены'}).waitFor();
 });
 assert.deepEqual(errors,[]);console.log('FIXED CONTACTS BROWSER RESULT',count,'groups PASS; disposable SQL adapter, not hosted');
}finally{await browser.close();await db.close();}

// Run specialist UX regression in the same browser acceptance entry point.
await import('./specialist-ux-browser.mjs');
