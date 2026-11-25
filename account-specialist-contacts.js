import {installValidation,validateForm} from './account-specialist-ui.js';
import {initChannels} from './account-specialist-channels.js';
import {prepareChannelValue,phoneValue,phoneDisplayValue} from './account-specialist-channel-rules.js';
import {context,rpc,message,status} from './account-specialist-api.js';
const form=document.getElementById('contacts-form'),fields=document.getElementById('fields');let id,version=0,busy=false,channels,baseline='';
installValidation(form);
const mapping={phone:'phone',email:'email',website:'website',area:'service_area',qualifications:'qualifications'};
function values(){const args={p_work_formats:[...form.querySelectorAll('[name=format]:checked')].map(x=>x.value)};for(const [key,prop] of Object.entries(mapping))args['p_'+prop]=(key==='phone'?phoneValue(document.getElementById(key).value):document.getElementById(key).value.trim())||null;return args;}
function fill(data){version=data.version;for(const [key,prop] of Object.entries(mapping))document.getElementById(key).value=key==='phone'?phoneDisplayValue(data[prop]):data[prop]??'';for(const c of form.querySelectorAll('[name=format]'))c.checked=data.work_formats.includes(c.value);baseline=JSON.stringify(values());}
const phone=document.getElementById('phone');phone.autocomplete='tel';phone.onblur=()=>{if(!phone.value.trim())phone.value='+7';};
const website=document.getElementById('website');website.oninput=()=>{website.setCustomValidity('');website.removeAttribute('aria-invalid');};
form.onsubmit=async e=>{
 e.preventDefault();if(busy||!id||!channels||fields.dataset.uncertain)return;
 website.setCustomValidity('');website.removeAttribute('aria-invalid');
 const raw=prepareChannelValue(website.value);
 if(raw)try{const url=new URL(raw);if(url.protocol!=='https:'||!url.hostname||url.username||url.password||/[\x00-\x20\x7f]/.test(raw))throw Error();}catch{const text='Укажите полную ссылку на сайт, начинающуюся с https://.';website.setCustomValidity(text);website.setAttribute('aria-invalid','true');website.focus();website.reportValidity();status('Сайт: '+text);return;}
 const payload=channels.prepare();if(payload===false||!validateForm(form))return;
 website.value=raw;
 const args=values(),changed=JSON.stringify(args)!==baseline;
 busy=true;fields.disabled=true;form.setAttribute('aria-busy','true');status('Сохраняем…');let legacySaved=false;
 try{
  if(changed){let saved=await rpc('save_my_specialist_settings',{p_specialist_id:id,p_version:version,...args});if(!saved||!Number.isInteger(saved.version)||!Array.isArray(saved.work_formats)){const verified=await rpc('get_my_specialist_settings',{p_specialist_id:id});const same=verified&&Number.isInteger(verified.version)&&verified.version>version&&Array.isArray(verified.work_formats)&&JSON.stringify([...verified.work_formats].sort())===JSON.stringify([...args.p_work_formats].sort())&&Object.entries(mapping).every(([key,prop])=>(verified[prop]??null)===(args['p_'+prop]??null));if(!same){fields.dataset.uncertain='true';throw Error('Не удалось подтвердить сохранение основных полей. Обновите страницу перед повторной попыткой.');}saved=verified;}fill(saved);legacySaved=true;}
  await channels.save(payload);
  status(channels.available?'Контакты сохранены. Доступны только вам.':'Основные поля сохранены. Мессенджеры и соцсети недоступны и не изменены.');
 }catch(e){if(e.uncertainSave)fields.dataset.uncertain='true';status((legacySaved?'Основные поля сохранены, но мессенджеры и соцсети не сохранены. ':'Контакты не сохранены. ')+message(e));}
 finally{busy=false;fields.disabled=fields.dataset.uncertain==='true';form.removeAttribute('aria-busy');}
};
const retry=document.createElement('button');retry.type='button';retry.id='retry-contacts';retry.textContent='Повторить загрузку контактов';retry.hidden=true;document.getElementById('status').after(retry);let loading=false;async function initialize(){if(loading||channels)return;loading=true;retry.disabled=true;try{if(!id)id=await context('contacts');const data=await rpc('get_my_specialist_settings',{p_specialist_id:id});if(!data||!Number.isInteger(data.version)||!Array.isArray(data.work_formats))throw Error('Не удалось загрузить настройки. Повторите попытку.');fill(data);channels=await initChannels(id);fields.disabled=false;retry.hidden=true;status('Контакты: только вам. Пустые поля заполнять необязательно.');}catch(e){fields.disabled=true;retry.hidden=false;status(message(e));}finally{loading=false;retry.disabled=false;}}retry.onclick=initialize;await initialize();
