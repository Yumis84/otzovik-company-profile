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
