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
  await page.getByRole('link',{name:'Контакты и работа',exact:true}).click();await page.locator('#fields:not([disabled])').waitFor();await page.locator('#phone').fill('+7 private');await page.locator('[name=format][value=online]').check();await page.locator('#area').fill('City only');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Контакты сохранены'}).waitFor();
  await page.reload();await page.locator('#fields:not([disabled])').waitFor();assert.equal(await page.locator('#phone').inputValue(),'+7 private');
  await page.getByRole('link',{name:'Фото и портфолио',exact:true}).click();await page.locator('#fields:not([disabled])').waitFor();await page.locator('#kind').selectOption('portfolio');
  const png=await page.evaluate(()=>{const c=document.createElement('canvas');c.width=c.height=4;return c.toDataURL('image/png').split(',')[1];});
  await page.locator('#file').setInputFiles({name:'private.png',mimeType:'image/png',buffer:Buffer.from(png,'base64')});await page.locator('#caption').fill('Private portfolio');await page.locator('#save').click();await page.locator('#status').filter({hasText:'Фотография сохранена'}).waitFor();
  await page.reload();await page.locator('#items').getByText('Private portfolio',{exact:true}).waitFor();assert.equal(await page.locator('#items img').count(),1);assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  assert.deepEqual(await page.evaluate(()=>JSON.parse(sessionStorage.getItem('active_profile'))),{kind:'specialist',id:draft.id});
  for(const href of await page.locator('.editor-nav a').evaluateAll(els=>els.map(e=>e.getAttribute('href'))))assert(href.endsWith('?id='+draft.id));
 });
}
