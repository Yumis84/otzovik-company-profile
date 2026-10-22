// One presentation module for both kinds; business operations belong to adapters.
import {isUUID} from './account-profile-core.js';
export function text(tag,value,className=''){const el=document.createElement(tag);el.textContent=value??'';el.className=className;return el;}
import {renderNavigation} from './account-profile-navigation.js';
export {renderNavigation} from './account-profile-navigation.js';
export function mountCabinet(adapter,context,active){
 let header=document.querySelector('[data-cabinet-header]');
 if(!header){header=document.createElement('header');header.className='cabinet-header';header.dataset.cabinetHeader='';const row=text('div','','cabinet-header-row');const brand=text('a','отзыв','cabinet-brand');brand.href='https://отзыв.com/';brand.append(text('span','.com'));const home=text('a','ЛИЧНЫЙ КАБИНЕТ','cabinet-home');home.href='account-home.html';row.append(brand,home);header.append(row);document.body.prepend(header);}
 const main=document.querySelector('main.wrap'),nav=document.querySelector('.editor-nav');
 if(main&&nav){main.prepend(nav);main.querySelector(':scope > a.brand')?.remove();}
 header.dataset.profileKind=adapter.kind;header.dataset.profileId=context.id||'';
 renderNavigation(nav,adapter,context.id,active,context.role);
 const name=document.getElementById('profile-name');if(name)name.textContent=context.name;
}
export function status(value){const node=document.getElementById('status');if(node)node.textContent=value;}
export function message(error){return error?.code==='40001'||error?.code==='PT409'?'Данные уже изменились. Обновите страницу перед сохранением.':error?.code==='42501'?(error.message==='Черновик не найден или недоступен.'?error.message:'Нет доступа к профилю или сессия истекла.'):error?.code==='54000'?'Достигнут лимит. Удалите ненужные элементы.':['42883','PGRST202'].includes(error?.code)?'Хранилище этого раздела ещё не подключено. Сохранение отключено.':error?.code==='23505'?'Элемент уже существует. Для замены аватара сначала удалите прежний.':error?.code==='22023'||String(error?.code||'').startsWith('23')?'Проверьте поля и ограничения формы.':error?.constructor===Error&&error.message&&!error.code?error.message:'Не удалось подтвердить операцию. Обновите список перед повторной попыткой.';}
export async function optimizeImage(file){
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>20*1024*1024)throw Error('Выберите JPG, PNG или WebP до 20 МБ.');
 const bitmap=await createImageBitmap(file);if(bitmap.width*bitmap.height>40000000){bitmap.close();throw Error('Изображение слишком большое.');}
 const scale=Math.min(1,1280/Math.max(bitmap.width,bitmap.height)),c=document.createElement('canvas');c.width=Math.max(1,Math.round(bitmap.width*scale));c.height=Math.max(1,Math.round(bitmap.height*scale));c.getContext('2d').drawImage(bitmap,0,0,c.width,c.height);bitmap.close();
 const blob=await new Promise(resolve=>c.toBlob(resolve,'image/webp',.82));if(!blob||blob.size>5242880)throw Error('Не удалось подготовить файл до 5 МБ.');return blob;
}
