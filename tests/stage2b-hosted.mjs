// Manual hosted acceptance: private synthetic users, approved staging only; no schema mutation.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';import crypto from 'node:crypto';import {chromium} from 'playwright';
const cfg=JSON.parse(await fs.readFile(process.env.OTZOVIK_TEST_CONFIG,'utf8'));
assert.equal(cfg.url,'https://salmcnhexlftrgtiryyo.supabase.co');
const base=process.env.OTZOVIK_TEST_PREVIEW;assert(/^https:\/\/[a-z0-9-]+\.otzovik-cabinet-dev\.pages\.dev$/.test(base));
const output=process.env.OTZOVIK_TEST_OUTPUT;assert(output,'Private evidence directory required');await fs.mkdir(output,{recursive:true});
const browser=await chromium.launch({headless:true,...(process.env.TEST_BROWSER_CHANNEL?{channel:process.env.TEST_BROWSER_CHANNEL}:{}),args:process.env.TEST_PREVIEW_IP?['--host-resolver-rules=MAP '+new URL(base).hostname+' '+process.env.TEST_PREVIEW_IP]:[]});
const results=[],errors=[],mutations=[];const pass=name=>{results.push(name);console.log('PASS HOSTED CHANNELS',results.length,name);};
async function token(user){const r=await fetch(cfg.url+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:cfg.key,'Content-Type':'application/json'},body:JSON.stringify({email:user.email,password:user.password})});const d=await r.json();assert(r.ok&&d.access_token);return d.access_token;}
const tokens=await Promise.all(cfg.users.map(token));
async function request(t,path,{method='POST',body={}}={}){const res=await fetch(cfg.url+'/rest/v1/'+path,{method,headers:{apikey:cfg.key,...(t?{Authorization:'Bearer '+t}:{}),'Content-Type':'application/json'},...(method==='GET'?{}:{body:JSON.stringify(body)})});const data=await res.json();return {ok:res.ok,status:res.status,data};}
const rpc=(t,name,args={})=>request(t,'rpc/'+name,{body:args});
const owned=(await rpc(tokens[0],'get_my_specialists')).data.filter(x=>x.profile_status==='draft');
const id=process.env.OTZOVIK_TEST_SPECIALIST_ID||owned[0]?.id;assert(owned.some(x=>x.id===id));
const read=()=>rpc(tokens[0],'list_my_specialist_channels',{p_specialist_id:id});
const save=(rows,version,t=tokens[0],profile=id)=>rpc(t,'save_my_specialist_channels',{p_specialist_id:profile,p_version:version,p_channels:rows});
const payload=rows=>rows.map(({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public})=>({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public}));
const initial=await read();assert(initial.ok);const original=payload(initial.data.channels);
const legacy=(await rpc(tokens[0],'get_my_specialist_settings',{p_specialist_id:id})).data;
const row=(kind,value_raw,extra={})=>({id:crypto.randomUUID(),kind,value_raw,label:'Тест '+kind,is_preferred:false,accepts_inquiries:false,is_public:false,...extra});
const data=[row('telegram','@Otzovik_test',{is_preferred:true,accepts_inquiries:true}),row('max','https://max.ru/u/TestAccount'),row('vk','https://vk.com/id12345'),row('whatsapp','+79991234567'),row('ok','https://ok.ru/profile/12345'),row('website','https://example.com'),row('portfolio','https://example.com/portfolio')];
let lastVersion=initial.data.version,changed=false,context,page,cleanup=false;
async function successfulSave(rows){const r=await save(rows,lastVersion);assert(r.ok,JSON.stringify(r.data));lastVersion=r.data.version;changed=true;return r.data;}
async function newContext(){const ctx=await browser.newContext();await ctx.route('**/*',r=>[base,cfg.url].includes(new URL(r.request().url()).origin)?r.continue():r.abort());const pg=await ctx.newPage();pg.on('pageerror',e=>errors.push(e.message));pg.on('request',r=>{if(r.url().startsWith(cfg.url)){const path=new URL(r.url()).pathname;if(/\/(?:save|create|update|delete|publish|register)_/.test(path))mutations.push(path);}});return {ctx,pg};}
async function login(pg){await pg.goto(base+'/account-login');await pg.locator('#email').fill(cfg.users[0].email);await pg.locator('#password').fill(cfg.users[0].password);await pg.locator('#submit').click();await pg.waitForURL(/\/account-home(?:\.html)?$/);}
const contacts=base+'/account-specialist-contacts?id='+id;
try{
 pass('actual Auth and new PostgREST list RPC available; initial private collection read');
 let stored=await successfulSave(data);assert.equal(stored.channels.length,7);assert(stored.channels.every(x=>x.is_public===false));assert.equal(stored.channels[0].href,'https://t.me/otzovik_test');assert.deepEqual((await read()).data,stored);
 pass('all seven kinds save/reopen through actual hosted RPC, normalized and private');
 for(const t of [tokens[1],null])for(const name of ['list_my_specialist_channels','save_my_specialist_channels']){
  const r=await rpc(t,name,{p_specialist_id:id,...(name.startsWith('save')?{p_version:lastVersion,p_channels:[]}:{})});assert(!r.ok);assert(['42501','PGRST301'].includes(r.data.code),JSON.stringify(r.data));
 }
 pass('foreign and anonymous list/save denied');
 for(const table of ['specialist_channel_sets','specialist_contact_channels'])for(const t of [tokens[0],tokens[1],null]){
  const r=await request(t,table+'?select=*',{method:'GET'});assert(!r.ok);assert.equal(r.data.code,'42501');
 }
 const helper=await rpc(tokens[0],'specialist_channel_normalize',{p_kind:'website',p_value:'https://example.com'});assert(!helper.ok);
 pass('direct tables and internal normalization helper inaccessible to clients');
 const ownB=(await rpc(tokens[1],'get_my_specialists')).data.find(x=>x.profile_status==='draft');
 if(ownB){const b=await rpc(tokens[1],'list_my_specialist_channels',{p_specialist_id:ownB.id});const r=await save([data[0]],b.data.version,tokens[1],ownB.id);assert(!r.ok);assert.equal(r.data.code,'42501');assert.deepEqual((await rpc(tokens[1],'list_my_specialist_channels',{p_specialist_id:ownB.id})).data,b.data);}
 else{const other=owned.find(x=>x.id!==id);assert(other,'Need second isolated profile for child-ID test');const b=await rpc(tokens[0],'list_my_specialist_channels',{p_specialist_id:other.id});const r=await save([data[0]],b.data.version,tokens[0],other.id);assert(!r.ok);assert.equal(r.data.code,'42501');}
 pass('cross-profile channel ID cannot be stolen; target collection untouched');
 const bad=[['website','javascript:alert(1)'],['website','https://user@example.com'],['website','https://127.0.0.1'],['website','https://example.com/%0aX'],['website','https://example.com/a/../b'],['telegram','https://t.me.evil.com/user'],['telegram','https://t.me/share'],['max','@someone'],['vk','https://vk.com/away.php'],['whatsapp','8999123456'],['ok','https://ok.ru/dk']];
 for(const [kind,value] of bad){const r=await save([row(kind,value)],lastVersion);assert(!r.ok);assert.equal(r.data.code,'22023');}
 for(const [rows,code] of [[[row('website','https://example.com',{is_public:true})],'22023'],[[row('website','https://example.com'),row('website','https://EXAMPLE.com/')],'23505'],[Array.from({length:21},(_,i)=>row('website','https://site'+i+'.com')),'54000'],[[row('website','https://one.com',{is_preferred:true}),row('website','https://two.com',{is_preferred:true})],'22023']]){
  const r=await save(rows,lastVersion);assert(!r.ok);assert.equal(r.data.code,code);
 }
 assert.deepEqual((await read()).data,stored);pass('hostile links, publicity, duplicates, quota and preferred rules reject atomically');
 const stale=await save([],lastVersion-1);assert.equal(stale.status,409);assert.equal(stale.data.code,'PT409');
 const race=await Promise.all([save(data,lastVersion),save(data,lastVersion)]);assert.equal(race.filter(r=>r.ok).length,1);assert.equal(race.find(r=>!r.ok).status,409);stored=race.find(r=>r.ok).data;lastVersion=stored.version;
 pass('actual overlapping HTTP saves: exactly one success, one HTTP409; stale save denied');
 ({ctx:context,pg:page}=await newContext());await login(page);await page.goto(contacts);
 const root=page.locator('#specialist-channels'),rows=root.locator('.channel-row'),button=root.getByRole('button',{name:'Сохранить контакты',exact:true}),note=root.locator('[role=status]');
 const ready=()=>page.locator('#specialist-channels form>fieldset:not([disabled])').waitFor();
 await ready();assert.equal(await rows.count(),7);assert.equal(await rows.first().locator('optgroup').count(),3);assert.equal(await root.locator('a').count(),0);
 for(const r of await rows.all()){assert.equal(await r.locator('input').count(),1);assert.equal(await r.locator('select').count(),1);assert.equal(await r.locator('button').count(),1);}
 assert.equal(await root.locator('input[type=checkbox]').count(),0);
 pass('compact browser shows seven rows: service, one input and accessible delete only');
 await root.getByRole('button',{name:'Добавить контакт',exact:true}).click();await rows.last().locator('input').fill('@Otzovik_second_test');await button.click();await note.filter({hasText:'Контакты сохранены'}).waitFor();stored=(await read()).data;lastVersion=stored.version;assert.equal(stored.channels.length,8);
 await page.reload();await ready();assert.equal(await rows.count(),8);pass('compact Add contact creates and persists row through browser save/reopen');
 await rows.last().getByRole('button',{name:/Удалить контакт/}).click();await button.click();await note.filter({hasText:'Контакты сохранены'}).waitFor();stored=(await read()).data;lastVersion=stored.version;
 const retained=payload(stored.channels);retained[0].label='<img src=x onerror=alert(1)>';stored=await successfulSave(retained);await page.reload();await ready();
 assert.equal(await root.locator('img').count(),0);assert.equal(await root.getByText(retained[0].label,{exact:true}).count(),0);
 await rows.first().locator('input').fill('@Otzovik_edited');await button.click();await note.filter({hasText:'Контакты сохранены'}).waitFor();stored=(await read()).data;lastVersion=stored.version;
 assert.deepEqual(stored.channels.map(r=>r.id),retained.map(r=>r.id));assert.equal(stored.channels[0].label,retained[0].label);assert(stored.channels[0].is_preferred&&stored.channels[0].accepts_inquiries);
 await page.reload();await ready();assert.equal(await rows.first().locator('input').inputValue(),'@Otzovik_edited');
 pass('compact edit/reload preserves hidden label/preferred/inquiries/IDs/order; XSS remains inert');
 await rows.last().getByRole('button',{name:/Удалить контакт/}).click();await button.click();await note.filter({hasText:'Контакты сохранены'}).waitFor();stored=(await read()).data;lastVersion=stored.version;assert.equal(stored.channels.length,6);
 pass('compact removal persists without changing remaining IDs');
 stored=await successfulSave(payload(stored.channels));await button.click();await note.filter({hasText:'Данные уже изменились'}).waitFor();assert.deepEqual((await read()).data,stored);
 pass('stale compact form cannot overwrite concurrent save');
 await page.reload();await ready();
 for(const width of [320,390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
 await root.screenshot({path:output+'/contacts-desktop.png'});await page.setViewportSize({width:390,height:1000});await root.screenshot({path:output+'/contacts-mobile.png'});
 assert.equal(await page.locator('.editor-nav a').count(),5);assert.equal(await page.getByRole('link',{name:/Выбор типа профиля/}).count(),0);
 pass('compact form fits320/390/1440 with existing navigation');
 await context.close();({ctx:context,pg:page}=await newContext());await login(page);await page.goto(contacts);await page.locator('#specialist-channels form>fieldset:not([disabled])').waitFor();assert.equal(await page.locator('.channel-row').count(),6);assert.equal(await page.locator('.channel-row input').first().inputValue(),'@Otzovik_edited');
 pass('fresh actual Auth session reopens compact contacts');
 assert.deepEqual((await rpc(tokens[0],'get_my_specialist_settings',{p_specialist_id:id})).data,legacy);assert.deepEqual(errors,[]);assert(mutations.every(p=>p.endsWith('/save_my_specialist_channels')));
 pass('legacy contacts unchanged; no page errors/company/publication writes');
}finally{
 if(changed){const current=await read();assert(current.ok);assert.equal(current.data.version,lastVersion,'Concurrent external edit detected: do not overwrite');const restored=await save(original,lastVersion);assert(restored.ok);assert.deepEqual(payload(restored.data.channels),original);cleanup=true;console.log('PASS CLEANUP original channel values restored; no synthetic contact links retained');if(context&&original.length===0){await page.goto(contacts);await page.locator('#specialist-channels form>fieldset:not([disabled])').waitFor();assert.equal(await page.locator('.channel-row').count(),1);assert.equal(await page.locator('.channel-row input').first().inputValue(),'');assert.equal((await read()).data.channels.length,0);pass('empty section immediately shows one editable blank row; nothing auto-saved');}}
 if(context)await context.close();await browser.close();
 await fs.writeFile(output+'/result.json',JSON.stringify({preview:base,specialist_id:id,results,errors,mutations,cleanup,hosted:true,transport:'actual Auth/PostgREST; no mocked responses'},null,2));
}
console.log('HOSTED CHANNELS RESULT',results.length,'groups PASS');
