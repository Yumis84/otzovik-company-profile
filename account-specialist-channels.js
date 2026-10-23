import {rpc,message} from './account-specialist-api.js';
import {kinds,normalizeChannel,validateChannels} from './account-specialist-channel-rules.js';
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
export async function initChannels(id){
 const root=document.getElementById('specialist-channels');
 const form=el('form'),fields=el('fieldset'),legend=el('legend','Мессенджеры, соцсети и ссылки'),notice=el('p','Контакты видны только вам.');
 const state=el('p','Загрузка контактов…');state.setAttribute('role','status');state.setAttribute('aria-live','polite');
 const list=el('div'),actions=el('div'),add=el('button','Добавить контакт'),save=el('button','Сохранить контакты');
 fields.disabled=true;add.type='button';add.className='secondary';save.type='submit';list.className='channel-list';actions.className='channel-form-actions';
 actions.append(add,save);fields.append(legend,notice,list,actions);form.append(fields);root.append(state,form);
 let rows=[],version=0,busy=false;
 const blankChannel=()=>({id:crypto.randomUUID(),kind:'telegram',value_raw:'',label:'',is_preferred:false,accepts_inquiries:false,is_public:false});
 const placeholders={telegram:'@username или https://t.me/username',max:'Ссылка на профиль MAX',vk:'https://vk.com/…',whatsapp:'+79991234567',ok:'https://ok.ru/profile/…',website:'https://example.ru',portfolio:'Ссылка на портфолио (https://…)'};
 function render(){
  list.replaceChildren();
  rows.forEach((row,index)=>{
   const box=el('div');box.className='channel-row';box.setAttribute('role','group');box.setAttribute('aria-label','Контакт '+(index+1));
   const type=el('select');type.setAttribute('aria-label','Канал '+(index+1));
   for(const [heading,keys] of [['Мессенджеры',['telegram','max','whatsapp']],['Социальные сети',['vk','ok']],['Сайт и портфолио',['website','portfolio']]]){
    const group=el('optgroup');group.label=heading;for(const key of keys){const option=el('option',kinds[key]);option.value=key;group.append(option);}type.append(group);
   }
   type.value=row.kind;
   const value=el('input');value.value=row.value_raw;value.required=true;value.maxLength=500;value.autocomplete='off';value.spellcheck=false;value.placeholder=placeholders[row.kind];value.setAttribute('aria-label',kinds[row.kind]+': контакт');value.className='channel-value';
   type.onchange=()=>{row.kind=type.value;row.value_raw='';row.href=null;render();list.children[index].querySelector('select').focus();};
   value.oninput=()=>{row.value_raw=value.value;row.href=null;value.setCustomValidity('');};
   value.onchange=()=>{try{normalizeChannel(row.kind,row.value_raw);value.setCustomValidity('');}catch(e){value.setCustomValidity(e.message);}};
   const remove=el('button','×');remove.type='button';remove.className='channel-remove';remove.setAttribute('aria-label','Удалить контакт '+(index+1));remove.title='Удалить контакт';
   remove.onclick=()=>{rows.splice(index,1);render();(list.children[Math.min(index,rows.length-1)]?.querySelector('select')||add).focus();};
   box.append(type,value,remove);list.append(box);
  });add.disabled=rows.length>=20;
 }
 function fill(data){if(!Number.isInteger(data.version)||!Array.isArray(data.channels))throw Error('Не удалось прочитать контакты.');version=data.version;rows=data.channels;render();}
 add.onclick=()=>{if(rows.length>=20)return;rows.push(blankChannel());render();list.lastElementChild.querySelector('input').focus();};
 form.onsubmit=async e=>{
  e.preventDefault();if(busy||!form.reportValidity())return;
  let payload;try{payload=validateChannels(rows).map(({href,...row})=>row);}catch(e){state.textContent=e.message;return;}
  busy=true;fields.disabled=true;state.textContent='Сохранение…';
  try{fill(await rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:version,p_channels:payload}));state.textContent='Контакты сохранены. Доступны только вам.';}
  catch(e){state.textContent=e.code==='23505'?'Этот контакт уже добавлен.':message(e);}finally{busy=false;fields.disabled=false;}
 };
 try{fill(await rpc('list_my_specialist_channels',{p_specialist_id:id}));fields.disabled=false;if(rows.length===0){rows.push(blankChannel());render();}state.textContent='';}
 catch(e){state.textContent=e.code==='PGRST202'||e.code==='42883'?'Мессенджеры и соцсети пока недоступны. Телефон, email и остальные поля выше можно сохранить.':message(e);}
}
