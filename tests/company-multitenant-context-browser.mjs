import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
const A='4616c65b-5ebb-4c13-b2ef-24e2bc40d623',B='f1d3c93b-20e6-4a3c-9a54-36a947a55fb2',foreign='11111111-2222-4333-8444-555555555555';
const browser=await chromium.launch({headless:true,...(process.env.CI?{}:{channel:'msedge'})});
const cases=[
 {label:'explicit B overrides stored A',requested:B,stored:A,role:'owner',expected:B,access:true},
 {label:'invalid requested ID falls back to owned A',requested:'invalid-id',stored:B,role:'owner',expected:A,access:true},
 {label:'foreign requested ID falls back to owned A',requested:foreign,stored:B,role:'owner',expected:A,access:true},
 {label:'analyst B hides Access',requested:B,stored:A,role:'analyst',expected:B,access:false},
 {label:'signed out clears unverified context',requested:B,stored:A,role:'owner',expected:null,access:false,signedOut:true},
 {label:'RPC denial clears unverified context',requested:B,stored:A,role:'owner',expected:null,access:false,rpcError:true},
 {label:'zero memberships clears unverified context',requested:B,stored:A,role:'owner',expected:null,access:false,noCompanies:true},
 {label:'pending RPC does not propagate unverified company',requested:foreign,stored:A,role:'owner',expected:A,access:true,delayed:true},
 {label:'malformed RPC response clears unverified context',requested:foreign,stored:A,role:'owner',expected:null,access:false,malformed:true}
];
try{
 for(const t of cases){
  const context=await browser.newContext();
  await context.addInitScript(({stored})=>{localStorage.setItem('otzovik_active_company_id',stored);sessionStorage.setItem('otzovik_active_company_id',stored)},{stored:t.stored});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('https://company-context.test/**',async route=>{
   const p=new URL(route.request().url()).pathname;
   if(p==='/sdk.js'){
    const rows=[{company:{id:A,name:'Owned A'},membership:{role:'owner'}},{company:{id:B,name:'Owned B'},membership:{role:t.role}}];
    return route.fulfill({contentType:'text/javascript',body:`export function createClient(){return {auth:{getSession:async()=>({data:{session:${t.signedOut?'null':"{user:{id:'synthetic-owner'}}"}}})},rpc:async()=>{${t.delayed?"await new Promise(resolve=>setTimeout(resolve,1000));":''}return ({data:${t.malformed?"{unexpected:true}":t.noCompanies?'[]':JSON.stringify(rows)},error:${t.rpcError?"{message:'permission denied'}":'null'}})},from:()=>({select(){return this},eq(){return this},limit(){return this},maybeSingle:async()=>({data:null})})}}`});
   }
   if(p.endsWith('.js')){let data=await fs.readFile(new URL('..'+p,import.meta.url),'utf8');data=data.replace('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm','./sdk.js');return route.fulfill({contentType:'text/javascript',body:data});}
   return route.fulfill({contentType:'text/html; charset=utf-8',body:'<!doctype html><html lang="ru"><main><nav aria-label="Навигация кабинета"><a href="account-home.html">Все компании</a><a class="active" href="account-profile.html">Профиль</a><a href="account-billing.html">Тариф</a></nav></main><script type="module" src="account-company-context.js"></script></html>'});
  });
  await page.goto('https://company-context.test/account-profile.html?company_id='+encodeURIComponent(t.requested));
  if(t.delayed){const premature=await page.locator('nav a[href^="account-profile.html"]').getAttribute('href');assert.equal(new URL(premature,page.url()).searchParams.has('company_id'),false,'unverified company must not reach navigation while RPC pending');}
  if(t.signedOut||t.rpcError||t.noCompanies||t.malformed){await page.waitForFunction(()=>!localStorage.getItem('otzovik_active_company_id')&&!sessionStorage.getItem('otzovik_active_company_id'));assert.equal(new URL(page.url()).searchParams.has('company_id'),false);assert.equal(await page.locator('nav a[href^="account-access.html"]').count(),0);assert.deepEqual(errors,[],t.label);console.log('PASS',t.label);await context.close();continue;}
  await page.waitForFunction(expected=>document.querySelector('#active-company-name')?.textContent===expected,t.expected===B?'Owned B':'Owned A');
  const selected=await page.evaluate(()=>({url:new URL(location.href).searchParams.get('company_id'),local:localStorage.getItem('otzovik_active_company_id'),session:sessionStorage.getItem('otzovik_active_company_id')}));
  assert.deepEqual(selected,{url:t.expected,local:t.expected,session:t.expected},t.label);
  const access=page.locator('nav a[href^="account-access.html"]');
  if(t.access){
   await access.waitFor();
   assert.equal(await access.count(),1,t.label);
   assert.equal(new URL(await access.getAttribute('href'),page.url()).searchParams.get('company_id'),t.expected,t.label);
  }else{assert.equal(await access.count(),0,t.label);}
  assert.deepEqual(errors,[],t.label);
  console.log('PASS',t.label);
  await context.close();
 }
}finally{await browser.close();}
