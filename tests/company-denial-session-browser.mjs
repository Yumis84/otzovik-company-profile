import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
const A='4616c65b-5ebb-4c13-b2ef-24e2bc40d623',foreign='11111111-2222-4333-8444-555555555555';
const names=['qna','access','profile','branches','services','media','reviews','sources','analytics','notifications','ai-assistant','billing'];
const browser=await chromium.launch({headless:true,...(process.env.CI?{}:{channel:'msedge'})});
try{
 for(const name of names){
  const context=await browser.newContext();await context.addInitScript(id=>localStorage.setItem('otzovik_active_company_id',id),A);
  const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/*',async route=>{
   const url=new URL(route.request().url()),path=url.pathname;
   if(url.hostname==='cdn.jsdelivr.net'&&url.pathname.includes('supabase-js'))return route.fulfill({contentType:'text/javascript',body:`export function createClient(){return {auth:{getSession:async()=>({data:{session:window.__session}}),onAuthStateChange(cb){queueMicrotask(()=>cb('INITIAL_SESSION',window.__session));window.__authListeners.push(cb);return {data:{subscription:{unsubscribe(){}}}}}},rpc:async(name,args)=>{window.__rpcCalls.push({name,args});return {data:name==='get_my_companies'?[{company:{id:'${A}',name:'Owned A'},membership:{role:'owner',verification_status:'verified'}}]:null,error:null}},from:()=>({select(){return this},eq(){return this},limit(){return this},maybeSingle:async()=>({data:null})})}}`});
   if(url.hostname!=='company-context.test')return route.fulfill({status:404,body:''});
   let file=path.slice(1)||'account-home.html';if(file==='sdk.js')return route.fulfill({status:404});
   try{let body=await fs.readFile(new URL('../'+file,import.meta.url),'utf8');return route.fulfill({contentType:file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.css')?'text/css':'text/javascript',body});}catch{return route.fulfill({status:404})}
  });
  await page.addInitScript(()=>{window.__rpcCalls=[];window.__authListeners=[];window.__session={user:{id:'synthetic'},access_token:'x.'+btoa(JSON.stringify({sub:'synthetic',session_id:'session-A'}))+'.x'};window.__writes=[];const set=Storage.prototype.setItem;Storage.prototype.setItem=function(k,v){if(k==='otzovik_active_company_id')window.__writes.push(v);return set.call(this,k,v)}});
  await page.goto('https://company-context.test/account-'+name+'.html?company_id='+foreign,{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(1200);
  const data=await page.evaluate(()=>({calls:window.__rpcCalls,storage:localStorage.getItem('otzovik_active_company_id'),writes:window.__writes,url:location.href,body:document.body.innerText}));
  const privileged=data.calls.filter(x=>x.name!=='get_my_companies');
  assert.equal(privileged.length,0,`${name}: foreign explicit id must not trigger company RPC: ${JSON.stringify(privileged)}`);
  assert.equal(errors.length,0,`${name}: uncaught errors ${errors}`);
  assert.ok(data.calls.some(x=>x.name==='get_my_companies'),`${name}: no membership lookup`);
  assert.equal(new URL(data.url).searchParams.get('company_id'),foreign,`${name}: explicit URL changed`);
  assert.equal(data.writes.length,0,`${name}: unexpected company writes`);
  assert.ok(!data.body.includes('Owned A'),`${name}: foreign data visible`);
  console.log('PASS explicit foreign denied without company RPC',name);
  await context.close();
 }
}finally{await browser.close()}
