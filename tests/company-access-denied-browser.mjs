import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
const company='4616c65b-5ebb-4c13-b2ef-24e2bc40d623';
const browser=await chromium.launch({headless:true,...(process.env.CI?{}:{channel:'msedge'})});
try{
 for(const role of ['analyst','owner']){
  const context=await browser.newContext();
  const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('https://company-context.test/**',async route=>{
   const path=new URL(route.request().url()).pathname;
   if(path==='/sdk.js')return route.fulfill({contentType:'text/javascript',body:`export function createClient(){return {auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'}}}})},rpc:async(name)=>({data:name==='get_my_companies'?[{company:{id:'${company}',name:'Synthetic'},membership:{role:'${role}'}}]:{members:[],invitations:[]},error:null}),from:()=>({select(){return this},eq(){return this},limit(){return this},maybeSingle:async()=>({data:null})})}}`});
   const file=path.slice(1);if(!file.startsWith('account-'))return route.fulfill({status:404});
   let data=await fs.readFile(new URL('../'+file,import.meta.url),'utf8');
   if(file.endsWith('.html'))data=data.replaceAll('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm','./sdk.js');
   if(file.endsWith('.js'))data=data.replaceAll('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm','./sdk.js');
   return route.fulfill({contentType:file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.css')?'text/css':'text/javascript',body:data});
  });
  await page.goto('https://company-context.test/account-access.html?company_id='+company);
  await page.waitForFunction(role=>role==='analyst'?!document.getElementById('access-denied')?.hidden:!document.getElementById('owner-ui')?.hidden,role);
  assert.equal(await page.locator('#owner-ui').isVisible(),role==='owner');
  assert.equal(await page.locator('#access-denied').isVisible(),role==='analyst');
  assert.deepEqual(errors,[],role);await context.close();console.log('PASS access state',role);
 }
}finally{await browser.close()}
