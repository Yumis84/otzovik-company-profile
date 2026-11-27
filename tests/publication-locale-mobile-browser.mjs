import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {chromium} from 'playwright';
const browser=await chromium.launch({headless:true,...(process.env.CI?{}:{channel:'msedge'})});
try{
 for(const width of [320,390,1280]){
  const context=await browser.newContext({viewport:{width,height:740}});const page=await context.newPage();
  await page.route('https://publication-ui.test/**',async route=>{
   const path=new URL(route.request().url()).pathname;
   if(path==='/publication-status-ui.mjs')return route.fulfill({contentType:'text/javascript',body:await fs.readFile(new URL('../publication-status-ui.mjs',import.meta.url),'utf8')});
   return route.fulfill({contentType:'text/html; charset=utf-8',body:`<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;padding:12px;font-family:Arial,sans-serif}#publication{overflow-wrap:anywhere}#publication a{display:inline-block;max-width:100%}</style><div id="publication" role="status"></div><script type="module">import{renderPublicationStatus}from'./publication-status-ui.mjs';const n=document.querySelector('#publication');renderPublicationStatus(n,{status:'queued',public_url:null});window.__queued=n.textContent;renderPublicationStatus(n,{status:'failed',public_url:null});window.__failed=n.textContent;renderPublicationStatus(n,{status:'published',public_url:null});window.__published=n.textContent;window.__done=true;</script></html>`});
  });
  await page.goto('https://publication-ui.test/');await page.waitForFunction(()=>window.__done===true);
  const result=await page.evaluate(()=>({queued:window.__queued,failed:window.__failed,published:window.__published,overflow:document.documentElement.scrollWidth>innerWidth,links:document.querySelectorAll('#publication a').length}));
  assert.match(result.queued,/\u043e\u0447\u0435\u0440\u0435\u0434\u0438/i);assert.match(result.failed,/\u041e\u0448\u0438\u0431\u043a\u0430/i);assert.match(result.published,/\u041e\u043f\u0443\u0431\u043b\u0438\u043a\u043e\u0432\u0430\u043d\u043e/i);assert.equal(result.links,0);assert.equal(result.overflow,false);
  console.log('PASS publication browser Russian locale/mobile',width);
  await context.close();
 }
}finally{await browser.close()}
