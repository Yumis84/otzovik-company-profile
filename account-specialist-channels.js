import {rpc,message} from './account-specialist-api.js';
import {validateChannels,phoneValue,phoneDisplayValue} from './account-specialist-channel-rules.js';
const names={telegram:'Telegram',whatsapp:'WhatsApp',max:'MAX',vk:'ВКонтакте',ok:'Одноклассники',portfolio:'Внешнее портфолио'};
const hints={telegram:'@username или https://t.me/username',whatsapp:'+79991234567',max:'https://max.ru/…',vk:'https://vk.com/…',ok:'https://ok.ru/profile/…',portfolio:'https://…',website:'https://…'};
export async function initChannels(id){
 const root=document.getElementById('specialist-channels');
 const note=document.createElement('p');note.className='hint';note.setAttribute('role','status');note.setAttribute('aria-live','polite');root.append(note);
 let rows=[],version=0,entries=[],available=false;
 const blank=kind=>({id:crypto.randomUUID(),kind,value_raw:'',label:'',is_preferred:false,accepts_inquiries:false,is_public:false});
 function render(){
  for(const entry of entries)entry.label.remove();entries=[];
  // Keep all existing contacts, IDs and metadata, including additional contacts of one kind.
  for(const kind of Object.keys(names).concat('website')){
   const existing=rows.filter(r=>r.kind===kind);
   const group=existing.length?existing:kind==='website'?[]:[blank(kind)];
   group.forEach((row,index)=>{
    const label=document.createElement('label');const input=document.createElement('input');
    const title=kind==='website'?'Дополнительный сайт (ранее сохранён)':names[kind]+(index?' — дополнительный '+(index+1):'');
    label.textContent=title;input.id='channel-'+row.id;input.type='text';input.maxLength=500;input.value=kind==='whatsapp'?phoneDisplayValue(row.value_raw):row.value_raw;input.placeholder=hints[kind];input.autocomplete='off';input.spellcheck=false;input.dataset.kind=kind;
    if(kind==='whatsapp'){input.inputMode='tel';input.onblur=()=>{if(!input.value.trim())input.value='+7';};}
    input.oninput=()=>{input.setCustomValidity('');input.removeAttribute('aria-invalid');note.textContent='';};
    label.append(input);root.append(label);entries.push({row,input,label,title});
   });
  }
 }
 function prepare(){
  if(!available)return null;
  const selected=[];const seen=new Set();
  for(const {row,input,title} of entries){
   input.setCustomValidity('');input.removeAttribute('aria-invalid');
   const value=row.kind==='whatsapp'?phoneValue(input.value):input.value.trim();
   if(!value)continue;
   try{
    const candidate=validateChannels([{...row,value_raw:value}])[0];
    const key=candidate.kind+'|'+candidate.href;if(seen.has(key))throw Error('Этот контакт уже указан.');seen.add(key);
    selected.push(candidate);
   }catch(e){input.setCustomValidity(e.message);input.setAttribute('aria-invalid','true');note.textContent=title+': '+e.message;input.focus();input.reportValidity();return false;}
  }
  selected.sort((a,b)=>{const ia=rows.findIndex(r=>r.id===a.id),ib=rows.findIndex(r=>r.id===b.id);return (ia<0?rows.length:ia)-(ib<0?rows.length:ib);});
  try{return validateChannels(selected).map(({href,...row})=>row);}catch(e){note.textContent=e.message;return false;}
 }
 try{
  const data=await rpc('list_my_specialist_channels',{p_specialist_id:id});
  if(!Number.isInteger(data.version)||!Array.isArray(data.channels))throw Error('Не удалось прочитать контакты.');
  version=data.version;rows=data.channels;available=true;render();note.textContent='';
 }catch(e){
  render();for(const {input} of entries)input.disabled=true;
  note.textContent='Мессенджеры и соцсети пока недоступны. Остальные поля можно сохранить. '+message(e);
 }
 return {available,prepare,async save(payload){
  if(!available)return;
  const data=await rpc('save_my_specialist_channels',{p_specialist_id:id,p_version:version,p_channels:payload});
  version=data.version;rows=data.channels;
  for(const entry of entries){const stored=rows.find(r=>r.id===entry.row.id);if(stored){entry.row=stored;entry.input.value=stored.kind==='whatsapp'?phoneDisplayValue(stored.value_raw):stored.value_raw;}else{entry.row={...entry.row,value_raw:''};if(entry.row.kind==='whatsapp')entry.input.value='+7';}}
 }};
}
