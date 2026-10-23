// Pure specialist UI helpers. No company context, RPC or storage.
export const isUUID=id=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id||'');
export function navigation(node,id,active='profile',name=''){
 node.replaceChildren();
 const items=[['home','Мои профили','account-home.html'],['profile','Профиль','account-create-specialist.html'],...(isUUID(id)?[['services','Услуги','account-specialist-services.html'],['media','Фото и портфолио','account-specialist-media.html'],['contacts','Контакты и работа','account-specialist-contacts.html']]:[])];
 for(const [key,label,file] of items){const a=document.createElement('a');a.textContent=label;a.href=key==='home'?file:isUUID(id)?file+'?id='+encodeURIComponent(id):'#profile';if(key===active){a.className='active';a.setAttribute('aria-current','page');}node.append(a);}
 const plaque=document.getElementById('specialist-context');if(plaque){plaque.hidden=!isUUID(id);plaque.replaceChildren();if(isUUID(id)){const label=document.createElement('small');label.textContent='Редактируется специалист';const strong=document.createElement('strong');strong.textContent=name;plaque.append(label,strong);}}
}
export function text(tag,value,className=''){const el=document.createElement(tag);el.textContent=value??'';el.className=className;return el;}
export async function optimizeImage(file){
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>20*1024*1024)throw Error('Выберите JPG, PNG или WebP до 20 МБ.');
 const bitmap=await createImageBitmap(file);if(bitmap.width*bitmap.height>40000000){bitmap.close();throw Error('Изображение слишком большое.');}
 const scale=Math.min(1,1280/Math.max(bitmap.width,bitmap.height)),c=document.createElement('canvas');c.width=Math.max(1,Math.round(bitmap.width*scale));c.height=Math.max(1,Math.round(bitmap.height*scale));c.getContext('2d').drawImage(bitmap,0,0,c.width,c.height);bitmap.close();
 const blob=await new Promise(resolve=>c.toBlob(resolve,'image/webp',.82));if(!blob||blob.size>5242880)throw Error('Не удалось подготовить файл до 5 МБ.');return blob;
}

/** Native validation with persistent accessible indication (specialist forms only). */
export function installValidation(form){
 form.noValidate=true;
 form.addEventListener('invalid',event=>event.target.setAttribute('aria-invalid','true'),true);
 form.addEventListener('input',event=>{const field=event.target;if(typeof field.setCustomValidity==='function'){field.setCustomValidity('');field.removeAttribute('aria-invalid');}});
}
export function fieldError(field,message){
 field.setCustomValidity(message);field.setAttribute('aria-invalid','true');
 field.focus();field.reportValidity();return false;
}
export function validateForm(form){
 for(const field of form.querySelectorAll('input,textarea,select')){
  if(field.disabled||!field.willValidate)continue;
  if(field.required&&['text','textarea'].includes(field.type)&&!field.value.trim())field.setCustomValidity('Заполните это поле.');
  if(field.checkValidity())field.removeAttribute('aria-invalid');
 }
 if(form.checkValidity())return true;
 const first=form.querySelector(':invalid:not(fieldset)');
 if(first){first.focus();first.reportValidity();}return false;
}

/** Saved-data overview only. It never changes publication or writes profile data. */
export function createSavedSummary(root,rpc){
 let revision=0;
 const heading=text('summary','Заполнение профиля'),list=text('ul','');
 const footer=text('p','Профиль остаётся приватным. Условия публикации будут определены отдельно.','hint');
 list.setAttribute('aria-live','polite');root.replaceChildren(heading,list,footer);
 list.append(text('li','Сначала сохраните профиль, затем здесь появится сводка сохранённых сведений.'));
 return {async load(id,profile){
  const current=++revision;list.replaceChildren(text('li','Проверяем сохранённые сведения…'));
  const result=await Promise.allSettled([
   rpc('get_my_specialist_services',{p_specialist_id:id}).then(x=>{if(!Array.isArray(x))throw Error();return x;}),
   rpc('get_my_specialist_media',{p_specialist_id:id}).then(x=>{if(!Array.isArray(x))throw Error();return x;}),
   rpc('get_my_specialist_settings',{p_specialist_id:id}).then(x=>{if(!x||!Number.isInteger(x.version))throw Error();return x;}),
   rpc('list_my_specialist_channels',{p_specialist_id:id}).then(x=>{if(!x||!Array.isArray(x.channels)||!Number.isInteger(x.version))throw Error();return x;})
  ]);
  if(current!==revision)return;
  const rows=['Основные сведения: сохранены.','Описание: '+(String(profile.description??'').trim()?'заполнено.':'пока не заполнено.')];
  rows.push('Услуги: '+(result[0].status==='fulfilled'?result[0].value.length:'не удалось проверить')+'.');
  rows.push('Фотографии: '+(result[1].status==='fulfilled'?result[1].value.length:'не удалось проверить')+'.');
  if(result[2].status==='fulfilled'&&result[3].status==='fulfilled'){
   const s=result[2].value,filled=!!(s.phone||s.email||s.website||result[3].value.channels.length);
   rows.push('Контакты: '+(filled?'сохранены приватно.':'пока не заполнены.'));
  }else rows.push('Контакты: не удалось проверить.');
  list.replaceChildren(...rows.map(value=>text('li',value)));
 }};
}
