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
const url='https://cabinet.test/account-specialist-contacts.html?id='+a.id,root=page.locator('#specialist-channels'),rows=root.locator('.channel-row');
const save=root.getByRole('button',{name:'Сохранить контакты',exact:true}),note=root.locator('[role=status]'),add=root.getByRole('button',{name:'Добавить контакт',exact:true});
const read=()=>db.call(A,'list_my_specialist_channels',[a.id]);
const payload=rows=>rows.map(({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public})=>({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public}));
const wait=()=>page.locator('#specialist-channels form>fieldset:not([disabled])').waitFor();
async function ready(){await page.goto(url);await wait();}
async function saved(){await save.click();await note.filter({hasText:'Контакты сохранены'}).waitFor();}
let count=0;const test=async(name,fn)=>{await fn();console.log('PASS COMPACT CHANNEL BROWSER',++count,name);};
try{
 await test('one input/select/remove per row; all seven kinds create/save/reopen',async()=>{
  await ready();assert.equal(await rows.count(),1);
  assert.equal(await add.evaluate(e=>getComputedStyle(e).backgroundColor),await save.evaluate(e=>getComputedStyle(e).backgroundColor));
  for(const [kind,value] of [['telegram',''],['telegram','   '],['whatsapp','66667666'],['telegram','https://vk.com/id123']]){
   await rows.first().locator('select').selectOption(kind);await rows.first().locator('input').fill(value);await add.click();assert.equal(await rows.count(),1);assert.equal(await rows.first().locator('input').getAttribute('aria-invalid'),'true');await save.click();assert.equal((await read()).version,0);assert.equal((await read()).channels.length,0);
  }
  const values={telegram:'@Yumis_test',max:'https://max.ru/u/Example',vk:'https://vk.com/id123',whatsapp:'+79991234567',ok:'https://ok.ru/profile/123',website:'https://example.ru',portfolio:'https://portfolio.ru/work'};
  for(const [kind,value] of Object.entries(values)){if(kind!=='telegram')await add.click();await rows.last().locator('select').selectOption(kind);await rows.last().locator('input').fill(value);}
  for(const row of await rows.all()){assert.equal(await row.locator('input').count(),1);assert.equal(await row.locator('select').count(),1);assert.equal(await row.locator('button').count(),1);assert.equal(await row.locator('fieldset,legend,a').count(),0);}
  assert.equal(await root.locator('input[type=checkbox]').count(),0);assert.equal(await rows.first().locator('optgroup').count(),3);
  await saved();await ready();assert.equal(await rows.count(),7);assert.equal(await rows.first().locator('input').inputValue(),'@Yumis_test');
  for(const width of [320,390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));assert.equal(await rows.first().evaluate(e=>getComputedStyle(e).borderTopWidth),'0px');}
  if(process.env.CHANNEL_SCREENSHOT_DIR){await root.screenshot({path:process.env.CHANNEL_SCREENSHOT_DIR+'/contacts-desktop.png'});await page.setViewportSize({width:390,height:1000});await root.screenshot({path:process.env.CHANNEL_SCREENSHOT_DIR+'/contacts-mobile.png'});}
 });
 await test('editing visible input preserves hidden labels, preferred, inquiries, IDs and order',async()=>{
  let data=await read();const old=payload(data.channels);old[0].label='<img src=x onerror=alert(1)>';old[0].is_preferred=true;old[0].accepts_inquiries=true;
  await db.call(A,'save_my_specialist_channels',[a.id,data.version,JSON.stringify(old)]);await ready();assert.equal(await root.locator('img').count(),0);assert.equal(await root.getByText(old[0].label,{exact:true}).count(),0);
  await rows.first().locator('input').fill('@Updated_test');await saved();data=await read();
  assert.deepEqual(data.channels.map(r=>r.id),old.map(r=>r.id));assert.equal(data.channels[0].label,old[0].label);assert(data.channels[0].is_preferred&&data.channels[0].accepts_inquiries);assert.equal(data.channels[0].value_raw,'@Updated_test');assert(data.channels.every(r=>r.is_public===false));
  await page.locator('#phone').fill('+79990000000');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();assert.deepEqual(await read(),data);
 });
 await test('compact delete persists; duplicate and unsafe inputs rejected',async()=>{
  const before=await read();await rows.nth(1).getByRole('button',{name:/Удалить контакт/}).click();await saved();await ready();
  assert.equal(await rows.count(),6);assert.deepEqual((await read()).channels.map(r=>r.id),before.channels.filter((_,i)=>i!==1).map(r=>r.id));
  await add.click();await rows.last().locator('input').fill('https://t.me/updated_test');await save.click();await note.filter({hasText:'уже добавлен'}).waitFor();
  await rows.last().locator('select').selectOption('website');await rows.last().locator('input').fill('javascript:alert(1)');await rows.last().locator('input').blur();assert.equal(await rows.last().locator('input').evaluate(e=>e.checkValidity()),false);
  await rows.last().getByRole('button',{name:/Удалить контакт/}).click();
 });
 await test('stale version, offline retention and disabled double submit remain correct',async()=>{
  const current=await read();await db.call(A,'save_my_specialist_channels',[a.id,current.version,'[]']);await save.click();await note.filter({hasText:'Обновите'}).waitFor();assert.equal(await rows.count(),6);
  await ready();await rows.first().locator('input').fill('@offline_test');offline=true;await save.click();await note.filter({hasText:'Не удалось'}).waitFor();assert.equal(await rows.first().locator('input').inputValue(),'@offline_test');offline=false;
  hold=true;await save.click();assert.equal(await save.isEnabled(),false);await note.filter({hasText:'Контакты сохранены'}).waitFor();hold=false;
 });
 await test('missing RPC disables channels only; old settings and existing navigation work',async()=>{
  missing=true;await page.reload();await note.filter({hasText:'пока недоступны'}).waitFor();assert.equal(await save.isEnabled(),false);assert.equal(await page.locator('#save').isEnabled(),true);
  await page.locator('#phone').fill('+79991111111');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();
  assert.equal(await page.locator('.editor-nav a').count(),5);assert.equal(await page.getByText('Все разделы',{exact:true}).count(),0);
 });
 assert.deepEqual(errors,[]);console.log('COMPACT CHANNEL BROWSER RESULT',count,'groups PASS; disposable SQL adapter, not hosted');
}finally{await browser.close();await db.close();}
