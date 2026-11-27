import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { chromium } from 'playwright';
const source=await fs.readFile('staging/specialist/company-public-unavailable.html','utf8');
const browser=await chromium.launch({headless:true,...(process.env.CI?{}:{channel:'msedge'})});
try{
 for(const width of [320,390,1280]){
  const page=await browser.newPage({viewport:{width,height:800}});
  const requests=[];page.on('request',req=>requests.push(req.url()));
  await page.setContent(source);
  assert.match(await page.title(),/\u041f\u0443\u0431\u043b\u0438\u0447\u043d/);
  assert.match(await page.locator('h1').innerText(),/\u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u0435\u043d/);
  assert.equal(await page.locator('meta[name="robots"]').getAttribute('content'),'noindex,nofollow');
  assert.equal(await page.locator('a').getAttribute('href'),'account-home.html');
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.deepEqual(requests,[]);
  console.log('PASS browser unavailable page',width,'px, no network, no overflow');
  await page.close();
 }
}finally{await browser.close();}
