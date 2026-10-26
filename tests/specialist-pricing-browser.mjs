import assert from 'node:assert/strict';import fs from 'node:fs/promises';import {chromium} from 'playwright';import {database,A,B} from './database.mjs';import {buildPages} from '../scripts/build-pages.mjs';
const db=await database({editor:true});const browser=await chromium.launch({headless:true,...(process.platform==='win32'?{channel:'msedge'}:{})});let count=0,missing=false,fail=false,user=A,calls=[];const errors=[];
const a=await db.call(A,'create_my_specialist_draft',['Pricing Browser','pricing-browser','Master']);
const legacy=await db.call(A,'save_my_specialist_service',[a.id,'44444444-4444-4444-8444-444444444444','Legacy service',null,1.12,null,'USD',null,true,null]);
await db.exec(await fs.readFile(new URL('../supabase/migrations/20261026040132_specialist_service_pricing_candidate.sql',import.meta.url),'utf8'));await buildPages();
const ctx=await browser.newContext();const keys={
 get_my_specialists:[],get_my_specialist_services:['p_specialist_id'],get_my_specialist_service_pricing:['p_specialist_id'],
 save_my_specialist_service:['p_specialist_id','p_service_id','p_name','p_description','p_price_from','p_price_to','p_currency','p_duration_minutes','p_is_active','p_version'],
 save_my_specialist_service_v2:['p_specialist_id','p_service_id','p_name','p_description','p_price_mode','p_price_unit','p_price_from','p_price_to','p_currency','p_duration_minutes','p_is_active','p_version'],
 delete_my_specialist_service:['p_specialist_id','p_service_id','p_version']
};
await ctx.route('**/*',async r=>{const u=new URL(r.request().url());
 if(u.hostname==='cdn.jsdelivr.net')return r.fulfill({contentType:'text/javascript',body:await fs.readFile(new URL('./browser-client-stub.js',import.meta.url),'utf8')});
 if(u.origin==='https://cabinet.test'&&/^\/account-[a-z-]+\.(html|js|css)$/.test(u.pathname))return r.fulfill({contentType:u.pathname.endsWith('.js')?'text/javascript':u.pathname.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(new URL('../_site'+u.pathname,import.meta.url),'utf8')});
 return r.abort();});
await ctx.exposeBinding('testSession',()=>user?{user:{id:user}}:null);
await ctx.exposeBinding('testRPC',async(_,name,args={})=>{calls.push({name,args});assert(keys[name],'Unexpected RPC '+name);if(missing&&name==='get_my_specialist_service_pricing')return{data:null,error:{code:'PGRST202',message:'Missing'}};
 if(fail==='offline'&&name==='save_my_specialist_service_v2')throw Error('offline');
 if(fail===true&&name==='save_my_specialist_service_v2')return{data:null,error:{code:'PGRST202',message:'Unavailable write'}};
 try{return{data:await db.call(user,name,keys[name].map(k=>args[k])),error:null};}catch(e){return{data:null,error:{code:e.code,message:e.message}};}});
const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
const open=()=>page.goto('https://cabinet.test/account-specialist-services.html?id='+a.id),ready=()=>page.locator('#fields:not([disabled])').waitFor();
const test=async(n,f)=>{await f();console.log('PASS PRICING UI',++count,n);};
const save=async()=>{await page.locator('#save').click();await page.locator('#status').filter({hasText:'Услуга сохранена'}).waitFor();};
try{
 await test('legacy edit preserves USD, missing unit and historical amount',async()=>{
  await open();await ready();await page.getByRole('button',{name:'Изменить',exact:true}).first().click();
  assert.equal(await page.locator('#currency').inputValue(),'USD');assert.equal(await page.locator('#price-unit').inputValue(),'');assert.equal(await page.locator('#price-mode').inputValue(),'priced');assert.equal(await page.locator('#price-from').inputValue(),'1.12');
  await page.locator('#description').fill('Only text changed');await save();
  const r=(await db.call(A,'get_my_specialist_services',[a.id])).find(x=>x.id===legacy.id);assert.equal(r.currency,'USD');assert.equal(r.price_from,1.12);assert.equal(r.price_unit,null);assert.equal(r.version,2);
 });
 await test('mode toggle retains unsaved amounts, range/blank errors focus exact fields',async()=>{
  await page.locator('#name').fill('Validation');await page.locator('#price-mode').selectOption('priced');await page.locator('#price-from').fill('9.50');
  await page.locator('#price-mode').selectOption('negotiated');await page.locator('#price-mode').selectOption('priced');assert.equal(await page.locator('#price-from').inputValue(),'9.50');
  await page.locator('#price-to').fill('2');await page.locator('#save').click();assert.equal(await page.locator('#price-to').getAttribute('aria-invalid'),'true');
  await page.locator('#price-from').fill('');await page.locator('#price-to').fill('');await page.locator('#save').click();assert.equal(await page.locator('#price-from').getAttribute('aria-invalid'),'true');
 });
 await test('negotiated/unit save and reopen, zero/exact, unspecified remain distinct',async()=>{
  await page.locator('#price-mode').selectOption('negotiated');await page.locator('#price-unit').selectOption('hour');await page.locator('#currency').selectOption('EUR');await save();
  assert((await page.locator('#items').textContent()).includes('По договорённости · за час'));
  await open();await ready();const card=page.locator('article').filter({hasText:'Validation'});await card.getByRole('button',{name:'Изменить',exact:true}).click();
  assert.equal(await page.locator('#price-mode').inputValue(),'negotiated');assert.equal(await page.locator('#currency').inputValue(),'EUR');assert.equal(await page.locator('#price-unit').inputValue(),'hour');
  await page.locator('#cancel').click();assert.equal(await page.locator('#currency').inputValue(),'RUB');
  await page.locator('#name').fill('<img src=x onerror=alert(1)>');await page.locator('#price-mode').selectOption('priced');await page.locator('#price-from').fill('0');await page.locator('#price-to').fill('0');await save();assert.equal(await page.locator('#items img').count(),0);assert((await page.locator('#items').textContent()).includes('0 RUB'));
  await page.locator('#name').fill('Unspecified');await save();assert((await page.locator('article').filter({hasText:'Unspecified'}).textContent()).includes('Цена не указана'));
 });
 await test('missing v2 write never falls back; offline retains form and choice',async()=>{
  await page.locator('#name').fill('Retained');await page.locator('#price-mode').selectOption('negotiated');await page.locator('#price-unit').selectOption('day');fail=true;const oldCalls=calls.filter(x=>x.name==='save_my_specialist_service').length;
  await page.locator('#save').click();await ready();assert.equal(await page.locator('#name').inputValue(),'Retained');assert.equal(await page.locator('#price-unit').inputValue(),'day');assert.equal(calls.filter(x=>x.name==='save_my_specialist_service').length,oldCalls);fail='offline';await page.locator('#save').click();await ready();assert.equal(await page.locator('#name').inputValue(),'Retained');assert.equal(calls.filter(x=>x.name==='save_my_specialist_service').length,oldCalls);fail=false;
 });
 await test('stale CAS gives error; explicit reload recovers without overwrite',async()=>{
  await page.locator('#cancel').click();await page.locator('article').filter({hasText:'Legacy service'}).getByRole('button',{name:'Изменить',exact:true}).click();
  const r=(await db.call(A,'get_my_specialist_services',[a.id])).find(x=>x.id===legacy.id);
  await db.call(A,'save_my_specialist_service',[a.id,r.id,r.name,'Other tab',r.price_from,r.price_to,r.currency,r.duration_minutes,r.is_active,r.version]);
  await page.locator('#description').fill('Stale');await page.locator('#save').click();await ready();assert.equal((await db.call(A,'get_my_specialist_services',[a.id])).find(x=>x.id===legacy.id).description,'Other tab');
  page.once('dialog',d=>d.accept());await page.locator('#reload-services').click();await ready();await page.locator('article').filter({hasText:'Legacy service'}).getByRole('button',{name:'Изменить',exact:true}).click();assert.equal(await page.locator('#description').inputValue(),'Other tab');
 });
 await test('320/390/1440 existing navigation, no overflow, screenshots',async()=>{
  for(const width of [320,390,1440]){await page.setViewportSize({width,height:900});assert.equal(await page.locator('.editor-nav a').count(),5);assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));}
  await page.setViewportSize({width:390,height:900});await page.screenshot({path:'C:/Users/Yumis/otzovik-stage2b-private/pricing-390.png',fullPage:true});
  await page.setViewportSize({width:1440,height:900});await page.screenshot({path:'C:/Users/Yumis/otzovik-stage2b-private/pricing-1440.png',fullPage:true});
 });
 await test('capability absent keeps legacy form; owner context fail closed',async()=>{
  missing=true;await open();await ready();assert(await page.locator('#price-mode').isDisabled());assert(await page.locator('#price-unit').isDisabled());assert(!(await page.locator('#price-from').isDisabled()));
  await page.locator('#name').fill('Legacy new');await page.locator('#price-from').fill('3');await save();assert(calls.some(x=>x.name==='save_my_specialist_service'));missing=false;
  user=B;const foreign=await ctx.newPage();await foreign.goto('https://cabinet.test/account-specialist-services.html?id='+a.id+'&check=foreign');await foreign.waitForTimeout(300);assert.equal(await foreign.locator('#fields').evaluate(e=>e.disabled),true);assert(await foreign.locator('#name').isDisabled());await foreign.close();assert.equal(errors.length,0);
 });
 console.log('PASS pricing browser groups',count);
}finally{await browser.close();await db.close();}
