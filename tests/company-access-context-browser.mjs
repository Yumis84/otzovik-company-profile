import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {chromium} from 'playwright';
const id='4616c65b-5ebb-4c13-b2ef-24e2bc40d623';
const browser=await chromium.launch({headless:true,channel:'msedge'}),page=await browser.newPage();
const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.route('https://company-context.test/**',async route=>{
 const p=new URL(route.request().url()).pathname;
 if(p==='/sdk.js')return route.fulfill({contentType:'text/javascript',body:`export function createClient(){return {auth:{getSession:async()=>({data:{session:{user:{id:'synthetic-owner'}}}})},rpc:async()=>({data:[{company:{id:'${id}',name:'Synthetic Company'},membership:{role:'owner'}}]}),from:()=>({select(){return this},eq(){return this},limit(){return this},maybeSingle:async()=>({data:null})})}}`});
 if(p.endsWith('.js')){let data=await fs.readFile(new URL('..'+p,import.meta.url),'utf8');data=data.replace('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm','./sdk.js');return route.fulfill({contentType:'text/javascript',body:data});}
 return route.fulfill({contentType:'text/html; charset=utf-8',body:'<!doctype html><html lang="ru"><main><nav aria-label="Навигация кабинета"><a href="account-home.html">Мои компании</a><a class="active" href="account-profile.html">Профиль</a><a href="account-billing.html">Тариф</a></nav></main><script type="module" src="account-company-context.js"></script></html>'});
});
try{
 await page.goto('https://company-context.test/account-profile.html?company_id='+id);
 const access=page.locator('nav a[href^="account-access.html"]');await access.waitFor();
 await page.waitForFunction(()=>document.querySelector('a[href^="account-access.html"]')?.getAttribute('href')?.includes('company_id='));
 assert.equal(new URL(await access.getAttribute('href'),'https://company-context.test').searchParams.get('company_id'),id);
 assert.deepEqual(errors,[]);console.log('PASS MOCK browser: owner Access link added after RPC retains explicit company_id; real source/navigation, mocked Auth/RPC only');
}finally{await browser.close();}
