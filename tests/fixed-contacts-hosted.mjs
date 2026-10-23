// Manual acceptance against an isolated Pages preview and approved staging. No schema changes.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {chromium} from 'playwright';
const cfg=JSON.parse(await fs.readFile(process.env.OTZOVIK_TEST_CONFIG,'utf8'));
assert.equal(cfg.url,'https://salmcnhexlftrgtiryyo.supabase.co');
const base=process.env.OTZOVIK_TEST_PREVIEW;assert(/^https:\/\/[a-z0-9-]+\.otzovik-cabinet-dev\.pages\.dev$/.test(base));
const id=process.env.OTZOVIK_TEST_SPECIALIST_ID;assert(id);
const output=process.env.OTZOVIK_TEST_OUTPUT;assert(output);
const browser=await chromium.launch({headless:true,...(process.env.TEST_BROWSER_CHANNEL?{channel:process.env.TEST_BROWSER_CHANNEL}:{}),args:process.env.TEST_PREVIEW_IP?['--host-resolver-rules=MAP '+new URL(base).hostname+' '+process.env.TEST_PREVIEW_IP]:[]});
const ctx=await browser.newContext();await ctx.route('**/*',r=>[base,cfg.url].includes(new URL(r.request().url()).origin)?r.continue():r.abort());
const page=await ctx.newPage(),errors=[],passes=[];page.on('pageerror',e=>errors.push(e.message));
const rpc=(name,args)=>page.evaluate(async({name,args})=>{const {sb}=await import('./account-specialist-api.js');const r=await sb.rpc(name,args);if(r.error)throw Error(r.error.code+': '+r.error.message);return r.data;},{name,args});
const read=()=>rpc('list_my_specialist_channels',{p_specialist_id:id}),settings=()=>rpc('get_my_specialist_settings',{p_specialist_id:id});
const payload=rows=>rows.map(({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public})=>({id,kind,value_raw,label,is_preferred,accepts_inquiries,is_public}));
const legacyArgs=d=>Object.fromEntries(['phone','email','website','work_formats','service_area','qualifications'].map(k=>['p_'+k,d[k]]));
const ready=()=>page.locator('#fields:not([disabled])').waitFor(),input=kind=>page.locator('#specialist-channels input[data-kind='+kind+']').first();
const save=async()=>{await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();};
const pass=s=>{passes.push(s);console.log('PASS REAL FIXED CONTACTS',passes.length,s);};
let original,legacy,lastChannel,lastSettings,channelChanged=false,settingsChanged=false;
try{
 await page.goto(base+'/account-login');await page.locator('#email').fill(cfg.users[0].email);await page.locator('#password').fill(cfg.users[0].password);await page.locator('#submit').click();await page.waitForURL(/\/account-home(?:\.html)?$/);
 await page.goto(base+'/account-specialist-contacts?id='+id);await ready();
 original=await read();legacy=await settings();lastChannel=original.version;lastSettings=legacy.version;
 // Private snapshot for recovery if this manual run is interrupted.
 await fs.mkdir(output,{recursive:true});await fs.writeFile(output+'/fixed-original.json',JSON.stringify({id,original,legacy}));
 assert.equal(await page.locator('form').count(),1);assert.equal(await page.locator('#specialist-channels select,#specialist-channels button').count(),0);assert.equal(await page.locator('#save').count(),1);pass('actual login and one ordinary form, no dynamic controls');
 // Clear only this synthetic profile with CAS, keeping an exact private snapshot.
 let data=await rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:lastChannel,p_channels:[]});lastChannel=data.version;channelChanged=true;
 await page.reload();await ready();await save();data=await read();lastChannel=data.version;assert.equal(data.channels.length,0);pass('all optional fields empty: save succeeds with no stored blank contacts');
 const vals={telegram:'@Otzovik_fixed',whatsapp:'+79991234567',max:'https://max.ru/u/CaseToken',vk:' Https://VK.com/id12345 ',ok:'https://ok.ru/profile/12345',portfolio:'HtTpS://Example.com/CaseSensitive?A=B'};
 for(const [kind,value] of Object.entries(vals))await input(kind).fill(value);
 await page.locator('#website').fill(' HtTpS://Example.com/SiteCase?A=B ');await page.locator('#phone').fill('+79990000000');
 // Mark before the UI request so cleanup also runs if the response is lost.
 settingsChanged=true;
 await save();data=await read();lastChannel=data.version;lastSettings=(await settings()).version;
 assert.equal(data.channels.length,6);assert(data.channels.every(r=>r.is_public===false));assert.equal(data.channels.find(r=>r.kind==='vk').value_raw,'https://VK.com/id12345');
 await page.reload();await ready();assert.equal(await input('telegram').inputValue(),'@Otzovik_fixed');assert.equal(await page.locator('#website').inputValue(),'https://Example.com/SiteCase?A=B');pass('six channels, website and phone save and reopen via real Auth/PostgREST; case retained');
 const before=await read(),beforeSettings=await settings();await input('whatsapp').fill('66667666');await page.locator('#phone').fill('+79991111111');await page.locator('#save').click();assert.equal(await input('whatsapp').getAttribute('aria-invalid'),'true');assert.deepEqual(await read(),before);assert.deepEqual(await settings(),beforeSettings);pass('invalid WhatsApp blocks both writes, no silent partial save');
 await page.reload();await ready();await input('whatsapp').fill('');await save();data=await read();lastChannel=data.version;lastSettings=(await settings()).version;assert.equal(data.channels.length,5);await page.reload();await ready();assert.equal(await input('whatsapp').inputValue(),'');pass('clearing optional field removes only that contact and remains empty on reopen');
 for(const width of [320,390,1440]){await page.setViewportSize({width,height:1000});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
 assert.equal(await page.locator('.editor-nav a').count(),5);assert.deepEqual(errors,[]);await page.setViewportSize({width:390,height:1000});await page.screenshot({path:output+'/fixed-hosted-mobile.png',fullPage:true});pass('320/390/1440 without overflow, existing five nav links, zero page errors');
}finally{
 // Never overwrite external concurrent changes. For an unknown/lost response stop for recovery.
 if(channelChanged){const now=await read();assert.equal(now.version,lastChannel,'Concurrent or untracked channel edit: restore manually from private snapshot');const restored=await rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:lastChannel,p_channels:payload(original.channels)});assert.deepEqual(payload(restored.channels),payload(original.channels));}
 if(settingsChanged){const now=await settings();assert.equal(now.version,lastSettings,'Concurrent or untracked settings edit: restore manually from private snapshot');const restored=await rpc('save_my_specialist_settings',{p_specialist_id:id,p_version:lastSettings,...legacyArgs(legacy)});assert.deepEqual(legacyArgs(restored),legacyArgs(legacy));}
 if(channelChanged||settingsChanged)pass('original synthetic profile contacts and settings restored with CAS; no test values left');
 await fs.writeFile(output+'/fixed-hosted-result.json',JSON.stringify({preview:base,passes,errors},null,2));await browser.close();
}
