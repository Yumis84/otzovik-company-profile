import assert from 'node:assert/strict';import fs from 'node:fs/promises';import {chromium} from 'playwright';
const browser=await chromium.launch({headless:true}),context=await browser.newContext(),errors=[];
let role='owner';const id='33333333-3333-4333-8333-333333333333';
await context.route('**/*',async route=>{const url=new URL(route.request().url());if(url.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'text/javascript',body:await fs.readFile(new URL('./browser-client-stub.js',import.meta.url),'utf8')});if(url.origin==='https://cabinet.test'&&/^\/account-[a-z-]+\.(html|js|css)$/.test(url.pathname)){const path=new URL('..'+url.pathname,import.meta.url);try{return route.fulfill({contentType:url.pathname.endsWith('.js')?'text/javascript':url.pathname.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(path,'utf8')});}catch{return route.abort();}}return route.abort();});
await context.exposeBinding('testSession',()=>({user:{id:'11111111-1111-4111-8111-111111111111'}}));
await context.exposeBinding('testRPC',(_,name)=>name==='get_my_companies'?{data:[{company:{id,name:'Тестовая компания',slug:'test-company',city:'Калининград'},membership:{role}}],error:null}:{data:null,error:null});await context.exposeBinding('testTable',()=>({data:null,error:null}));
const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));await fs.mkdir('navigation-screenshots',{recursive:true});
try{
 for(role of ['owner','admin','analyst'])for(const width of [320,390,768,1440]){
  await page.setViewportSize({width,height:900});await page.goto('https://cabinet.test/account-profile.html?company_id='+id);await page.locator('#active-company-name').filter({hasText:'Тестовая компания'}).waitFor();
  assert.equal(await page.locator('.shared-nav-shell').count(),1);assert.equal(await page.getByRole('button',{name:'☰ Меню'}).count(),1);
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),role+' '+width+' profile overflow');
  const toggle=page.getByRole('button',{name:'☰ Меню'});await toggle.click();const menu=page.locator('.shared-nav-menu');const tabHrefs=await page.locator('main nav a').evaluateAll(xs=>xs.map(x=>x.href));const menuHrefs=await menu.locator('a').evaluateAll(xs=>xs.map(x=>x.href));assert.deepEqual(menuHrefs,tabHrefs);
  assert.equal(menuHrefs.some(x=>x.includes('account-access.html')),role==='owner');assert.equal(menuHrefs.some(x=>x.includes('account-billing.html')),role==='owner');
  if(role==='owner')await page.screenshot({path:`navigation-screenshots/company-real-${width}.png`,fullPage:true});
  await page.keyboard.press('Escape');assert.equal(await toggle.getAttribute('aria-expanded'),'false');assert(await toggle.evaluate(e=>document.activeElement===e));
 }
 assert.deepEqual(errors,[]);console.log('PASS company real HTML: owner/admin/analyst simulated Auth and role responses; 4 widths, menu/ARIA, no horizontal overflow');
}finally{await context.close();await browser.close();}
