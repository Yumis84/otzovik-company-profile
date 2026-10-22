import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
const root=new URL('../',import.meta.url);
const browser=await chromium.launch({...(process.env.TEST_BROWSER_CHANNEL?{channel:process.env.TEST_BROWSER_CHANNEL}:{}),headless:true});
let rows=[],calls=[],user=true,fail=null;
const id='12345678-1234-4234-8234-123456789012';
const context=await browser.newContext();
await context.route('**/*',async route=>{
 const u=new URL(route.request().url());
 if(u.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'text/javascript',body:`export const createClient=()=>({auth:{getSession:async()=>({data:{session:await window.session()}})},rpc:(n,a)=>window.rpc(n,a)});`});
 if(u.origin==='http://cabinet.test'){
  try{return route.fulfill({contentType:u.pathname.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(new URL('.'+u.pathname,root),'utf8')})}catch{return route.fulfill({status:404,body:''})}
 }
 return route.abort();
});
await context.exposeBinding('session',()=>user?{user:{id:'owner'}}:null);
await context.exposeBinding('rpc',(_,name,args)=>{
 calls.push({name,args});
 assert(['get_my_specialists','create_my_specialist_draft','update_my_specialist_draft'].includes(name));
 if(fail===name)return {data:null,error:{code:'PGRST202'}};
 if(name==='get_my_specialists')return {data:rows,error:null};
 const item={id,profile_status:'draft',...Object.fromEntries(Object.entries(args).filter(([k])=>k!=='p_id').map(([k,v])=>[k.slice(2),v]))};
 if(name==='create_my_specialist_draft')rows.push(item);else rows[0]={...rows[0],...item};
 return {data:rows[0],error:null};
});
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
const open=q=>page.goto('http://cabinet.test/account-create-specialist.html'+(q||''));
const ready=()=>page.locator('#save:not([disabled])').waitFor();
try{
 for(const width of [320,390,1280]){
 await page.setViewportSize({width,height:900});await open();await ready();
 assert.equal(await page.locator('nav a').count(),2);
 assert.equal(await page.getByText('Все разделы',{exact:true}).count(),0);
 assert(await page.evaluate(()=>[...document.querySelectorAll('input,textarea,button')].every(e=>e.getBoundingClientRect().right<=innerWidth)));
 console.log('PASS layout',width);
 }
 await page.locator('[name=display_name]').fill('Test Specialist');
 await page.locator('[name=slug]').fill('test-specialist');
 await page.locator('[name=profession]').fill('Photographer');
 await page.locator('[name=description]').fill('<img src=x onerror=alert(1)>');
 await page.locator('#save').click();await page.waitForURL('**/account-home.html');
 assert.equal(rows.length,1);assert.equal(calls.at(-1).name,'create_my_specialist_draft');console.log('PASS create and return to list');
 await open('?id='+id);await ready();assert.equal(await page.locator('[name=slug]').getAttribute('readonly'),'');
 assert.equal(await page.locator('[name=description]').inputValue(),'<img src=x onerror=alert(1)>');
 await page.locator('[name=description]').fill('Saved revision');
 await page.locator('#save').click();await page.waitForURL('**/account-home.html');
 await open('?id='+id);await ready();assert.equal(await page.locator('[name=description]').inputValue(),'Saved revision');
 assert.equal(rows.length,1);console.log('PASS update and reopen; literal HTML; no duplicate');
 fail='get_my_specialists';await page.reload();await page.getByText('Не удалось загрузить черновик.',{exact:false}).waitFor();assert(await page.locator('#save').isDisabled());fail=null;
 await open('?id=invalid');await page.getByText('Некорректная ссылка на черновик.').waitFor();assert(await page.locator('#save').isDisabled());
 rows=[];await open('?id='+id);await page.getByText('Черновик не найден или недоступен.').waitFor();assert(await page.locator('#save').isDisabled());
 user=false;calls=[];await open('?id='+id);await page.waitForURL('**/account-login.html?*');assert.equal(calls.length,0);
 assert.equal(new URL(page.url()).searchParams.get('next'),'account-create-specialist.html?id='+id);
 assert.deepEqual(errors,[]);console.log('PASS missing RPC, malformed/foreign id, auth redirect; no external traffic; RPC contract mocks only');
}finally{await browser.close()}
