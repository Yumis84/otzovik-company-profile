import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {chromium} from 'playwright';
import {database,A,B} from './database.mjs';
const db=await database();
const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,args:['--no-sandbox','--disable-dev-shm-usage']});
let user=A,failRPC=null,throwRPC=null,calls=[],slowRPC=null;
const context=await browser.newContext();
await context.route('**/*',async route=>{
 const url=new URL(route.request().url());
 if(url.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'text/javascript',body:`export const createClient=()=>({auth:{getSession:async()=>({data:{session:await window.testSession()}}),signInWithPassword:async()=>({error:null}),signOut:async()=>({error:null})},rpc:async(name,args)=>window.testRPC(name,args)});`});
 if(url.origin==='http://cabinet.test'){
  if(!/^\/account-[a-z-]+\.html$/.test(url.pathname))return route.fulfill({status:404,body:''});
  return route.fulfill({contentType:'text/html',body:await fs.readFile(new URL('..'+url.pathname,import.meta.url),'utf8')});
 }
 return route.abort(); // No production traffic possible.
});
await context.exposeBinding('testSession',()=>user?{user:{id:user,email:'test@example.invalid'}}:null);
await context.exposeBinding('testRPC',async(_,name,args={})=>{
 calls.push({name,args});
 if(slowRPC===name)await new Promise(r=>setTimeout(r,250));
 if(throwRPC===name)throw new Error('Simulated offline');
 if(failRPC===name)return {data:null,error:{code:'PGRST202',message:'Not installed'}};
 if(name==='get_my_pending_company_invitations')return {data:[],error:null};
 const names={create_my_specialist_draft:['p_display_name','p_slug','p_profession','p_specialization','p_city','p_description'],update_my_specialist_draft:['p_id','p_display_name','p_profession','p_specialization','p_city','p_description'],create_my_company:['p_name','p_slug','p_website','p_phone','p_city','p_email'],get_my_companies:[],get_my_specialists:[]}[name];
 assert(names,'Unexpected RPC '+name);assert.deepEqual(Object.keys(args).sort(),[...names].sort());
 try{return {data:await db.call(user,name,names.map(n=>args[n])),error:null};}catch(e){return {data:null,error:{code:e.code,message:e.message}};}
});
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
const open=path=>page.goto('http://cabinet.test/'+path);
const note=()=>page.locator('#save-note');
const waitReady=()=>page.locator('#save:not([disabled])').waitFor();
let count=0;const test=async(name,fn)=>{await fn();console.log('PASS browser',++count,name);};
try{
let id;
await test('mobile chooser → actual create RPC → dashboard → load → update → reload',async()=>{
 await page.setViewportSize({width:390,height:844});
 await open('account-create-profile.html');await page.getByRole('link',{name:/Индивидуальный специалист/}).click();await waitReady();
 await page.locator('[name=display_name]').fill('Иван Мастер');await page.locator('[name=slug]').fill('ivan-master');await page.locator('[name=profession]').fill('Фотограф');await page.locator('[name=specialization]').fill('Портреты');await page.locator('[name=city]').fill('Калининград');await page.locator('[name=description]').fill('Описание <img src=x onerror=alert(1)>');
 assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.locator('#save').click();await page.waitForURL('**/account-home.html');await page.getByText('Иван Мастер',{exact:true}).waitFor();
 const [item]=await db.call(A,'get_my_specialists');id=item.id;assert.equal(item.description,'Описание <img src=x onerror=alert(1)>');
 await page.getByRole('link',{name:/Редактировать специалиста/}).click();await waitReady();
 assert.equal(await page.locator('[name=slug]').getAttribute('readonly'),'');assert.equal(await page.locator('[name=description]').inputValue(),item.description);
 await page.locator('[name=display_name]').fill('Иван Обновлённый');await page.locator('[name=description]').fill('Новое описание');await page.locator('#save').click();await page.waitForURL('**/account-home.html');await page.getByText('Иван Обновлённый',{exact:true}).waitFor();await page.reload();await page.getByRole('link',{name:/Редактировать специалиста/}).click();await waitReady();assert.equal(await page.locator('[name=description]').inputValue(),'Новое описание');
});
await test('unauthenticated edit preserves id through login; no data RPC before auth',async()=>{
 user=null;calls=[];await open('account-create-specialist.html?id='+id);await page.waitForURL('**/account-login.html?*');
 assert.equal(new URL(page.url()).searchParams.get('next'),'account-create-specialist.html?id='+id);assert.equal(calls.length,0);
 user=A;await page.reload();await page.waitForURL('**/account-create-specialist.html?id='+id);await waitReady();
});
await test('specialist-only user login lands in cabinet',async()=>{
 await open('account-login.html');await page.waitForURL('**/account-home.html');await page.getByText('Иван Обновлённый',{exact:true}).waitFor();
});
await test('foreign profile and malformed id fail closed',async()=>{
 user=B;await open('account-create-specialist.html?id='+id);await note().filter({hasText:'недоступен'}).waitFor();assert(await page.locator('#save').isDisabled());assert.equal(await page.locator('[name=display_name]').inputValue(),'');
 for(const invalid of ['','not-a-uuid']){calls=[];await open('account-create-specialist.html?id='+invalid);await note().filter({hasText:'Некорректная'}).waitFor();assert(await page.locator('#save').isDisabled());assert.equal(calls.length,0);}
 user=A;
});
await test('missing RPC, rejected network, retry and duplicate address are visible',async()=>{
 await open('account-create-specialist.html');await waitReady();await page.locator('[name=display_name]').fill('Другой Мастер');await page.locator('[name=slug]').fill('ivan-master');await page.locator('[name=profession]').fill('Мастер');await page.locator('#save').click();await note().filter({hasText:'Адрес уже занят'}).waitFor();assert(await page.locator('#save').isEnabled());
 await page.locator('[name=slug]').fill('retry-master');failRPC='create_my_specialist_draft';await page.locator('#save').click();await note().filter({hasText:'временно недоступно'}).waitFor();assert(await page.locator('#save').isEnabled());failRPC=null;
 throwRPC='create_my_specialist_draft';await page.locator('#save').click();await note().filter({hasText:'Не удалось подтвердить'}).waitFor();throwRPC=null;assert(await page.locator('#save').isEnabled());
 slowRPC='create_my_specialist_draft';calls=[];await page.evaluate(()=>{const f=document.querySelector('form');f.dispatchEvent(new Event('submit',{cancelable:true}));f.dispatchEvent(new Event('submit',{cancelable:true}));});await page.waitForURL('**/account-home.html');assert.equal(calls.filter(x=>x.name==='create_my_specialist_draft').length,1);slowRPC=null;
});
await test('dashboard read errors are not shown as empty profiles; company failure does not hide specialist',async()=>{
 failRPC='get_my_companies';await open('account-home.html');await page.locator('#status').filter({hasText:'Не удалось загрузить компании'}).waitFor();await page.getByText('Иван Обновлённый',{exact:true}).waitFor();
 failRPC='get_my_specialists';await open('account-home.html');await page.locator('#status').filter({hasText:'Не удалось загрузить специалистов'}).waitFor();assert.equal(await page.getByText('Пока нет профилей').count(),0);failRPC=null;
});
await test('failed edit load disables all fields and cannot overwrite draft',async()=>{
 failRPC='get_my_specialists';await open('account-create-specialist.html?id='+id);await note().filter({hasText:'Не удалось загрузить'}).waitFor();assert(await page.locator('#save').isDisabled());assert(await page.locator('[name=display_name]').isDisabled());failRPC=null;
});
await test('existing company form creates company through exact RPC, then displays in cabinet',async()=>{
 await page.setViewportSize({width:1280,height:900});await open('account-create-company.html');await page.locator('#name').fill('New Company');await page.locator('#slug').fill('new-company');await page.locator('#submit').click();await page.waitForURL('**/account-home.html');await page.getByText('New Company',{exact:true}).waitFor();
 const [company]=await db.call(A,'get_my_companies');assert.equal(company.company.website,company.company.public_url);
 await page.getByText('Иван Обновлённый',{exact:true}).waitFor();assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
});
assert.deepEqual(errors,[]);console.log(`PASS ${count} browser groups; all external requests blocked; SQL-backed RPC adapter (not hosted Auth/PostgREST)`);
}finally{await browser.close();await db.close();}
