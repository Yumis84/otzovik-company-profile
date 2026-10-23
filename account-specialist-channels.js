import {rpc,message} from './account-specialist-api.js';
import {validateChannels,normalizeChannel,phoneValue,phoneDisplayValue} from './account-specialist-channel-rules.js';
const names={telegram:'Telegram',whatsapp:'WhatsApp',max:'MAX',vk:'ВКонтакте',ok:'Одноклассники',portfolio:'Внешнее портфолио'};
const hints={telegram:'@username или https://t.me/username',whatsapp:'+79991234567',max:'https://max.ru/…',vk:'https://vk.com/…',ok:'https://ok.ru/profile/…',portfolio:'https://…'};
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
export async function initChannels(id){
 const root=document.getElementById('specialist-channels'),note=el('p');note.className='hint';note.setAttribute('role','status');root.append(note);
 let rows=[],version=0,entries=[],custom=[],available=false,editing=null;
 const blank=kind=>({id:crypto.randomUUID(),kind,value_raw:'',label:'',is_preferred:false,accepts_inquiries:false,is_public:false});
 const other=el('fieldset');other.id='other-links';other.append(el('legend','Другие ссылки'));
 const list=el('ul');list.className='other-links-list';
 const nameLabel=el('label','Название ссылки'),name=el('input');name.id='other-link-name';name.maxLength=80;name.placeholder='Например, мой блог';nameLabel.append(name);
 const urlLabel=el('label','Ссылка'),url=el('input');url.id='other-link-url';url.maxLength=500;url.placeholder='https://…';url.spellcheck=false;url.inputMode='url';urlLabel.append(url);
 const add=el('button','Добавить ссылку'),cancel=el('button','Отменить'),state=el('p');add.type=cancel.type='button';cancel.hidden=true;cancel.className='secondary';state.setAttribute('role','status');state.className='hint';
 const actions=el('div');actions.className='actions';actions.append(add,cancel);
 other.append(list,nameLabel,urlLabel,actions,state);
 // Keep the generic-link composer after the existing website, before work formats.
 document.getElementById('website').closest('label').after(other);
 function clearErrors(){for(const input of [name,url]){input.setCustomValidity('');input.removeAttribute('aria-invalid');}state.textContent='';}
 for(const input of [name,url])input.oninput=clearErrors;
 function reset(){editing=null;name.value=url.value='';add.textContent='Добавить ссылку';cancel.hidden=true;clearErrors();}
 cancel.onclick=()=>{reset();name.focus();};
 function renderCustom(){
  list.replaceChildren();
  for(const row of custom){
   const li=el('li'),link=el('a',row.label||'Сайт');link.href=normalizeChannel('website',row.value_raw);link.target='_blank';link.rel='noopener noreferrer nofollow';
   const edit=el('button','Изменить'),remove=el('button','Удалить');edit.type=remove.type='button';edit.className=remove.className='secondary';
   edit.setAttribute('aria-label','Изменить ссылку '+(row.label||'Сайт'));remove.setAttribute('aria-label','Удалить ссылку '+(row.label||'Сайт'));
   edit.onclick=()=>{editing=row.id;name.value=row.label;url.value=row.value_raw;add.textContent='Применить изменения';cancel.hidden=false;clearErrors();name.focus();};
   remove.onclick=()=>{custom=custom.filter(r=>r.id!==row.id);if(editing===row.id)reset();renderCustom();state.textContent='Ссылка удалена из списка. Сохраните контакты.';};
   const buttons=el('div');buttons.className='actions';buttons.append(edit,remove);li.append(link,buttons);list.append(li);
  }
 }
 function fail(input,text){input.setCustomValidity(text);input.setAttribute('aria-invalid','true');state.textContent=text;input.focus();input.reportValidity();return false;}
 function stagePending(){
  clearErrors();
  if(!name.value.trim()&&!url.value.trim()&&!editing)return true;
  if(!name.value.trim())return fail(name,'Укажите название ссылки.');
  if(!url.value.trim())return fail(url,'Укажите ссылку HTTPS.');
  let candidate;
  try{candidate=validateChannels([{...(custom.find(r=>r.id===editing)||blank('website')),label:name.value.trim(),value_raw:url.value}])[0];}
  catch(e){return fail([...name.value.trim()].length>40?name:url,e.message);}
  if(custom.some(r=>r.id!==candidate.id&&normalizeChannel('website',r.value_raw)===candidate.href))return fail(url,'Эта ссылка уже добавлена.');
  const fixedCount=entries.filter(({row,input})=>row.kind==='whatsapp'?phoneValue(input.value):input.value.trim()).length;
  if(fixedCount+custom.length+(editing?0:1)>20)return fail(url,'Можно сохранить до 20 контактов. Удалите ненужный контакт.');
  if(editing)custom=custom.map(r=>r.id===editing?candidate:r);else custom.push(candidate);
  reset();renderCustom();return true;
 }
 add.onclick=()=>{if(!available)return;if(!name.value.trim()&&!url.value.trim())return fail(name,'Укажите название ссылки.');if(stagePending()){state.textContent='Ссылка добавлена в список. Сохраните контакты.';name.focus();}};
 function render(){
  for(const entry of entries)entry.label.remove();entries=[];
  for(const kind of Object.keys(names)){
   const existing=rows.filter(r=>r.kind===kind),group=existing.length?existing:[blank(kind)];
   group.forEach((row,index)=>{
    const label=el('label'),input=el('input'),title=names[kind]+(index?' — дополнительный '+(index+1):'');
    label.textContent=title;input.id='channel-'+row.id;input.maxLength=500;input.value=kind==='whatsapp'?phoneDisplayValue(row.value_raw):row.value_raw;input.placeholder=hints[kind];input.autocomplete='off';input.spellcheck=false;input.dataset.kind=kind;
    if(kind==='whatsapp'){input.inputMode='tel';input.onblur=()=>{if(!input.value.trim())input.value='+7';};}
    input.oninput=()=>{input.setCustomValidity('');input.removeAttribute('aria-invalid');note.textContent='';};
    label.append(input);root.append(label);entries.push({row,input,label,title});
   });
  }
  renderCustom();
 }
 function prepare(){
  if(!available)return null;
  if(!stagePending())return false;
  const selected=[...custom],seen=new Set(custom.map(r=>r.kind+'|'+normalizeChannel(r.kind,r.value_raw)));
  for(const {row,input,title} of entries){
   input.setCustomValidity('');input.removeAttribute('aria-invalid');
   const value=row.kind==='whatsapp'?phoneValue(input.value):input.value.trim();if(!value)continue;
   try{
    const candidate=validateChannels([{...row,value_raw:value}])[0],key=candidate.kind+'|'+candidate.href;
    if(seen.has(key))throw Error('Этот контакт уже указан.');seen.add(key);selected.push(candidate);
   }catch(e){input.setCustomValidity(e.message);input.setAttribute('aria-invalid','true');note.textContent=title+': '+e.message;input.focus();input.reportValidity();return false;}
  }
  selected.sort((a,b)=>{const ia=rows.findIndex(r=>r.id===a.id),ib=rows.findIndex(r=>r.id===b.id);return (ia<0?rows.length:ia)-(ib<0?rows.length:ib);});
  try{return validateChannels(selected).map(({href,...row})=>row);}catch(e){state.textContent=e.message;return false;}
 }
 try{
  const data=await rpc('list_my_specialist_channels',{p_specialist_id:id});
  if(!Number.isInteger(data.version)||!Array.isArray(data.channels))throw Error('Не удалось прочитать контакты.');
  version=data.version;rows=data.channels;custom=rows.filter(r=>r.kind==='website');available=true;render();note.textContent='';
 }catch(e){render();for(const {input} of entries)input.disabled=true;other.disabled=true;note.textContent='Мессенджеры и соцсети пока недоступны. Остальные поля можно сохранить. '+message(e);}
 return {available,prepare,async save(payload){
  if(!available)return;
  const data=await rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:version,p_channels:payload});
  version=data.version;rows=data.channels;custom=rows.filter(r=>r.kind==='website');renderCustom();state.textContent='';
  for(const entry of entries){const stored=rows.find(r=>r.id===entry.row.id);if(stored){entry.row=stored;entry.input.value=stored.kind==='whatsapp'?phoneDisplayValue(stored.value_raw):stored.value_raw;}else{entry.row={...entry.row,value_raw:''};if(entry.row.kind==='whatsapp')entry.input.value='+7';}}
 }};
}
