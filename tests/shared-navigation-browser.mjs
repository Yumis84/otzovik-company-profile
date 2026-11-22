import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {chromium} from 'playwright';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage();
await page.route('https://navigation.test/**',async route=>{
 const url=new URL(route.request().url());
 if(url.pathname==='/account-shared-navigation.js')return route.fulfill({contentType:'text/javascript',body:await fs.readFile(new URL('../account-shared-navigation.js',import.meta.url),'utf8')});
 return route.fulfill({contentType:'text/html; charset=utf-8',body:`<!doctype html><html lang="ru"><meta name="viewport" content="width=device-width,initial-scale=1"><style>*{box-sizing:border-box}body{margin:0;background:#f8fafc;font-family:system-ui}.wrap{width:min(1120px,calc(100% - 32px));margin:auto}main{padding:20px 0}nav a.active{background:#eaf2ff;color:#175cd3}</style><main class="wrap"><nav aria-label="Навигация кабинета"></nav><section id="content"><h1>Редактор</h1><input aria-label="Название"></section></main><script type="module">import{installNavigation}from '/account-shared-navigation.js';window.installNavigation=installNavigation;window.ready=true</script></html>`});
});
const kinds=[['company',['Мои компании','Профиль','Филиалы','Услуги','Фото','Отзывы','Вопросы и ответы','Источники рейтингов','Доступ','Тариф и оплата','AI-ассистент','Уведомления','Статистика']],['specialist',['Мои профили','Профиль','Услуги','Фото и портфолио','Контакты и работа']]];
async function setup(kind,labels){
 await page.goto('https://navigation.test/');
 await page.waitForFunction(()=>window.ready);
 await page.evaluate(({kind,labels})=>{
  const nav=document.querySelector('nav');nav.replaceChildren();
  labels.forEach((label,i)=>{const a=document.createElement('a');a.href='/'+kind+'-'+i+'?id=synthetic';a.textContent=label;if(i===labels.length-1){a.className='active';a.setAttribute('aria-current','page')}nav.append(a)});
  window.installNavigation(nav);
 },{kind,labels});
}
try{
 await fs.mkdir('navigation-screenshots',{recursive:true});
 for(const [kind,labels] of kinds){
  for(const width of [320,390,768,1280,1440]){
   await page.setViewportSize({width,height:900});
   await setup(kind,labels);
   const toggle=page.locator('.shared-nav-toggle');
   const nav=page.locator('.shared-nav-shell>nav');
   const menu=page.locator('.shared-nav-menu');
   assert.equal(await nav.locator('a').count(),labels.length);
   assert.equal(await nav.locator('[aria-current="page"]').count(),1);
   assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
   if(width>768){
    assert(await nav.isVisible());
    assert.equal(await toggle.isVisible(),false);
    assert(await page.locator('.shared-nav-shell').evaluate(el=>el.getBoundingClientRect().right<=document.querySelector('#content').getBoundingClientRect().left));
    assert.equal(await nav.evaluate(el=>getComputedStyle(el).flexDirection),'column');
    assert.equal(await nav.locator('a').last().getAttribute('href'),'/'+kind+'-'+(labels.length-1)+'?id=synthetic');
   }else{
    assert.equal(await nav.isVisible(),false);
    assert(await toggle.isVisible());
    await toggle.click();
    assert.equal(await toggle.getAttribute('aria-expanded'),'true');
    assert.equal(await menu.locator('a').count(),labels.length);
    assert.equal(await menu.locator('[aria-current="page"]').textContent(),labels.at(-1));
    await page.keyboard.press('Escape');
    assert.equal(await toggle.getAttribute('aria-expanded'),'false');
    assert(await toggle.evaluate(el=>document.activeElement===el));
    await toggle.click();
    await menu.getByRole('link',{name:labels.at(-1),exact:true}).click();
    await page.waitForURL(new RegExp('/'+kind+'-'));
   }
   await setup(kind,labels);
   await page.screenshot({path:`navigation-screenshots/${kind}-${width}.png`,fullPage:true});
  }
 }
 console.log('PASS shared sidebar: 2 kinds, 5 widths, active routes, keyboard Escape, mobile menu, desktop layout, no horizontal overflow');
}finally{await browser.close();}
