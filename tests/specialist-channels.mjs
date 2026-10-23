import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {database,A,B} from './database.mjs';
import {normalizeChannel,validateChannels} from '../account-specialist-channel-rules.js';
const db=await database({editor:true});let count=0;
const test=async(name,fn)=>{await fn();console.log('PASS CHANNELS',++count,name);};
const reject=(fn,code)=>assert.rejects(fn,e=>!code||e.code===code);
const row=(kind,value_raw,extra={})=>({id:crypto.randomUUID(),kind,value_raw,label:'',is_public:false,is_preferred:false,accepts_inquiries:false,...extra});
try{
 const before=(await db.query("SELECT oid,pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='public'::regnamespace ORDER BY oid")).rows;
 const company=(await db.query('SELECT row_to_json(c) data FROM companies c')).rows;
 await db.exec(await fs.readFile(new URL('../docs/specialist-contact-channels-candidate.sql',import.meta.url),'utf8'));
 const a=await db.call(A,'create_my_specialist_draft',['Channels A','channels-a','Master']);
 const b=await db.call(B,'create_my_specialist_draft',['Channels B','channels-b','Master']);
 const read=()=>db.call(A,'list_my_specialist_channels',[a.id]);
 const save=(rows,v)=>db.call(A,'save_my_specialist_channels',[a.id,v,JSON.stringify(rows)]);
 const good=[['telegram','@Yumis_test'],['max','https://max.ru/u/AbC123'],['vk','https://m.vk.com/id123'],['whatsapp','+79991234567'],['ok','https://ok.ru/profile/123'],['website','https://Example.ru'],['portfolio','https://portfolio.ru/project?a=1']];
 let channels=good.map(([kind,value])=>row(kind,value));
 await test('read is side effect free; all seven kinds save and reopen privately',async()=>{
  assert.deepEqual(await read(),{version:0,channels:[]});
  assert.equal(Number((await db.query('SELECT count(*) n FROM specialist_channel_sets')).rows[0].n),0);
  const data=await save(channels,0);assert.equal(data.version,1);assert.equal(data.channels.length,7);
  assert.deepEqual(await read(),data);
  data.channels.forEach((r,i)=>{assert.equal(r.href,normalizeChannel(good[i][0],good[i][1]));assert.equal(r.is_public,false);assert.equal(r.sort_order,i);});
 });
 await test('SQL and JS reject hostile URLs and wrong platform hosts',async()=>{
  const bad=[['website','https://example.ru/a/../b'],['website','https://example.ru/%2e%2e/'],['website','https://example.ru/%ZZ'],['website','javascript:alert(1)'],['website','http://example.ru'],['website','https://user:pass@example.ru'],['website','https://127.0.0.1'],['website','https://example.ru:443/'],['website','https://xn--e1afmkfd.ru/'],['website','https://example.ru/%0aX'],['website','https://example.ru\\@evil.ru'],['website','https://example.ru/#fragment'],['website','https://example.ru/\n'],['telegram','https://t.me.evil.ru/name'],['telegram','https://t.me/share'],['telegram','https://t.me/+invite'],['telegram','https://t.me/name?start=x'],['vk','https://vk.com/away.php'],['vk','https://evil.ru/id123'],['ok','https://ok.ru/dk'],['whatsapp','8999123456'],['whatsapp','https://wa.me/+79991234567'],['max','@username'],['max','https://max.ru/'],['max','https://max.ru/u/abc?redirect=x']];
  for(const [kind,value] of bad){assert.throws(()=>normalizeChannel(kind,value),undefined,kind+':'+value);await reject(()=>save([row(kind,value)],1),'22023');}
  assert.equal((await read()).channels.length,7);
 });
 await test('duplicates, quotas, preferred, privacy and strict JSON validation',async()=>{
  await reject(()=>save([row('telegram','@Yumis_test'),row('telegram','https://t.me/yumis_test')],1),'23505');
  const duplicate=row('website','https://one.ru');await reject(()=>save([duplicate,{...duplicate,value_raw:'https://two.ru'}],1),'23505');
  await reject(()=>save(Array.from({length:21},(_,i)=>row('website','https://site'+i+'.ru')),1),'54000');
  for(const bad of [
   [row('website','https://one.ru',{is_preferred:true}),row('website','https://two.ru',{is_preferred:true})],
   [row('website','https://one.ru',{is_public:true})],
   [row('website','https://one.ru',{accepts_inquiries:'false'})],
   [row('website','https://one.ru',{href:'https://evil.ru'})],
   [row('website','https://one.ru',{label:'x'.repeat(41)})],
   [row('website','https://one.ru',{label:'line\nbreak'})],
   [row('unknown','https://one.ru')], [null], {}
  ])await reject(()=>save(bad,1),'22023');
  assert.equal((await read()).version,1);
 });
 await test('foreign/anonymous/company access and contact ID theft denied',async()=>{
  for(const id of [a.id,'33333333-3333-4333-8333-333333333333']){
   await reject(()=>db.call(B,'list_my_specialist_channels',[id]),'42501');
   await reject(()=>db.call(B,'save_my_specialist_channels',[id,0,'[]']),'42501');
  }
  await reject(()=>db.call(null,'list_my_specialist_channels',[a.id]),'42501');
  await reject(()=>db.session(null,c=>c.query('SELECT public.list_my_specialist_channels($1)',[a.id]),'anon'),'42501');
  await reject(()=>db.call(B,'save_my_specialist_channels',[b.id,0,JSON.stringify([channels[0]])]),'42501');
 });
 await test('direct tables, helper, accidental SELECT grants remain fail-closed',async()=>{
  for(const table of ['specialist_channel_sets','specialist_contact_channels']){
   await reject(()=>db.session(A,c=>c.query('SELECT * FROM public.'+table)),'42501');
   await reject(()=>db.session(A,c=>c.query('DELETE FROM public.'+table)),'42501');
   await db.exec('GRANT SELECT ON public.'+table+' TO authenticated');
   assert.equal((await db.session(B,c=>c.query('SELECT * FROM public.'+table))).rows.length,0);
   await db.exec('REVOKE SELECT ON public.'+table+' FROM authenticated');
  }
  await reject(()=>db.session(A,c=>c.query("SELECT public.specialist_channel_normalize('website','https://example.ru')")),'42501');
 });
 await test('edit, order, one preferred, lost response replay and stale tabs',async()=>{
  channels=[...channels].reverse();channels[0].label='<img src=x onerror=alert(1)>';channels[0].is_preferred=true;channels[0].accepts_inquiries=true;
  const data=await save(channels,1);assert.equal(data.version,2);assert.equal(data.channels[0].id,channels[0].id);assert.equal(data.channels[0].label,channels[0].label);
  await reject(()=>save(channels,1),'PT409');assert.equal((await read()).channels.length,7);
  const concurrent=await Promise.allSettled([save(channels,2),save(channels,2)]);
  assert.equal(concurrent.filter(x=>x.status==='fulfilled').length,1);assert.equal(concurrent.find(x=>x.status==='rejected').reason.code,'PT409');
 });
 await test('legacy settings and existing function definitions preserved',async()=>{
  const defs=(await db.query("SELECT oid,pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='public'::regnamespace ORDER BY oid")).rows;
  for(const old of before)assert.deepEqual(defs.find(x=>x.oid===old.oid),old);
  const legacy=await db.call(A,'save_my_specialist_settings',[a.id,'+79990000000','legacy@example.ru','https://legacy.ru',['online'],'City','Education',0]);
  await save([],3);assert.deepEqual(await db.call(A,'get_my_specialist_settings',[a.id]),legacy);
  assert.deepEqual((await db.query('SELECT row_to_json(c) data FROM companies c')).rows,company);
  assert.equal((await read()).channels.length,0);assert.equal((await read()).version,4);
 });
 await test('JS collections validate independent from saved href and reject duplicates',async()=>{
  assert.equal(validateChannels([row('telegram','@valid')])[0].href,'https://t.me/valid');
  assert.throws(()=>validateChannels([row('telegram','@valid'),row('telegram','https://t.me/valid')]));
  assert.throws(()=>validateChannels([row('website','https://one.ru',{is_public:true})]));
 });
 await test('cosmetic HTTPS case and edge spaces normalize before server save; path case retained',async()=>{
  const cases=[['telegram',' Https://T.ME/Yumis_test ','https://t.me/yumis_test'],['vk','Https://VK.com/Yumis','https://vk.com/yumis'],['max','HTTPS://MAX.ru/u/AbC123','https://max.ru/u/AbC123'],['whatsapp','HTTPS://WA.ME/79991234567','https://wa.me/79991234567'],['ok','HtTpS://OK.RU/profile/123','https://ok.ru/profile/123'],['website',' HtTpS://Example.ru/CaseSensitive?A=B ','https://example.ru/CaseSensitive?A=B'],['portfolio','https://Portfolio.ru/MyWork','https://portfolio.ru/MyWork']];
  const payload=validateChannels(cases.map(([kind,value])=>row(kind,value))).map(({href,...r})=>r);
  payload.forEach((r,i)=>{assert(r.value_raw.startsWith('https://'));assert.equal(normalizeChannel(r.kind,cases[i][1]),cases[i][2]);});
  const current=await read(),saved=await save(payload,current.version);assert.equal(saved.channels.length,7);saved.channels.forEach((r,i)=>assert.equal(r.href,cases[i][2]));assert.deepEqual(await read(),saved);
  assert.throws(()=>validateChannels([row('vk','Https://VK.com/Yumis'),row('vk','https://vk.com/yumis')]));
  assert.throws(()=>normalizeChannel('website','JaVaScRiPt:alert(1)'));
 });
 console.log('CHANNELS RESULT',count,'groups PASS; engine',db.concurrent?'PostgreSQL':'PGlite','HOSTED SQL NOT APPLIED');
}finally{await db.close();}
