import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {chromium} from 'playwright';
import {database,A} from './database.mjs';
import {buildPages} from '../scripts/build-pages.mjs';
await buildPages();
const db=await database({editor:true});
await db.exec(await fs.readFile(new URL('../docs/specialist-contact-channels-candidate.sql',import.meta.url),'utf8'));
const a=await db.call(A,'create_my_specialist_draft',['Channels browser','channels-browser','Master']);
const browser=await chromium.launch({headless:true,...(process.platform==='win32'?{channel:'msedge'}:{})});
const ctx=await browser.newContext();let missing=false,offline=false,hold=false;
const calls=[],errors=[];
await ctx.route('**/*',async route=>{
 const u=new URL(route.request().url());
 if(u.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'text/javascript',body:await fs.readFile(new URL('./browser-client-stub.js',import.meta.url),'utf8')});
 if(u.origin==='https://cabinet.test'&&/^\/account-[a-z-]+\.(html|js|css)$/.test(u.pathname))return route.fulfill({contentType:u.pathname.endsWith('.js')?'text/javascript':u.pathname.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(new URL('../_site'+u.pathname,import.meta.url),'utf8')});
 return route.abort();
});
await ctx.exposeBinding('testSession',()=>({user:{id:A}}));
await ctx.exposeBinding('testRPC',async(_,name,args={})=>{
 calls.push(name);
 if(missing&&name==='list_my_specialist_channels')return {data:null,error:{code:'PGRST202',message:'missing'}};
 if(offline&&name==='save_my_specialist_channels')return {data:null,error:{code:'NETWORK',message:'Offline'}};
 if(hold&&name==='save_my_specialist_channels')await new Promise(r=>setTimeout(r,300));
 const keys={get_my_specialists:[],get_my_specialist_settings:['p_specialist_id'],save_my_specialist_settings:['p_specialist_id','p_phone','p_email','p_website','p_work_formats','p_service_area','p_qualifications','p_version'],list_my_specialist_channels:['p_specialist_id'],save_my_specialist_channels:['p_specialist_id','p_version','p_channels']}[name];
 assert(keys,'Unexpected RPC '+name);
 try{return {data:await db.call(A,name,keys.map(k=>k==='p_channels'?JSON.stringify(args[k]):args[k])),error:null};}catch(e){return {data:null,error:{code:e.code,message:e.message}};}
});
const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
const url='https://cabinet.test/account-specialist-contacts.html?id='+a.id;
const root=page.locator('#specialist-channels'),rows=root.locator('.channel-row');
const save=root.getByRole('button',{name:'Сохранить каналы',exact:true});
const note=root.locator('[role=status]');
const add=root.getByRole('button',{name:'Добавить контакт',exact:true});
let count=0;const test=async(name,fn)=>{await fn();console.log('PASS CHANNEL BROWSER',++count,name);};
async function ready(){await page.goto(url);await save.waitFor();await page.waitForFunction(()=>!document.querySelector('#specialist-channels form>fieldset').disabled);}
try{
 await test('seven kinds; create/save/reload; settings independent',async()=>{
  await ready();const values={telegram:'@Yumis_test',max:'https://max.ru/u/Example',vk:'https://vk.com/id123',whatsapp:'+79991234567',ok:'https://ok.ru/profile/123',website:'https://example.ru',portfolio:'https://portfolio.ru/work'};
  for(const [kind,value] of Object.entries(values)){await add.click();const row=rows.last();await row.locator('select').selectOption(kind);await row.locator('input').nth(0).fill(value);await row.locator('input').nth(1).fill(kind);}
  await rows.first().getByLabel('Предпочтительный канал',{exact:true}).check();
  await rows.first().getByLabel('Принимаю обращения по этому каналу',{exact:true}).check();
  await save.click();await note.filter({hasText:'Каналы сохранены'}).waitFor();
  await ready();assert.equal(await rows.count(),7);assert.equal(await rows.first().locator('input').nth(0).inputValue(),'@Yumis_test');
  await page.locator('#phone').fill('+79990000000');await page.locator('#save').click();await page.locator('#status').filter({hasText:'сохранены'}).waitFor();
  assert.equal((await db.call(A,'list_my_specialist_channels',[a.id])).channels.length,7);
 });
 await test('edit/order/remove; preferred exclusive; labels stay inert text; safe links',async()=>{
  await rows.first().getByRole('button',{name:'Ниже',exact:true}).click();
  await rows.first().getByLabel('Предпочтительный канал',{exact:true}).check();
  assert.equal(await root.locator('input[type=checkbox]:checked').count(),2); // one inquiry and one preferred
  await rows.first().locator('input').nth(1).fill('<img src=x onerror=alert(1)>');
  await rows.last().getByRole('button',{name:'Удалить',exact:true}).click();await save.click();await note.filter({hasText:'Каналы сохранены'}).waitFor();
  await ready();assert.equal(await rows.count(),6);assert.equal(await rows.first().locator('select').inputValue(),'max');assert.equal(await root.locator('img').count(),0);await page.setViewportSize({width:390,height:900});await root.screenshot({path:'C:/Users/Yumis/otzovik-stage2b-contacts-mobile.png'});await page.setViewportSize({width:1440,height:1000});await root.screenshot({path:'C:/Users/Yumis/otzovik-stage2b-contacts-desktop.png'});
  assert.equal(await rows.first().locator('input').nth(1).inputValue(),'<img src=x onerror=alert(1)>');
  for(const a of await root.locator('a').all()){assert((await a.getAttribute('href')).startsWith('https://'));assert((await a.getAttribute('rel')).includes('noopener'));}
 });
 await test('duplicates and unsafe URLs rejected without losing input',async()=>{
  await add.click();await rows.last().locator('input').nth(0).fill('https://t.me/yumis_test');await save.click();await note.filter({hasText:'уже добавлен'}).waitFor();
  await rows.last().locator('select').selectOption('website');await rows.last().locator('input').nth(0).fill('javascript:alert(1)');await rows.last().locator('input').nth(0).blur();assert.equal(await rows.last().locator('input').nth(0).evaluate(x=>x.checkValidity()),false);
  await rows.last().getByRole('button',{name:'Удалить',exact:true}).click();
 });
 await test('stale tab cannot overwrite; network error leaves draft intact; double submit disabled',async()=>{
  const current=await db.call(A,'list_my_specialist_channels',[a.id]);
  await db.call(A,'save_my_specialist_channels',[a.id,current.version,JSON.stringify([])]);
  await save.click();await note.filter({hasText:'Обновите'}).waitFor();assert.equal(await rows.count(),6);
  await ready();await add.click();await rows.first().locator('input').nth(0).fill('@offline_test');
  offline=true;await save.click();await note.filter({hasText:'Не удалось'}).waitFor();assert.equal(await rows.first().locator('input').nth(0).inputValue(),'@offline_test');offline=false;
  hold=true;await save.click();assert.equal(await save.isEnabled(),false);await note.filter({hasText:'Каналы сохранены'}).waitFor();hold=false;
 });
 await test('missing RPC disables channels only; old settings still save; no extra navigation',async()=>{
  missing=true;await page.reload();await note.filter({hasText:'пока недоступны'}).waitFor();assert.equal(await save.isEnabled(),false);assert.equal(await page.locator('#save').isEnabled(),true);
  await page.locator('#phone').fill('+79991111111');await page.locator('#save').click();await page.locator('#status').filter({hasText:'сохранены'}).waitFor();
  assert.equal(await page.getByText('Все разделы',{exact:true}).count(),0);assert.equal(await page.locator('.editor-nav a').count(),5);
  for(const width of [390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
 });
 assert.deepEqual(errors,[]);console.log('CHANNEL BROWSER RESULT',count,'groups PASS; browser RPCs backed by disposable PGlite, not hosted');
}finally{await browser.close();await db.close();}
