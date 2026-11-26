import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {chromium} from 'playwright';
const base='https://specialist-test.invalid',origin='https://salmcnhexlftrgtiryyo.supabase.co';
const id='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222';
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64');
const browser=await chromium.launch({headless:true,...(process.platform==='win32'?{channel:'msedge'}:{})});
let unavailable=false;
const data={display_name:'Тест специалиста '+('Ж'.repeat(100)),profession:'Консультант',specialization:'Тестовая специализация',city:'Калининград',description:'Публичное описание',items:[{type:'service',name:'Консультация',description:'Описание',from:1200,currency:'RUB'},{type:'contact',label:'Связаться '+('x'.repeat(150)),href:'mailto:public@example.invalid'},{type:'photo',id,kind:'avatar'},{type:'photo',id:other,kind:'portfolio',caption:'Работа специалиста'}]};
const context=await browser.newContext();const errors=[];
await context.route('**/*',async route=>{
 const url=new URL(route.request().url());
 if(url.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'text/javascript',body:'export const createClient=()=>({rpc:async()=>({data:'+JSON.stringify(data)+'})});'});
 if(url.origin===origin){assert.equal(route.request().method(),'POST');assert(url.searchParams.get('photo'));assert(route.request().headers().authorization.startsWith('Bearer eyJ'));return route.fulfill(unavailable?{status:404,body:'Photo unavailable'}:{contentType:'image/png',body:png});}
 if(url.origin!==base)return route.abort();
 const name=url.pathname.slice(1);if(!['specialist-public.html','specialist-public.js','specialist-public-media.js','specialist-public.css','profile.css'].includes(name))return route.abort();
 return route.fulfill({contentType:name.endsWith('.js')?'text/javascript':name.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(name)});
});
const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
try{
 for(const width of [320,390,768,1280,1440]){
  await page.setViewportSize({width,height:1000});await page.goto(base+'/specialist-public.html?slug=test-profile');
  await page.locator('#portfolio img').waitFor();assert.equal(await page.locator('#avatar img').count(),1);
  assert.equal(await page.locator('#specialization').textContent(),data.specialization);
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'overflow at '+width);
  assert(!(await page.locator('body').innerText()).includes('private@example.invalid'));
  console.log('PASS MOCK public desktop/mobile width',width,'photos decoded, selected data, overflow=0');
 }
 unavailable=true;await page.reload();await page.getByRole('status').filter({hasText:'Некоторые опубликованные фотографии'}).waitFor();
 assert.equal(await page.locator('#avatar img').count(),0);assert.equal(await page.locator('#media').isVisible(),false);assert.equal(await page.locator('img').count(),0);assert.deepEqual(errors,[]);
 console.log('PASS MOCK public photo404: fallback, hidden empty gallery, no broken images/page errors');
}finally{await browser.close();}
