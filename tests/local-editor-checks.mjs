import assert from 'node:assert/strict';
import crypto from 'node:crypto';
export async function editorChecks({a,b,anonymous,ok,company,test}){
 const draft=ok(await a.rpc('get_my_specialists')).find(x=>x.slug==='local-specialist');
 const id=draft.id;
 await test('specialist editor RPCs: owner, foreign/anon and cross-kind denial',async()=>{
  const sid=crypto.randomUUID();const params={p_specialist_id:id,p_service_id:sid,p_name:'Private specialist service',p_price_from:100,p_price_to:200,p_duration_minutes:60};
  const row=ok(await a.rpc('save_my_specialist_service',params));assert.equal(row.version,1);
  assert((await a.rpc('save_my_specialist_service',{...params,p_version:0})).error);
  ok(await a.rpc('save_my_specialist_settings',{p_specialist_id:id,p_phone:'private',p_work_formats:['online'],p_version:0}));
  assert.equal(ok(await a.rpc('get_my_specialist_settings',{p_specialist_id:id})).contact_visibility,'private');
  for(const c of [b,anonymous])for(const name of ['get_my_specialist_services','get_my_specialist_settings','get_my_specialist_media'])assert.equal((await c.rpc(name,{p_specialist_id:id})).error?.code,'42501');
  for(const name of ['get_my_specialist_services','get_my_specialist_settings','get_my_specialist_media'])assert.equal((await a.rpc(name,{p_specialist_id:company.id})).error?.code,'42501');
  assert.equal((await a.rpc('create_my_company_service',{p_company_id:id,p_name:'Wrong plane'})).error?.code,'42501');
  for(const c of [a,b,anonymous])for(const table of ['specialist_services','specialist_settings','specialist_media'])assert.equal((await c.from(table).select('*')).error?.code,'42501');
 });
 await test('real channel PostgREST private roundtrip, owner ACL, stale version and competing saves',async()=>{
  const row={id:crypto.randomUUID(),kind:'telegram',value_raw:'@local_master',label:'',is_public:false,is_preferred:false,accepts_inquiries:false};
  const read=()=>a.rpc('list_my_specialist_channels',{p_specialist_id:id});
  const save=(v,rows)=>a.rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:v,p_channels:rows});
  const initial=ok(await read());const saved=ok(await save(initial.version,[row]));assert.deepEqual(ok(await read()),saved);assert.equal(saved.channels[0].is_public,false);
  for(const c of [b,anonymous]){assert.equal((await c.rpc('list_my_specialist_channels',{p_specialist_id:id})).error?.code,'42501');assert.equal((await c.rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:saved.version,p_channels:[]})).error?.code,'42501');}
  for(const table of ['specialist_channel_sets','specialist_contact_channels'])for(const c of [a,b,anonymous])assert.equal((await c.from(table).select('*')).error?.code,'42501');
  assert.equal((await save(saved.version,[{...row,is_public:true}])).error?.code,'22023');
  const outcomes=await Promise.all(['One','Two'].map(label=>save(saved.version,[{...row,label}])));assert.equal(outcomes.filter(r=>!r.error).length,1);assert.equal(outcomes.filter(r=>r.error).length,1);
  assert((await save(initial.version,[])).error);const latest=ok(await read());assert.equal(latest.channels.length,1);assert.equal(latest.version,saved.version+1);
 });
 await test('concurrent specialist upload/delete cannot create an orphan',async()=>{
  for(let i=0;i<3;i++){
   const profile=ok(await a.rpc('create_my_specialist_draft',{p_display_name:'Race Cleanup',p_slug:'cleanup-race-'+i,p_profession:'Master'}));
   const path=profile.id+'/portfolio/'+crypto.randomUUID()+'.png',blob=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=','base64');
   const [removed,uploaded]=await Promise.all([a.rpc('delete_my_specialist_draft',{p_specialist_id:profile.id}),a.storage.from('specialist-media').upload(path,blob,{contentType:'image/png'})]);
   assert(removed.error||uploaded.error,'Both operations succeeded: orphan risk');
   if(!uploaded.error){assert.equal(removed.error?.code,'55000');ok(await a.storage.from('specialist-media').remove([path]));ok(await a.rpc('delete_my_specialist_draft',{p_specialist_id:profile.id}));}
   else assert(!removed.error,'Neither competing operation completed');
  }
 });
 await test('competing real Storage uploads at 19 objects cannot exceed quota',async()=>{
  const profile=ok(await a.rpc('create_my_specialist_draft',{p_display_name:'Quota Race',p_slug:'quota-race-editor',p_profession:'Master'}));
  const storage=a.storage.from('specialist-media'),blob=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=','base64');
  const paths=Array.from({length:21},()=>profile.id+'/portfolio/'+crypto.randomUUID()+'.png');
  for(const path of paths.slice(0,19))ok(await storage.upload(path,blob,{contentType:'image/png'}));
  const results=await Promise.all(paths.slice(19).map(path=>storage.upload(path,blob,{contentType:'image/png'})));
  assert.equal(results.filter(r=>!r.error).length,1,'Exactly one upload may claim the final slot');
  const objects=ok(await storage.list(profile.id+'/portfolio',{limit:100}));assert.equal(objects.length,20);
  for(const rpc of ['can_manage_specialist_object','can_upload_specialist_object']){
   assert.equal(ok(await b.rpc(rpc,{p_name:paths[0]})),false);
   assert.equal(ok(await a.rpc(rpc,{p_name:'invalid/avatar/x.png'})),false);
  }
  ok(await storage.remove(objects.map(x=>profile.id+'/portfolio/'+x.name)));
  ok(await a.rpc('delete_my_specialist_draft',{p_specialist_id:profile.id}));
 });
 await test('separate real specialist Storage MIME/size/owner/cross-kind policies',async()=>{
  const blob=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=','base64'),name=id+'/avatar/'+crypto.randomUUID()+'.png';
  ok(await a.storage.from('specialist-media').upload(name,blob,{contentType:'image/png'}));
  ok(await a.rpc('register_my_specialist_media',{p_specialist_id:id,p_object_name:name,p_kind:'avatar'}));
  assert.equal(ok(await a.rpc('get_my_specialist_media',{p_specialist_id:id})).length,1);
  ok(await a.storage.from('specialist-media').download(name));
  for(const c of [b,anonymous]){assert((await c.storage.from('specialist-media').download(name)).error);assert((await c.storage.from('specialist-media').createSignedUrl(name,60)).error);assert((await c.storage.from('specialist-media').upload(id+'/portfolio/'+crypto.randomUUID()+'.png',blob,{contentType:'image/png'})).error);}
  assert((await a.storage.from('specialist-media').upload(company.id+'/portfolio/'+crypto.randomUUID()+'.png',blob,{contentType:'image/png'})).error);
  assert((await a.storage.from('company-media').upload(id+'/logo/'+crypto.randomUUID()+'.png',blob,{contentType:'image/png'})).error);
  assert((await a.storage.from('specialist-media').upload(id+'/portfolio/'+crypto.randomUUID()+'.png',Buffer.alloc(5242881),{contentType:'image/png'})).error);
  assert((await a.storage.from('specialist-media').upload(id+'/portfolio/'+crypto.randomUUID()+'.png',Buffer.from('<svg/>'),{contentType:'image/svg+xml'})).error);
  assert.equal((await a.rpc('delete_my_specialist_draft',{p_specialist_id:id})).error?.code,'55000');
 });
}
export async function editorBrowser({page,open,a,ok,test}){
 const draft=ok(await a.rpc('get_my_specialists')).find(x=>x.slug==='browser-specialist');
 await test('specialist navigation, services, contacts and portfolio through real browser/Storage',async()=>{
  await open('account-create-specialist.html?id='+draft.id);await page.getByRole('link',{name:'Услуги',exact:true}).click();await page.locator('#fields:not([disabled])').waitFor();
  await page.locator('#name').fill('<img src=x onerror=alert(1)> Service');await page.locator('#price-from').fill('1200');await page.locator('#duration').fill('45');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Услуга сохранена'}).waitFor();
  await page.reload();await page.locator('#items').getByText('<img src=x onerror=alert(1)> Service',{exact:true}).waitFor();assert.equal(await page.locator('#items img').count(),0);
  await page.locator('#items').getByRole('button',{name:'Изменить',exact:true}).click();await page.locator('#price-to').fill('1800');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Услуга сохранена'}).waitFor();
  await page.getByRole('link',{name:'Контакты и работа',exact:true}).click();await page.locator('#fields:not([disabled])').waitFor();await page.locator('#phone').fill('+79991234567');await page.locator('[name=format][value=online]').check();await page.locator('#area').fill('City only');await page.locator('input[data-kind=telegram]').fill('@local_master');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();
  await page.reload();await page.locator('#fields:not([disabled])').waitFor();assert.equal(await page.locator('#phone').inputValue(),'+79991234567');assert.equal(await page.locator('input[data-kind=telegram]').inputValue(),'@local_master');const channels=ok(await a.rpc('list_my_specialist_channels',{p_specialist_id:draft.id}));assert(channels.channels.some(r=>r.kind==='telegram'&&r.href==='https://t.me/local_master'&&r.is_public===false));
  await page.getByRole('link',{name:'Фото и портфолио',exact:true}).click();await page.locator('#fields:not([disabled])').waitFor();await page.locator('#kind').selectOption('portfolio');
  const png=await page.evaluate(()=>{const c=document.createElement('canvas');c.width=c.height=4;return c.toDataURL('image/png').split(',')[1];});
  await page.locator('#file').setInputFiles({name:'private.png',mimeType:'image/png',buffer:Buffer.from(png,'base64')});await page.locator('#caption').fill('Private portfolio');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Фотография сохранена'}).waitFor();
  await page.reload();await page.locator('#items').getByText('Private portfolio',{exact:true}).waitFor();assert.equal(await page.locator('#items img').count(),1);assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  assert.deepEqual(await page.evaluate(()=>JSON.parse(sessionStorage.getItem('active_profile'))),{kind:'specialist',id:draft.id});
  for(const href of await page.locator('.editor-nav a').evaluateAll(els=>els.map(e=>e.getAttribute('href'))))assert(href==='account-home.html'||href.endsWith('?id='+draft.id));
  page.once('dialog',d=>d.accept());await page.locator('#items').getByRole('button',{name:'Удалить',exact:true}).click();await page.locator('#status').filter({hasText:'Фотография удалена'}).waitFor();
  await page.getByRole('link',{name:'Профиль',exact:true}).click();await page.locator('#save:not([disabled])').waitFor();assert.equal(await page.locator('[name=display_name]').inputValue(),draft.display_name);

 });
}
