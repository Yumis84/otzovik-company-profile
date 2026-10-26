import {context,rpc,message,status} from './account-specialist-api.js';
import {text,installValidation,validateForm,fieldError} from './account-specialist-ui.js';
const form=document.getElementById('service-form'),fields=document.getElementById('fields'),items=document.getElementById('items');
installValidation(form);
let id,rows=[],selected=null,newId=crypto.randomUUID(),busy=false,pricing=false;
const el=k=>document.getElementById(k),val=k=>el(k).value;
const units={service:'за услугу',hour:'за час',lesson:'за занятие',day:'за день',square_meter:'за м²',project:'за проект'};
function priceMode(row){return row.price_mode??(row.price_from!=null||row.price_to!=null?'priced':'unspecified');}
function priceText(row){
 const mode=priceMode(row);let s=mode==='negotiated'?'По договорённости':'Цена не указана';
 if(mode==='priced'){s=row.price_from!=null&&row.price_to!=null&&row.price_from===row.price_to?String(row.price_from):[row.price_from!=null?'от '+row.price_from:'',row.price_to!=null?'до '+row.price_to:''].filter(Boolean).join(' ');s+=' '+row.currency;}
 return s+(mode!=='unspecified'&&row.price_unit&&units[row.price_unit]?' · '+units[row.price_unit]:'');
}
function clearErrors(){for(const input of form.querySelectorAll('input,textarea,select')){input.setCustomValidity('');input.removeAttribute('aria-invalid');}}
function modeUI(){const priced=!pricing||val('price-mode')==='priced';for(const k of ['price-from','price-to']){el(k).step=pricing?'0.01':'any';el(k).disabled=!priced;el(k).closest('label').hidden=!priced;el(k).setCustomValidity('');el(k).removeAttribute('aria-invalid');}el('price-mode').disabled=!pricing;el('price-unit').disabled=!pricing;}
function reset(){form.reset();clearErrors();selected=null;newId=crypto.randomUUID();el('form-title').textContent='Добавить услугу';modeUI();}
function edit(row){clearErrors();selected=row;for(const [field,key] of [['name','name'],['description','description'],['price-from','price_from'],['price-to','price_to'],['currency','currency'],['duration','duration_minutes']])el(field).value=row[key]??'';el('price-mode').value=priceMode(row);el('price-unit').value=row.price_unit??'';el('active').checked=row.is_active;el('form-title').textContent='Изменить услугу';modeUI();form.scrollIntoView({behavior:'smooth'});}
el('price-mode').onchange=modeUI;
async function load(){
 rows=await rpc('get_my_specialist_services',{p_specialist_id:id});items.replaceChildren();
 if(!rows.length)items.append(text('p','Пока нет услуг.'));
 for(const row of rows){const card=text('article','','item');card.append(text('h3',row.name),text('p',row.description),text('p',[priceText(row),row.duration_minutes?row.duration_minutes+' мин':'',row.is_active?'Доступна в черновике':'Отключена'].filter(Boolean).join(' · ')));
 const actions=text('div','','actions');for(const [label,fn] of [['Изменить',()=>edit(row)],['Удалить',async()=>{if(busy||!confirm('Удалить услугу «'+row.name+'»?'))return;busy=true;fields.disabled=true;try{await rpc('delete_my_specialist_service',{p_specialist_id:id,p_service_id:row.id,p_version:row.version});if(selected?.id===row.id)reset();await load();status('Услуга удалена.');}catch(e){status(message(e));}finally{busy=false;fields.disabled=false;modeUI();}}]]){const b=text('button',label,'secondary');b.type='button';b.onclick=()=>{if(!busy)fn();};actions.append(b);}card.append(actions);items.append(card);}
}
el('cancel').onclick=()=>{if(!busy)reset();};
el('reload-services').onclick=async()=>{if(busy||!id||!confirm('Перезагрузить услуги? Несохранённые изменения формы будут сброшены.'))return;busy=true;fields.disabled=true;try{await load();reset();status('Услуги обновлены. Выберите услугу для редактирования.');}catch(e){status(message(e));}finally{busy=false;fields.disabled=false;modeUI();}};
form.onsubmit=async e=>{
 e.preventDefault();if(busy||!id)return;if(!validateForm(form)){status('Проверьте выделенные поля.');return;}
 if(val('name').trim().length<2){fieldError(el('name'),'Название услуги — от 2 символов.');return;}
 const priced=!pricing||val('price-mode')==='priced';
 const from=priced&&val('price-from')!==''?Number(val('price-from')):null,to=priced&&val('price-to')!==''?Number(val('price-to')):null;
 if(pricing&&priced&&from===null&&to===null){fieldError(el('price-from'),'Укажите стоимость от или до.');status('Укажите стоимость или выберите другой вариант.');return;}
 if(from!==null&&to!==null&&to<from){fieldError(el('price-to'),'Стоимость «до» не может быть меньше «от».');status('Проверьте диапазон стоимости.');return;}
 const args={p_specialist_id:id,p_service_id:selected?.id||newId,p_name:val('name').trim(),p_description:val('description').trim()||null,p_price_from:from,p_price_to:to,p_currency:val('currency'),p_duration_minutes:val('duration')?Number(val('duration')):null,p_is_active:el('active').checked,p_version:selected?.version??null};
 if(pricing){args.p_price_mode=val('price-mode');args.p_price_unit=val('price-unit')||null;}
 busy=true;fields.disabled=true;status('Сохранение…');
 try{await rpc(pricing?'save_my_specialist_service_v2':'save_my_specialist_service',args);reset();await load();status('Услуга сохранена в черновике.');}
 catch(e){status(message(e));}finally{busy=false;fields.disabled=false;modeUI();}
};
try{
 id=await context('services');await load();
 try{const cap=await rpc('get_my_specialist_service_pricing',{p_specialist_id:id});if(cap?.schema_version!==2)throw Error('Неизвестная версия стоимости услуг.');pricing=true;}
 catch(e){if(!['PGRST202','42883'].includes(e?.code))throw e;pricing=false;}
 reset();fields.disabled=false;modeUI();
 el('pricing-note').textContent=pricing?'Единица стоимости необязательна.':'Новые варианты стоимости ещё не подключены. Доступна прежняя форма цены.';
 status('Изменения видны только вам.');
}catch(e){status(message(e));}
