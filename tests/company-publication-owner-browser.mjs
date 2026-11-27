import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
const A='4616c65b-5ebb-4c13-b2ef-24e2bc40d623';
const browser=await chromium.launch({headless:true,...(process.env.CI?{}:{channel:'msedge'})});
try{
 for(const [width,role] of [[320,'owner'],[390,'owner'],[390,'admin'],[390,'manager'],[390,'analyst']]){
  const context=await browser.newContext({viewport:{width,height:740}});const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));await page.addInitScript(()=>{window.__calls=[];window.__requested=false});
  await page.route('**/*',async route=>{
   const url=new URL(route.request().url());
   if(url.hostname==='cdn.jsdelivr.net'&&url.pathname.includes('supabase-js'))return route.fulfill({contentType:'text/javascript',body:`export function createClient(){return {auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'},access_token:'x.'+btoa(JSON.stringify({sub:'synthetic',session_id:'A'}))+'.x'}}}),onAuthStateChange(cb){return {data:{subscription:{unsubscribe(){}}}}}},rpc:async(name,args)=>{window.__calls.push({name,args});if(name==='get_my_companies')return {data:[{company:{id:'${A}',name:'Owned A',slug:'owned-a'},membership:{role:'${role}',verification_status:'verified'}}]};if(name==='get_my_company_publication_status')return {data:{company_id:'${A}',status:window.__requested?'queued':'failed',public_url:null}};if(name==='request_my_company_publication'){window.__requested=true;return {data:'attempt-1'}};return {data:null,error:null}},from:()=>({select(){return this},eq(){return this},limit(){return this},maybeSingle:async()=>({data:null})})}}`});
   if(url.hostname!=='company-context.test')return route.fulfill({status:404});
   try{const file=url.pathname.slice(1)||'account-profile.html';const body=await fs.readFile(new URL('../'+file,import.meta.url),'utf8');return route.fulfill({contentType:file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.css')?'text/css':'text/javascript',body});}catch{return route.fulfill({status:404})}
  });
  await page.goto('https://company-context.test/account-profile.html?company_id='+A,{waitUntil:'domcontentloaded'});
  const button=page.locator('#publication-request');if(role!=='owner'){await page.waitForFunction(()=>window.__calls.some(x=>x.name==='get_my_companies'));await page.waitForTimeout(800);assert.ok(await button.isHidden()||await button.isDisabled());assert.equal(await page.evaluate(()=>window.__calls.filter(x=>x.name==='request_my_company_publication').length),0);assert.deepEqual(errors,[]);console.log('PASS publication denied',role);await context.close();continue;}await button.waitFor({state:'visible',timeout:12000});await page.waitForFunction(()=>!document.querySelector('#publication-request').disabled);
  await button.click();await page.waitForFunction(()=>window.__requested===true&&document.querySelector('#publication-state')?.textContent?.includes('\u043e\u0447\u0435\u0440\u0435\u0434\u0438'));
  const result=await page.evaluate(()=>({calls:window.__calls.filter(x=>x.name==='request_my_company_publication'),label:document.querySelector('#publication-state').textContent,overflow:document.documentElement.scrollWidth>innerWidth}));
  assert.equal(result.calls.length,1);assert.equal(result.calls[0].args.p_company_id,A);assert.match(result.calls[0].args.p_request_id,/^[0-9a-f-]{36}$/i);assert.equal(result.overflow,false);assert.deepEqual(errors,[]);
  console.log('PASS profile publication RPC click Russian mobile',width);
  await context.close();
 }
}finally{await browser.close()}
