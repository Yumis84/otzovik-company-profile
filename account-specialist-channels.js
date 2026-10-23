import {rpc,message} from './account-specialist-api.js';
import {kinds,normalizeChannel,validateChannels} from './account-specialist-channel-rules.js';
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
export async function initChannels(id){
 const root=document.getElementById('specialist-channels');
 const form=el('form'),fields=el('fieldset'),legend=el('legend','Личные мессенджеры и социальные сети'),notice=el('p','Все контакты в этом разделе видны только вам. Публичный показ пока недоступен. Указание ссылки не подтверждает владение аккаунтом.');
 const state=el('p','Загрузка контактов…');state.setAttribute('role','status');state.setAttribute('aria-live','polite');
 const list=el('div'),add=el('button','Добавить контакт'),save=el('button','Сохранить каналы');
 fields.disabled=true;add.type='button';save.type='submit';list.className='channel-list';
 fields.append(legend,notice,list,add,save);form.append(fields);root.append(state,form);
 let rows=[],version=0,busy=false;
 const blankChannel=()=>({id:crypto.randomUUID(),kind:'telegram',value_raw:'',label:'',is_preferred:false,accepts_inquiries:false,is_public:false});
 function render(){
  list.replaceChildren();
  rows.forEach((row,index)=>{
   const box=el('fieldset'),title=el('legend','Контакт '+(index+1));box.className='channel-row';box.append(title);
   function label(text,node){const l=el('label',text);l.append(node);box.append(l);return node;}
   const type=el('select');const groups=[['Мессенджеры',['telegram','max','whatsapp']],['Социальные сети',['vk','ok']],['Сайт и портфолио',['website','portfolio']]];for(const [heading,keys] of groups){const group=el('optgroup');group.label=heading;for(const key of keys){const option=el('option',kinds[key]);option.value=key;group.append(option);}type.append(group);}type.value=row.kind;label('Мессенджер, социальная сеть или сайт',type);
   const value=el('input');value.value=row.value_raw;value.required=true;value.maxLength=500;value.autocomplete='off';value.spellcheck=false;
   const placeholders={telegram:'@username или https://t.me/username',max:'https://max.ru/…',vk:'https://vk.com/…',whatsapp:'+79991234567 или https://wa.me/79991234567',ok:'https://ok.ru/profile/…',website:'https://example.ru',portfolio:'https://example.ru/portfolio'};
   value.placeholder=placeholders[row.kind];label('Ссылка или контакт',value);
   const name=el('input');name.value=row.label;name.maxLength=80;label('Подпись (до 40 символов)',name);
   const preferred=el('input');preferred.type='checkbox';preferred.checked=row.is_preferred;label('Предпочтительный канал',preferred);
   const inquiries=el('input');inquiries.type='checkbox';inquiries.checked=row.accepts_inquiries;label('Принимаю обращения по этому каналу',inquiries);
   type.onchange=()=>{row.kind=type.value;value.placeholder=placeholders[row.kind];row.value_raw='';row.href=null;render();};
   value.oninput=()=>{row.value_raw=value.value;row.href=null;value.setCustomValidity('');};
   value.onchange=()=>{try{normalizeChannel(row.kind,row.value_raw);value.setCustomValidity('');}catch(e){value.setCustomValidity(e.message);}};
   name.oninput=()=>{row.label=name.value;};inquiries.onchange=()=>row.accepts_inquiries=inquiries.checked;
   preferred.onchange=()=>{for(const r of rows)r.is_preferred=false;row.is_preferred=preferred.checked;render();};
   if(row.href){try{if(normalizeChannel(row.kind,row.href)===row.href){const a=el('a','Открыть '+kinds[row.kind]);a.href=row.href;a.target='_blank';a.rel='noopener noreferrer nofollow ugc';box.append(a);}}catch{}}
   const actions=el('div');actions.className='channel-actions';
   for(const [text,delta] of [['Выше',-1],['Ниже',1]]){const b=el('button',text);b.type='button';b.disabled=index+delta<0||index+delta>=rows.length;b.onclick=()=>{[rows[index],rows[index+delta]]=[rows[index+delta],rows[index]];render();};actions.append(b);}
   const remove=el('button','Удалить');remove.type='button';remove.onclick=()=>{rows.splice(index,1);render();};actions.append(remove);box.append(actions);list.append(box);
  });add.disabled=rows.length>=20;
 }
 function fill(data){if(!Number.isInteger(data.version)||!Array.isArray(data.channels))throw Error('Не удалось прочитать контакты.');version=data.version;rows=data.channels;render();}
 add.onclick=()=>{if(rows.length>=20)return;rows.push(blankChannel());render();list.lastElementChild.querySelector('input').focus();};
 form.onsubmit=async e=>{
  e.preventDefault();if(busy||!form.reportValidity())return;
  let payload;try{payload=validateChannels(rows).map(({href,...row})=>row);}catch(e){state.textContent=e.message;return;}
  busy=true;fields.disabled=true;state.textContent='Сохранение…';
  try{fill(await rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:version,p_channels:payload}));state.textContent='Каналы сохранены. Доступны только вам.';}
  catch(e){state.textContent=e.code==='23505'?'Этот контакт уже добавлен.':message(e);}finally{busy=false;fields.disabled=false;}
 };
 try{fill(await rpc('list_my_specialist_channels',{p_specialist_id:id}));fields.disabled=false;if(rows.length===0){rows.push(blankChannel());render();}state.textContent='Контакты доступны только вам. Можно добавить до 20 каналов.';}
 catch(e){state.textContent=e.code==='PGRST202'||e.code==='42883'?'Мессенджеры и соцсети пока недоступны. Телефон, email и остальные поля выше можно сохранить.':message(e);}
}
