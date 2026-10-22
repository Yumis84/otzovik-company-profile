// Pure specialist UI helpers. No company context, RPC or storage.
export const isUUID=id=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id||'');
export function navigation(node,id,active='profile'){
 node.replaceChildren();
 const items=[['profile','Профиль','account-specialist-profile.html'],['services','Услуги и цены','account-specialist-services.html'],['media','Фото и портфолио','account-specialist-media.html'],['contacts','Контакты и работа','account-specialist-contacts.html'],['reviews','Отзывы и ответы'],['questions','Вопросы пользователей'],['sources','Источники рейтингов'],['analytics','Аналитика'],['notifications','Уведомления'],['assistant','ИИ-ассистент'],['mcp','Мой ИИ-агент · MCP'],['settings','Настройки и публикация']];
 for(const [key,label,file] of items){const a=document.createElement(isUUID(id)?'a':'span');a.textContent=label;if(isUUID(id))a.href=(file||'account-specialist-section.html')+'?id='+encodeURIComponent(id)+(file?'':'&section='+key);else a.setAttribute('aria-disabled','true');if(key===active){a.className='active';a.setAttribute('aria-current','page');}node.append(a);}
 // As in the company menu, wait for layout and reveal the active tab once.
 // Scroll only this menu so the page position and subsequent manual scrolling stay intact.
 requestAnimationFrame(()=>requestAnimationFrame(()=>{
  const current=node.querySelector('a[aria-current="page"]');
  if(!node.isConnected||!current)return;
  const left=node.scrollLeft+current.getBoundingClientRect().left-node.getBoundingClientRect().left-node.clientLeft-(node.clientWidth-current.offsetWidth)/2;
  node.scrollTo({left:Math.min(Math.max(0,node.scrollWidth-node.clientWidth),Math.max(0,left)),behavior:'auto'});
 }));
}
export function text(tag,value,className=''){const el=document.createElement(tag);el.textContent=value??'';el.className=className;return el;}
export async function optimizeImage(file){
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>20*1024*1024)throw Error('Выберите JPG, PNG или WebP до 20 МБ.');
 const bitmap=await createImageBitmap(file);if(bitmap.width*bitmap.height>40000000){bitmap.close();throw Error('Изображение слишком большое.');}
 const scale=Math.min(1,1280/Math.max(bitmap.width,bitmap.height)),c=document.createElement('canvas');c.width=Math.max(1,Math.round(bitmap.width*scale));c.height=Math.max(1,Math.round(bitmap.height*scale));c.getContext('2d').drawImage(bitmap,0,0,c.width,c.height);bitmap.close();
 const blob=await new Promise(resolve=>c.toBlob(resolve,'image/webp',.82));if(!blob||blob.size>5242880)throw Error('Не удалось подготовить файл до 5 МБ.');return blob;
}
