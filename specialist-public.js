import {publishedPhotoLoader} from './specialist-public-media.js';
import {createClient} from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm';
const sb=createClient('https://salmcnhexlftrgtiryyo.supabase.co','sb_publishable_W-trkanJIam4TdhADQkbzw_ngISUVv6',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
const status=document.getElementById('status'),profile=document.getElementById('profile');
function text(tag,value){const el=document.createElement(tag);el.textContent=value??'';return el;}
const slug=new URLSearchParams(location.search).get('slug');
const photos=publishedPhotoLoader({endpoint:'https://salmcnhexlftrgtiryyo.supabase.co/functions/v1/specialist-media-gateway',anonKey:'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhbG1jbmhleGxmdHJndGlyeXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIyNjIyOTAsImV4cCI6MjEwNzgzODI5MH0.jCoAeqmptuPO9K1MZbfAYUkCBgc_DqxABVgrsDMGHk0'});
let active=true;
addEventListener('pagehide',()=>{active=false;photos.dispose();},{once:true});
addEventListener('pageshow',event=>{if(event.persisted)location.reload();});
function sectionVisibility(sectionId,itemsId){
 const empty=!document.getElementById(itemsId).childElementCount;
 document.getElementById(sectionId).hidden=empty;
 const link=document.querySelector('.profile-nav a[href="#'+sectionId+'"]');if(link)link.hidden=empty;
}
async function showPhoto(item){
 const resource=await photos.load(slug,item.id);if(!resource)return false;
 if(!active){resource.release();return false;}
 const img=document.createElement('img');img.alt=item.caption||(item.kind==='avatar'?'Аватар специалиста':'Работа специалиста');img.src=resource.url;
 try{await img.decode();}catch{resource.release();return false;}
 if(!active){resource.release();return false;}
 if(item.kind==='avatar')document.getElementById('avatar').replaceChildren(img);
 else {const figure=document.createElement('figure');figure.append(img);if(item.caption)figure.append(text('figcaption',item.caption));document.getElementById('portfolio').append(figure);document.getElementById('media-note').hidden=true;sectionVisibility('media','portfolio');}
 return true;
}
try{
 if(!slug||!/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/.test(slug)||slug.includes('--'))throw Error('Адрес профиля указан неверно.');
 const {data,error}=await sb.rpc('get_public_specialist_v1',{p_slug:slug});
 if(error)throw Error('Не удалось загрузить профиль. Обновите страницу.');
 if(!data){status.textContent='Профиль пока недоступен.';}
 else{
 for(const [id,key] of [['name','display_name'],['profession','profession'],['specialization','specialization'],['city','city'],['description','description']])document.getElementById(id).textContent=data[key]??'';document.getElementById('avatar').textContent=(data.display_name||'').slice(0,1);
 const photoTasks=[];
 for(const item of data.items??[]){
 if(item?.type==='photo'&&['avatar','portfolio'].includes(item.kind)){photoTasks.push(showPhoto(item));continue;}
 const card=document.createElement('article');
 if(item.type==='service'){card.append(text('h2',item.name),text('p',item.description));if(item.from!=null||item.to!=null)card.append(text('p',[item.from!=null?'от '+item.from:'',item.to!=null?'до '+item.to:'',item.currency].filter(Boolean).join(' ')));}
 else if(item.type==='contact'){try{const url=new URL(item.href);if(!['https:','mailto:','tel:'].includes(url.protocol))continue;const a=text('a',item.label);a.href=url.href;a.rel='noopener noreferrer';card.append(a);}catch{continue;}}
 else continue;
 document.getElementById(item.type==='service'?'service-items':'contact-items').append(card);
 }
 for(const [sectionId,itemsId] of [['services','service-items'],['contacts','contact-items'],['media','portfolio']]){
 const empty=!document.getElementById(itemsId).childElementCount;
 document.getElementById(sectionId).hidden=empty;
 const link=document.querySelector('.profile-nav a[href="#'+sectionId+'"]');
 if(link)link.hidden=empty;
 }
 profile.hidden=false;status.hidden=true;document.title=data.display_name+' — Отзыв.com';
 if(photoTasks.length)void Promise.all(photoTasks).then(results=>{
  if(!active||results.every(Boolean))return;
  const notice=text('p','Некоторые опубликованные фотографии временно недоступны.');notice.className='wrap muted';notice.setAttribute('role','status');profile.prepend(notice);
 });
 }
}catch(e){status.textContent=e.message;}
