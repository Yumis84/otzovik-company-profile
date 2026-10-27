import assert from 'node:assert/strict';import fs from 'node:fs/promises';import crypto from 'node:crypto';import {createMediaGateway} from '../server/specialist-media-gateway.js';
export async function gatewayChecks({a,b,anonymous,admin,db,api,anon,service,page,open,ok,test,company}){
 const file=f=>fs.readFile(new URL('../'+f,import.meta.url),'utf8'),A=ok(await a.auth.getUser()).user.id;
 const id=ok(await a.rpc('get_my_specialists')).find(r=>r.slug==='local-specialist').id;
 // Migration from historical isolated fixture only. No hosted trigger was installed or removed.
 await db.query('DROP TRIGGER specialist_object_integrity ON storage.objects');
 await db.query(await file('sql/20261027_specialist_upload_gateway_CANDIDATE.sql'));
 await db.query(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));
 await db.query("NOTIFY pgrst,'reload schema'");await new Promise(r=>setTimeout(r,1500));
 const bytes=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=','base64');
 const payload=(profile=id,request_id=crypto.randomUUID())=>({action:'upload',specialist_id:profile,request_id,kind:'portfolio',mime:'image/png',data:bytes.toString('base64'),caption:'Gateway photo'});
 async function gw(c,body,headers={}){
  const session=await c.auth.getSession();const token=session.data.session?.access_token;
  const r=await fetch(api+'/functions/v1/specialist-media-gateway',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...headers},body:JSON.stringify(body)});
  const data=await r.json();assert(!JSON.stringify(data).includes(service));return{status:r.status,...data};
 }
 await test('real Edge gateway authenticates JWT; anonymous, foreign, spoofed owner and Origin denied',async()=>{
  assert.equal((await gw(anonymous,payload())).status,401);assert.equal((await gw(b,{...payload(),p_owner:A})).status,403);
  assert.equal((await gw(a,payload(),{Origin:'https://evil.invalid'})).status,403);
  for(const c of [a,b,anonymous])assert((await c.rpc('specialist_gateway_reserve',{p_owner:A,p_specialist_id:id,p_request_id:crypto.randomUUID(),p_kind:'portfolio',p_fingerprint:'a'.repeat(64),p_mime:'image/png',p_size:bytes.length,p_caption:null})).error);
  assert.equal((await gw(a,{...payload(),data:Buffer.from('<svg/>').toString('base64')})).status,415);
 });
 let photo,body=payload();
 await test('real Edge upload, lost response replay, private signed read and direct bypass denial',async()=>{
  const saved=await gw(a,body);assert.equal(saved.status,200,JSON.stringify(saved));photo=saved.media;assert(photo.id);
  assert.equal((await gw(a,body)).media.id,photo.id);
  assert.equal((await gw(a,{...body,caption:'Changed'})).status,409);
  ok(await a.storage.from('specialist-media').download(photo.object_name));
  const signed=ok(await a.storage.from('specialist-media').createSignedUrl(photo.object_name,60));assert.equal((await fetch(signed.signedUrl)).status,200);
  for(const c of [b,anonymous]){assert((await c.storage.from('specialist-media').download(photo.object_name)).error);assert((await c.storage.from('specialist-media').createSignedUrl(photo.object_name,60)).error);}
  const path=id+'/portfolio/'+crypto.randomUUID()+'.png';
  assert((await a.storage.from('specialist-media').upload(path,bytes,{contentType:'image/png'})).error);
  assert((await a.storage.from('specialist-media').createSignedUploadUrl(path)).error);
  assert((await a.storage.from('specialist-media').copy(photo.object_name,path)).error);
  assert((await a.storage.from('specialist-media').move(photo.object_name,path)).error);
  assert((await a.storage.from('specialist-media').remove([photo.object_name])).error||ok(await a.storage.from('specialist-media').download(photo.object_name)));
  ok(await a.storage.from('specialist-media').download(photo.object_name));
 });
 await test('real PostgREST service CRUD and 40001 versus PT409 HTTP mapping',async()=>{
  const params={p_specialist_id:id,p_service_id:crypto.randomUUID(),p_name:'Gateway v1',p_price_from:100,p_duration_minutes:45};const row=ok(await a.rpc('save_my_specialist_service',params));assert.equal(row.price_from,100);assert.equal(row.duration_minutes,45);
  const changed=ok(await a.rpc('save_my_specialist_service',{...params,p_name:'Edited',p_version:row.version}));assert.equal(changed.version,row.version+1);
  const stale=await a.rpc('save_my_specialist_service',{...params,p_version:row.version});assert.equal(stale.error?.code,'40001');assert([409,500].includes(stale.status));console.log('POSTGREST conflict code40001 HTTP',stale.status);
  const collision=await admin.rpc('specialist_gateway_reserve',{p_owner:A,p_specialist_id:id,p_request_id:body.request_id,p_kind:'portfolio',p_fingerprint:'b'.repeat(64),p_mime:'image/png',p_size:bytes.length,p_caption:'Gateway photo'});assert.equal(collision.error?.code,'PT409');assert.equal(collision.status,409);console.log('POSTGREST conflict codePT409 HTTP',collision.status);
  ok(await a.rpc('delete_my_specialist_service',{p_specialist_id:id,p_service_id:row.id,p_version:changed.version}));assert(!ok(await a.rpc('get_my_specialist_services',{p_specialist_id:id})).some(r=>r.id===row.id));
 });
 await test('real owner/foreign/anon editor ACL, settings/channel CAS and direct tables closed',async()=>{
  for(const c of [b,anonymous])for(const name of ['get_my_specialist_services','get_my_specialist_settings','get_my_specialist_media','list_my_specialist_channels'])assert.equal((await c.rpc(name,{p_specialist_id:id})).error?.code,'42501');
  for(const c of [a,b,anonymous])for(const table of ['specialist_profiles','specialist_services','specialist_settings','specialist_media','specialist_channel_sets','specialist_contact_channels','specialist_upload_reservations','specialist_upload_control'])assert((await c.from(table).select('*')).error);
  const setting=ok(await a.rpc('save_my_specialist_settings',{p_specialist_id:id,p_phone:'+79991234567',p_version:0}));assert.equal(setting.contact_visibility,'private');assert((await a.rpc('save_my_specialist_settings',{p_specialist_id:id,p_version:0})).error);
  const initial=ok(await a.rpc('list_my_specialist_channels',{p_specialist_id:id}));const make=value=>({p_specialist_id:id,p_version:initial.version,p_channels:[{id:crypto.randomUUID(),kind:'telegram',value_raw:value,label:'',is_public:false,is_preferred:false,accepts_inquiries:false}]});
  const outcomes=await Promise.all([a.rpc('save_my_specialist_channels',make('@gateway_one')),a.rpc('save_my_specialist_channels',make('@gateway_two'))]);assert.equal(outcomes.filter(r=>!r.error).length,1);assert.equal(outcomes.filter(r=>r.error).length,1);assert(ok(await a.rpc('list_my_specialist_channels',{p_specialist_id:id})).channels.every(r=>!r.is_public));
 });
 await test('failure between metadata and Storage cleanup: dry-run, deletion failure, safe retry',async()=>{
  await db.query('DELETE FROM specialist_media WHERE id=$1',[photo.id]); // injected legacy partial failure, disposable only
  const before=(await db.query('SELECT count(*)::int n FROM specialist_upload_reservations')).rows[0].n;
  const dry=await gw(a,{action:'reconcile',specialist_id:id});assert(dry.dry_run);assert(dry.reservations.some(r=>r.object_name===photo.object_name&&r.object_exists&&!r.media_exists));assert.equal((await db.query('SELECT count(*)::int n FROM specialist_upload_reservations')).rows[0].n,before);
  const token=ok(await a.auth.getSession()).session.access_token;
  const injected=createMediaGateway({url:api,anonKey:anon,serviceKey:service,fetcher:(url,options)=>options?.method==='DELETE'?Promise.resolve(new Response('{}',{status:500})):fetch(url,options)});
  const req=new Request('http://isolated.test',{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({action:'delete',specialist_id:id,object_name:photo.object_name})});
  assert.equal((await injected(req)).status,409);ok(await a.storage.from('specialist-media').download(photo.object_name));
  const deleted=await gw(a,{action:'delete',specialist_id:id,object_name:photo.object_name});assert.equal(deleted.status,200);assert(deleted.deleted);
  assert((await gw(a,{action:'delete',specialist_id:id,object_name:photo.object_name})).deleted);
  assert.equal((await gw(a,body)).status,409); // tombstone prevents resurrection
 });
 await test('strict real Storage quota at19: one winner, including concurrent Edge requests',async()=>{
  for(let attempt=0;attempt<3;attempt++){
   const profile=ok(await a.rpc('create_my_specialist_draft',{p_display_name:'Gateway quota',p_slug:'gw-quota-'+attempt,p_profession:'Master'}));
   for(let i=0;i<19;i++)assert.equal((await gw(a,payload(profile.id))).status,200);
   const results=await Promise.all([gw(a,payload(profile.id)),gw(a,payload(profile.id))]);assert.equal(results.filter(r=>r.status===200).length,1,JSON.stringify(results));assert(results.some(r=>r.status===429));
   const objects=ok(await a.storage.from('specialist-media').list(profile.id+'/portfolio',{limit:100}));assert.equal(objects.length,20);
   for(const object of objects)assert((await gw(a,{action:'delete',specialist_id:profile.id,object_name:profile.id+'/portfolio/'+object.name})).deleted);
   ok(await a.rpc('delete_my_specialist_draft',{p_specialist_id:profile.id}));
  }
 });
 await test('upload versus profile deletion cannot orphan an object',async()=>{
  for(let attempt=0;attempt<3;attempt++){
   const p=ok(await a.rpc('create_my_specialist_draft',{p_display_name:'Gateway race',p_slug:'gw-delete-'+attempt,p_profession:'Master'}));
   const [uploaded,removed]=await Promise.all([gw(a,payload(p.id)),a.rpc('delete_my_specialist_draft',{p_specialist_id:p.id})]);assert(uploaded.status!==200||removed.error,'Both must not succeed');
   if(uploaded.status===200){assert((await gw(a,{action:'delete',specialist_id:p.id,object_name:uploaded.media.object_name})).deleted);ok(await a.rpc('delete_my_specialist_draft',{p_specialist_id:p.id}));}
   assert.equal((await db.query("SELECT count(*)::int n FROM storage.objects WHERE bucket_id='specialist-media' AND split_part(name,'/',1)=$1",[p.id])).rows[0].n,0);
  }
 });
 await test('unknown expired operation remains quarantined; disable/enable and company Storage unaffected',async()=>{
  const request=crypto.randomUUID();await db.query("SELECT specialist_gateway_reserve($1,$2,$3,'portfolio',$4,'image/png',68,null)",[A,id,request,'a'.repeat(64)]);
  await db.query("UPDATE specialist_upload_reservations SET expires_at=now()-interval '1 day' WHERE id=$1",[request]);
  const dry=await gw(a,{action:'reconcile',specialist_id:id});assert(dry.reservations.some(r=>r.id===request&&r.expired&&r.state==='uploading'));
  await db.query(await file('sql/release/DISABLE_MEDIA_CANDIDATE.sql'));assert.equal((await gw(a,payload())).status,503);
  ok(await a.storage.from('company-media').upload(company.id+'/logo/gateway-regression.png',bytes,{contentType:'image/png'}));
  await db.query(await file('sql/release/80_ENABLE_MEDIA_CANDIDATE.sql'));assert.equal(ok(await a.rpc('get_my_specialist_upload_capability',{p_specialist_id:id})).enabled,true);
 });
 await test('real gateway browser: services, contacts, private portfolio, reload, all sizes and keyboard focus',async()=>{
  const p=ok(await a.rpc('get_my_specialists')).find(r=>r.slug==='browser-specialist');
  await open('account-specialist-services.html?id='+p.id);await page.locator('#fields:not([disabled])').waitFor();await page.locator('#name').fill('Gateway browser service');await page.locator('#price-from').fill('1200');await page.locator('#duration').fill('45');await page.locator('#save').click();await page.locator('#items').getByText('Gateway browser service',{exact:true}).waitFor();
  await open('account-specialist-contacts.html?id='+p.id);await page.locator('#fields:not([disabled])').waitFor();await page.locator('#phone').fill('+79991234567');await page.locator('input[data-kind=telegram]').fill('@gateway_test');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();await page.reload();await page.locator('#fields:not([disabled])').waitFor();assert.equal(await page.locator('input[data-kind=telegram]').inputValue(),'@gateway_test');
  await open('account-specialist-media.html?id='+p.id);await page.locator('#fields:not([disabled])').waitFor();
  const validPng=Buffer.from(await page.evaluate(()=>{const c=document.createElement('canvas');c.width=c.height=4;return c.toDataURL('image/png').split(',')[1];}),'base64');await page.locator('#file').setInputFiles({name:'private.png',mimeType:'image/png',buffer:validPng});await page.locator('#kind').selectOption('portfolio');await page.locator('#caption').fill('Gateway private portfolio');await page.locator('#save').click();await page.locator('#items').getByText('Gateway private portfolio',{exact:true}).waitFor().catch(async e=>{throw Error('Gateway browser photo save: '+await page.locator('#status').innerText(),{cause:e});});await page.reload();await page.locator('#items img').waitFor();assert.equal(await page.locator('#items img').count(),1);
  for(const width of [320,390,768,1440]){await page.setViewportSize({width,height:900});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));for(const link of await page.locator('.editor-nav a').evaluateAll(els=>els.map(e=>e.getAttribute('href'))))assert(link==='account-home.html'||link.endsWith('?id='+p.id));}
  await page.locator('#caption').focus();await page.keyboard.press('Tab');assert.equal(await page.evaluate(()=>document.activeElement.id),'save');
  page.once('dialog',d=>d.accept());await page.locator('#items button').click();await page.locator('#status').filter({hasText:'Фотография удалена'}).waitFor();assert.equal(await page.locator('#items img').count(),0);
 });
 for(const [module,rpc,args]of [['SERVICES','get_my_specialist_services',{p_specialist_id:id}],['SETTINGS','get_my_specialist_settings',{p_specialist_id:id}],['CHANNELS','list_my_specialist_channels',{p_specialist_id:id}]]){
  await test('server capability disable/re-enable '+module,async()=>{await db.query(await file('sql/release/DISABLE_'+module+'_CANDIDATE.sql'));assert((await a.rpc(rpc,args)).error);await db.query(await file('sql/release/ENABLE_'+module+'_CANDIDATE.sql'));ok(await a.rpc(rpc,args));ok(await a.rpc('get_my_companies'));});
 }
}
