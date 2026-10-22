import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {chromium} from 'playwright';
import {database,A,B} from './database.mjs';
import {buildPages} from '../scripts/build-pages.mjs';
await buildPages();
const db=await database({editor:true});
const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,args:['--no-sandbox','--disable-dev-shm-usage']});
let user=A,failRPC=null,throwRPC=null,calls=[],slowRPC=null,authMode='confirm',authFail=false,authCalls=[];
const records={locations:[],services:[],media:[]};
const context=await browser.newContext();
await context.route('**/*',async route=>{
 const url=new URL(route.request().url());
 if(url.hostname==='cdn.jsdelivr.net')return route.fulfill({contentType:'text/javascript',body:await fs.readFile(new URL('./browser-client-stub.js',import.meta.url),'utf8')});
 if(url.origin==='https://cabinet.test'){
  if(/^\/account-[a-z-]+$/.test(url.pathname))url.pathname+='.html';
  if(!/^\/account-[a-z-]+\.(html|js|css)$/.test(url.pathname))return route.fulfill({status:404,body:''});
  return route.fulfill({contentType:url.pathname.endsWith('.js')?'text/javascript':url.pathname.endsWith('.css')?'text/css':'text/html',body:await fs.readFile(new URL('../_site'+url.pathname,import.meta.url),'utf8')});
 }
 return route.abort(); // No production traffic possible.
});
await context.exposeBinding('testSession',()=>user?{user:{id:user,email:'test@example.invalid'}}:null);
await context.exposeBinding('testAuth',async(_,name,args)=>{
 authCalls.push({name,args});if(authFail)throw new Error('Offline');
 if(name==='logout'){user=null;return {error:null};}
 if(name==='login'||authMode==='immediate')user=B;
 return {data:{session:user?{user:{id:user}}:null},error:null};
});
await context.exposeBinding('testTable',async(_,q)=>{
 assert.equal(q.table,'company_media');
 const allowed=(await db.call(user,'get_my_companies')).map(x=>x.company.id);
 let data=records.media.filter(x=>allowed.includes(x.company_id)&&q.filters.every(([k,v])=>x[k]===v));
 return {data:q.single?(data[0]||null):data,error:null};
});
await context.exposeBinding('testRPC',async(_,name,args={})=>{
 calls.push({name,args});
 if(slowRPC===name)await new Promise(r=>setTimeout(r,250));
 if(throwRPC===name)throw new Error('Simulated offline');
 if(failRPC===name)return {data:null,error:{code:'PGRST202',message:'Not installed'}};
 if(name==='get_my_pending_company_invitations')return {data:[],error:null};
 if(name==='get_my_company_review_sources')return {data:[],error:null};
 if(name==='get_my_company_client_content')return {data:{review_statements:[],questions_answers:[]},error:null};
 // Unchanged company subsystem RPCs use a contract stub, not a claim of backend acceptance.
 if(name==='get_my_company_publication_status')return {data:{status:'unknown'},error:null};
 if(name==='get_public_company_profile_v2')return {data:{locations:[],services:[]},error:null};
 if(['get_my_company_locations','create_my_company_location','get_my_company_services','create_my_company_service','get_my_company_access','register_my_company_media'].includes(name)){
  const row=(await db.call(user,'get_my_companies')).find(x=>x.company.id===args.p_company_id);
  if(!row)return {data:null,error:{code:'42501',message:'access_denied'}};
  if(name==='get_my_company_access')return {data:{members:[{user_id:user,email:'test@example.invalid',role:row.membership.role,verification_status:'verified'}],invitations:[]},error:null};
  const kind=name.includes('location')?'locations':name.includes('service')?'services':'media';
  if(name.startsWith('get_'))return {data:records[kind].filter(x=>x.company_id===args.p_company_id),error:null};
  const record={id:crypto.randomUUID(),company_id:args.p_company_id,status:'published',...Object.fromEntries(Object.entries(args).map(([k,v])=>[k.replace(/^p_/,''),v]))};records[kind].push(record);return {data:record,error:null};
 }
 if(name==='get_my_specialist_media')return {data:null,error:{code:'PGRST202',message:'Not installed'}};
 const editorNames={get_my_specialist_services:['p_specialist_id'],save_my_specialist_service:['p_specialist_id','p_service_id','p_name','p_description','p_price_from','p_price_to','p_currency','p_duration_minutes','p_is_active','p_version'],delete_my_specialist_service:['p_specialist_id','p_service_id','p_version'],get_my_specialist_settings:['p_specialist_id'],save_my_specialist_settings:['p_specialist_id','p_phone','p_email','p_website','p_work_formats','p_service_area','p_qualifications','p_version']};
 if(editorNames[name]){try{return {data:await db.call(user,name,editorNames[name].map(n=>args[n]??null)),error:null};}catch(e){return {data:null,error:{code:e.code,message:e.message}};}}
 const names={update_my_company_profile:['p_company_id','p_name','p_description','p_website','p_phone','p_city','p_email'],create_my_specialist_draft:['p_display_name','p_slug','p_profession','p_specialization','p_city','p_description'],update_my_specialist_draft:['p_id','p_display_name','p_profession','p_specialization','p_city','p_description'],create_my_company:['p_name','p_slug','p_website','p_phone','p_city','p_email'],get_my_companies:[],get_my_specialists:[]}[name];
 assert(names,'Unexpected RPC '+name);assert.deepEqual(Object.keys(args).sort(),[...names].sort());
 try{return {data:await db.call(user,name,names.map(n=>args[n])),error:null};}catch(e){return {data:null,error:{code:e.code,message:e.message}};}
});
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
const open=path=>page.goto('https://cabinet.test/'+path);
const note=()=>page.locator('#save-note');
const waitReady=()=>page.locator('#save:not([disabled])').waitFor();
let count=0;const test=async(name,fn)=>{await fn();console.log('PASS browser',++count,name);};
try{
let id;
await test('registration confirmation → login → chooser; empty account; login network retry',async()=>{
 user=null;await open('account-login.html');await page.locator('#signupTab').click();
 await page.locator('#email').fill('new@example.invalid');await page.locator('#password').fill('acceptance-password');await page.locator('#submit').click();await page.locator('#status').filter({hasText:'Проверьте почту'}).waitFor();
 const redirect=authCalls.at(-1).args.options.emailRedirectTo;
 assert.equal(new URL(redirect).searchParams.get('next'),'account-create-profile.html');
 await page.goto(redirect);await page.locator('#email').fill('new@example.invalid');await page.locator('#password').fill('acceptance-password');
 authFail=true;await page.locator('#submit').click();await page.locator('#status').filter({hasText:'Проверьте соединение'}).waitFor();assert(await page.locator('#submit').isEnabled());authFail=false;
 await page.locator('#submit').click();await page.waitForURL('**/account-create-profile.html');
 await open('account-home.html');await page.getByText('Пока нет профилей',{exact:true}).waitFor();
 user=null;authMode='immediate';await open('account-login.html');await page.locator('#signupTab').click();await page.locator('#email').fill('immediate@example.invalid');await page.locator('#password').fill('acceptance-password');await page.locator('#submit').click();await page.waitForURL('**/account-create-profile.html');authMode='confirm';user=A;
});
await test('mobile chooser → actual create RPC → dashboard → load → update → reload',async()=>{
 await page.setViewportSize({width:390,height:844});
 await open('account-create-profile.html');assert.equal(await page.locator('.type-icon svg').count(),2);assert.equal(await page.getByRole('link',{name:/Создать компанию/}).count(),1);await page.getByRole('link',{name:/Создать компанию/}).click();await page.waitForURL('**/account-create-company.html');await page.locator('#name').waitFor();await open('account-create-profile.html');await page.getByRole('link',{name:/Индивидуальный специалист/}).click();await waitReady();
 await page.locator('[name=display_name]').fill('Иван Мастер');await page.locator('[name=slug]').fill('ivan-master');await page.locator('[name=profession]').fill('Фотограф');await page.locator('[name=specialization]').fill('Портреты');await page.locator('[name=city]').fill('Калининград');await page.locator('[name=description]').fill('Описание <img src=x onerror=alert(1)>');
 assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.locator('#save').click();await page.waitForURL('**/account-specialist-profile.html?id=*');await open('account-home.html');await page.getByText('Иван Мастер',{exact:true}).waitFor(); assert.equal(await page.locator('.specialist-card .specialist-avatar svg').count(),1); assert.equal(await page.locator('.specialist-card .company-avatar').count(),0);
 const [item]=await db.call(A,'get_my_specialists');id=item.id;assert.equal(item.description,'Описание <img src=x onerror=alert(1)>');
 await page.getByRole('link',{name:/Редактировать специалиста/}).click();await waitReady();
 assert.equal(await page.locator('[name=slug]').getAttribute('readonly'),'');assert.equal(await page.locator('[name=description]').inputValue(),item.description);
 await page.locator('[name=display_name]').fill('Иван Обновлённый');await page.locator('[name=description]').fill('Новое описание');await page.locator('#save').click();await note().filter({hasText:'Изменения сохранены'}).waitFor();await open('account-home.html');await page.getByText('Иван Обновлённый',{exact:true}).waitFor(); assert.equal(await page.locator('.specialist-card .specialist-avatar svg').count(),1);await page.reload();await page.getByRole('link',{name:/Редактировать специалиста/}).click();await waitReady();assert.equal(await page.locator('[name=description]').inputValue(),'Новое описание');
});
await test('unauthenticated edit preserves id through login; no data RPC before auth',async()=>{
 user=null;calls=[];await open('account-specialist-profile.html?id='+id);await page.waitForURL('**/account-login.html?*');
 assert.equal(new URL(page.url()).searchParams.get('next'),'account-specialist-profile.html?id='+id);assert.equal(calls.length,0);
 user=A;await page.reload();await page.waitForURL('**/account-specialist-profile.html?id='+id);await waitReady();
});
await test('specialist-only user login lands in cabinet',async()=>{
 await open('account-login.html');await page.waitForURL('**/account-home.html');await page.getByText('Иван Обновлённый',{exact:true}).waitFor();
});
await test('foreign profile and malformed id fail closed',async()=>{
 user=B;await open('account-specialist-profile.html?id='+id);await note().filter({hasText:'недоступен'}).waitFor();assert(await page.locator('#save').isDisabled());assert.equal(await page.locator('[name=display_name]').inputValue(),'');
 for(const invalid of ['','not-a-uuid']){calls=[];await open('account-specialist-profile.html?id='+invalid);await note().filter({hasText:'Некорректная'}).waitFor();assert(await page.locator('#save').isDisabled());assert.equal(calls.length,0);}
 user=A;
});
await test('missing RPC, rejected network, retry and duplicate address are visible',async()=>{
 await open('account-create-specialist.html');await waitReady();await page.locator('[name=display_name]').fill('Другой Мастер');await page.locator('[name=slug]').fill('ivan-master');await page.locator('[name=profession]').fill('Мастер');await page.locator('#save').click();await note().filter({hasText:'Адрес уже занят'}).waitFor();assert(await page.locator('#save').isEnabled());
 await page.locator('[name=slug]').fill('retry-master');failRPC='create_my_specialist_draft';await page.locator('#save').click();await note().filter({hasText:'временно недоступно'}).waitFor();assert(await page.locator('#save').isEnabled());failRPC=null;
 throwRPC='create_my_specialist_draft';await page.locator('#save').click();await note().filter({hasText:'Не удалось подтвердить'}).waitFor();throwRPC=null;assert(await page.locator('#save').isEnabled());
 slowRPC='create_my_specialist_draft';calls=[];await page.evaluate(()=>{const f=document.querySelector('form');f.dispatchEvent(new Event('submit',{cancelable:true}));f.dispatchEvent(new Event('submit',{cancelable:true}));});await page.waitForURL('**/account-specialist-profile.html?id=*');assert.equal(calls.filter(x=>x.name==='create_my_specialist_draft').length,1);slowRPC=null;
});
await test('dashboard read errors are not shown as empty profiles; company failure does not hide specialist',async()=>{
 failRPC='get_my_companies';await open('account-home.html');await page.locator('#status').filter({hasText:'Не удалось загрузить компании'}).waitFor();await page.getByText('Иван Обновлённый',{exact:true}).waitFor();
 failRPC='get_my_specialists';await open('account-home.html');await page.locator('#status').filter({hasText:'Не удалось загрузить специалистов'}).waitFor();assert.equal(await page.getByText('Пока нет профилей').count(),0);failRPC=null;
 for(const rpc of ['get_my_companies','get_my_pending_company_invitations']){throwRPC=rpc;await open('account-home.html');await page.getByText('Иван Обновлённый',{exact:true}).waitFor();await page.locator('#status').filter({hasText:'Не удалось загрузить'}).waitFor();}throwRPC=null;
});
await test('failed edit load disables all fields and cannot overwrite draft',async()=>{
 failRPC='get_my_specialists';await open('account-specialist-profile.html?id='+id);await note().filter({hasText:'Не удалось загрузить'}).waitFor();assert(await page.locator('#save').isDisabled());assert(await page.locator('[name=display_name]').isDisabled());failRPC=null;
});
await test('existing company form creates company through exact RPC, then displays in cabinet',async()=>{
 await page.setViewportSize({width:1280,height:900});await open('account-create-company.html');await page.locator('#name').fill('New Company');await page.locator('#slug').fill('new-company');await page.locator('#submit').click();await page.waitForURL('**/account-home.html');await page.getByText('New Company',{exact:true}).waitFor();assert.equal(await page.locator('.company-card .company-avatar svg').count(),1);assert((await page.locator('.specialist-card .specialist-avatar svg').count())>=1);
 const [company]=await db.call(A,'get_my_companies');assert.equal(company.company.website,company.company.public_url);
 await page.getByText('Иван Обновлённый',{exact:true}).waitFor();assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
});
await test('company editor saves actual SQL, reloads, and keeps specialist independent',async()=>{
 const [row]=await db.call(A,'get_my_companies');const id=row.company.id;
 await open('account-profile.html?company_id='+id);await page.locator('#profile-fields:not([disabled])').waitFor();
 await page.locator('#name').fill('Company Edited');await page.locator('#description').fill('Company description');await page.locator('#save').click();await page.locator('#save-state').filter({hasText:'Изменения сохранены'}).waitFor();
 await page.reload();await page.locator('#profile-fields:not([disabled])').waitFor();assert.equal(await page.locator('#description').inputValue(),'Company description');
 assert.equal((await db.call(A,'get_my_specialists')).find(x=>x.slug==='ivan-master').description,'Новое описание');
});
await test('company sections keep company_id and use upper menu without swipe navigation',async()=>{
 const [row]=await db.call(A,'get_my_companies');const id=row.company.id;
 await page.setViewportSize({width:390,height:844});
 await open('account-branches.html?company_id='+id);await page.getByText('Сохранённых филиалов пока нет',{exact:true}).waitFor();
 await page.locator('#new-name').fill('Test Branch');await page.locator('#new-address').fill('Street 1');await page.locator('#new-city').fill('City');await page.locator('#branch-submit').click();await page.locator('#branches').getByText('Test Branch',{exact:true}).waitFor();
 assert.equal(await page.getByRole('button',{name:'Следующий раздел',exact:true}).count(),0);
 assert.equal(await page.getByRole('button',{name:'Предыдущий раздел',exact:true}).count(),0);
 const beforeSwipe=page.url();
 await page.evaluate(()=>{const target=document.querySelector('main');const touch=(x)=>({identifier:1,target,clientX:x,clientY:250});for(const [type,x] of [['touchstart',280],['touchend',70]]){const e=new Event(type,{bubbles:true});Object.defineProperties(e,{touches:{value:type==='touchstart'?[touch(x)]:[]},changedTouches:{value:[touch(x)]}});target.dispatchEvent(e);}});
 assert.equal(page.url(),beforeSwipe);
 await page.locator('.profile-nav-primary a[data-section=services]').click();await page.waitForURL('**/account-services.html?company_id='+id);
 await page.locator('#svc-name').fill('Test Service');await page.locator('#svc-submit').click();await page.locator('#services').getByText('Test Service',{exact:true}).waitFor();
 assert.equal(records.locations[0].company_id,id);assert.equal(records.services[0].company_id,id);
 await open('account-media.html?company_id='+id);await page.locator('#active-company-name').filter({hasText:'Company Edited'}).waitFor();assert.equal(await page.locator('#media-file').count(),1);
 const png=await page.evaluate(()=>{const c=document.createElement('canvas');c.width=c.height=4;return c.toDataURL('image/png').split(',')[1];});
 await page.locator('#media-file').setInputFiles({name:'acceptance.png',mimeType:'image/png',buffer:Buffer.from(png,'base64')});await page.locator('#media-state').filter({hasText:'Фотография загружена и опубликована'}).waitFor();assert.equal(records.media[0].company_id,id);
 await open('account-access.html?company_id='+id);await page.locator('#owner-ui').waitFor({state:'visible'});await page.locator('#members').getByText('Владелец',{exact:true}).first().waitFor();
 await open('account-home.html');await page.getByText('Company Edited',{exact:true}).waitFor();assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.locator('.company-card .manage-link').click();await page.waitForURL('**/account-services.html?company_id='+id);await page.locator('#services').getByText('Test Service',{exact:true}).waitFor();
});
await test('repeat specialist update keeps one row; logout and external next fail closed',async()=>{
 const before=(await db.call(A,'get_my_specialists')).length;
 for(let i=0;i<2;i++){
  await open('account-specialist-profile.html?id='+id);await waitReady();await page.locator('#save').click();await note().filter({hasText:'Изменения сохранены'}).waitFor();
 }
 assert.equal((await db.call(A,'get_my_specialists')).length,before);
 await open('account-home.html');await page.locator('#logout').click();await page.waitForURL('**/account-login.html');assert.equal(user,null);
 user=A;await open('account-login.html?next=https%3A%2F%2Fevil.example');await page.waitForURL('**/account-home.html');
});
await test('12 specialist sections, safe disabled AI/MCP, explicit id and no page swipe on desktop/mobile',async()=>{
 user=A;
 for(const width of [1280,390]){
  await page.setViewportSize({width,height:844});await open('account-specialist-profile.html?id='+id);await waitReady();
  assert.equal(await page.locator('[data-cabinet-header][data-profile-kind=specialist]').count(),1);assert.equal(await page.locator('.cabinet-home').getAttribute('href'),'account-home.html');assert.equal(await page.locator('main.wrap > .editor-nav').count(),1);
  assert.equal(await page.locator('.editor-nav .profile-nav-list a').count(),12);assert.equal(await page.getByRole('link',{name:'Филиалы',exact:true}).count(),0);
  const links=await page.locator('.editor-nav .profile-nav-list a').evaluateAll(es=>es.map(e=>e.getAttribute('href')));
  for(const link of links)assert.equal(new URL(link,'https://cabinet.test').searchParams.get('id'),id);
  const before=page.url();await page.evaluate(()=>{const target=document.querySelector('h1');for(const [type,x] of [['touchstart',350],['touchend',20]]){const e=new Event(type,{bubbles:true});Object.defineProperty(e,type==='touchstart'?'touches':'changedTouches',{value:[{clientX:x,clientY:350}]});target.dispatchEvent(e);}});assert.equal(page.url(),before);
  for(const link of links.filter(x=>x.includes('section='))){await open(link);await page.locator('#section-content:not([hidden])').waitFor();assert.equal(await page.locator('.editor-nav .profile-nav-list a').count(),12);assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));assert.equal(await page.locator('#section-content button:not([disabled]), #section-content textarea:not([disabled]), #section-content input:not([disabled])').count(),0);}
 }
 const before=calls.length;user=B;await open('account-specialist-section.html?id='+id+'&section=mcp');await page.locator('#status').filter({hasText:'недоступен'}).waitFor();assert(await page.locator('#section-content').isHidden());assert(!calls.slice(before).some(x=>x.name.startsWith('save_')));
 user=null;await open('account-specialist-section?id='+id+'&section=mcp');await page.waitForURL('**/account-login.html?*');assert.equal(new URL(page.url()).searchParams.get('next'),'account-specialist-section.html?id='+id+'&section=mcp');
 user=A;await open('account-create-specialist.html?id='+id);await page.waitForURL('**/account-specialist-profile.html?id='+id);await waitReady();
});
await test('shared mobile menu: three primary links, full list, deep links, active extra label, keyboard and no forced scroll',async()=>{
 user=A;const [row]=await db.call(A,'get_my_companies');const companyId=row.company.id;
 for(const kind of ['company','specialist']){
  const prefix=kind==='company'?'account-profile':'account-specialist-profile',query=(kind==='company'?'company_id=':'id=')+(kind==='company'?companyId:id);
  for(const width of [320,390]){
   await page.setViewportSize({width,height:844});await open(prefix+'.html?'+query);
   await page.locator('.profile-nav-primary a').first().waitFor();
   assert.deepEqual(await page.locator('.profile-nav-primary a').allTextContents(),['Профиль','Услуги','Фото']);
   assert(await page.locator('.profile-nav-list').isHidden());
   const links=await page.locator('.profile-nav-list a').evaluateAll(es=>es.map(e=>({href:e.getAttribute('href'),label:e.textContent,key:e.dataset.section})));
   assert.equal(links.some(x=>x.key==='branches'),kind==='company');
   if(kind==='specialist')assert(links.find(x=>x.key==='media').label.includes('портфолио'));
   for(const key of ['profile','reviews','assistant',kind==='company'?'analytics':'settings']){
    const target=links.find(x=>x.key===key);
    await page.getByRole('button',{name:'Все разделы',exact:true}).click();
    assert.equal(await page.locator('.profile-nav-toggle').getAttribute('aria-expanded'),'true');
    await page.locator('.profile-nav-list a[data-section="'+key+'"]').click();
    await page.waitForURL('**/'+target.href);await page.locator('.profile-nav-list a[data-section="'+key+'"][aria-current=page]').waitFor({state:'attached'});
    assert(await page.locator('.profile-nav-list').isHidden());
    if(key!=='profile'){assert(await page.locator('.profile-nav-current').isVisible());assert((await page.locator('.profile-nav-current').innerText()).includes(target.label));}
    await page.reload();await page.locator('.profile-nav-list a[data-section="'+key+'"][aria-current=page]').waitFor({state:'attached'});
    assert.equal(await page.locator('.profile-navigation').evaluate(n=>n.scrollLeft),0);
    const geometry=await page.locator('.profile-navigation').evaluate(nav=>({page:location.pathname,width:innerWidth,document:document.documentElement.scrollWidth,nav:[nav.getBoundingClientRect().left,nav.getBoundingClientRect().right],outside:[...nav.querySelectorAll('*')].filter(e=>e.getClientRects().length&& (e.getBoundingClientRect().left<0||e.getBoundingClientRect().right>innerWidth)).map(e=>e.className)}));
    assert(geometry.nav[0]>=0&&geometry.nav[1]<=width&&geometry.outside.length===0,JSON.stringify(geometry));
    if(geometry.document>width)console.log('Existing editor width diagnostic (menu fits):',JSON.stringify(geometry));
   }
   const toggle=page.locator('.profile-nav-toggle');await toggle.focus();await page.keyboard.press('Space');assert(await page.locator('.profile-nav-list').isVisible());await page.keyboard.press('Escape');assert(await page.locator('.profile-nav-list').isHidden());assert(await toggle.evaluate(e=>e===document.activeElement));
   await toggle.click();await page.locator('h1').first().click();assert(await page.locator('.profile-nav-list').isHidden());
   await page.setViewportSize({width:1280,height:844});assert(await page.locator('.profile-nav-list').isVisible());assert(await toggle.isHidden());assert(await page.locator('.profile-nav-current').isVisible());
   assert.equal(await page.locator('.profile-nav-list a[aria-current=page]').count(),1);
   const manual=await page.locator('.profile-nav-list').evaluate(n=>{n.scrollLeft=80;return n.scrollLeft;});await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));assert.equal(await page.locator('.profile-nav-list').evaluate(n=>n.scrollLeft),manual);
  }
 }
});
await test('service/contact save and reload; missing media/backend disables writes',async()=>{
 user=A;await open('account-specialist-services.html?id='+id);try{await page.locator('#fields:not([disabled])').waitFor({timeout:5000});}catch{throw Error('Service UI did not enable: '+await page.locator('#status').innerText()+'; errors='+JSON.stringify(errors)+'; calls='+JSON.stringify(calls.slice(-6)));}await page.locator('#name').fill('Portrait');await page.locator('#price-from').fill('1500');await page.locator('#duration').fill('45');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Услуга сохранена'}).waitFor();await page.reload();await page.locator('#items').getByText('Portrait',{exact:true}).waitFor();
 await open('account-specialist-contacts.html?id='+id);await page.locator('#fields:not([disabled])').waitFor();await page.locator('#phone').fill('+7 private');await page.locator('[name=format][value=online]').check();await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();await page.reload();await page.locator('#fields:not([disabled])').waitFor();assert.equal(await page.locator('#phone').inputValue(),'+7 private');
 for(const [file,rpc] of [['services','get_my_specialist_services'],['contacts','get_my_specialist_settings'],['media','get_my_specialist_media']]){failRPC=rpc;await open('account-specialist-'+file+'.html?id='+id);await page.locator('#status').filter({hasText:'Хранилище'}).waitFor();assert.equal(await page.locator('#fields').getAttribute('disabled'),'');assert(await page.locator('#save').isDisabled());}failRPC=null;
});
await test('one shell renders both typed adapters without duplicate headers or cross-kind URLs',async()=>{
 user=A;await open('account-specialist-profile.html?id='+id);await waitReady();
 const result=await page.evaluate(async()=>{
  const {mountCabinet}=await import('./account-profile-shell.js');const {profileAdapter}=await import('./account-profile-adapters.js');
  const snapshots=[];
  for(const kind of ['company','specialist','company']){const adapter=profileAdapter(kind);mountCabinet(adapter,{id:'33333333-3333-4333-8333-333333333333',name:'Fixture',role:'owner'},'profile');snapshots.push({kind:document.querySelector('[data-cabinet-header]').dataset.profileKind,headers:document.querySelectorAll('[data-cabinet-header]').length,links:[...document.querySelectorAll('.editor-nav .profile-nav-list a')].map(a=>a.getAttribute('href'))});}return snapshots;
 });
 for(const snapshot of result){assert.equal(snapshot.headers,1);for(const link of snapshot.links){const params=new URL(link,'https://cabinet.test').searchParams;assert.equal(params.get(snapshot.kind==='company'?'company_id':'id'),'33333333-3333-4333-8333-333333333333');assert(!params.has(snapshot.kind==='company'?'id':'company_id'));}}
});
assert.deepEqual(errors,[]);console.log(`PASS ${count} browser groups; all external requests blocked; SQL-backed RPC adapter (not hosted Auth/PostgREST)`);
}finally{await browser.close();await db.close();}
