import {isUUID} from './account-profile-core.js';
import {sectionsFor} from './account-profile-sections.js';
const disposers=new WeakMap();let sequence=0;
export function renderNavigation(node,adapter,id,active='profile',role='owner'){
 if(!node)return;
 disposers.get(node)?.();node.replaceChildren();node.classList.add('profile-navigation');node.dataset.profileKind=adapter.kind;
 const items=sectionsFor(adapter.kind).filter(item=>adapter.visible(item.key,role));
 const current=sectionsFor(adapter.kind).find(item=>item.key===active);
 function link(item,primary=false){
  const a=document.createElement(isUUID(id)?'a':'span');a.textContent=primary?item.primaryLabel:item.label;a.dataset.section=item.key;
  if(isUUID(id)){const params=new URLSearchParams({[adapter.idKey]:id});if(item.route==='account-specialist-section.html')params.set('section',item.key);a.href=item.route+'?'+params;}else a.setAttribute('aria-disabled','true');
  if(item.key===active){a.className='active';a.setAttribute('aria-current','page');}return a;
 }
 const primary=document.createElement('div');primary.className='profile-nav-primary';for(const item of items.filter(x=>x.primary))primary.append(link(item,true));
 const toggle=document.createElement('button');toggle.type='button';toggle.className='profile-nav-toggle';toggle.textContent='Все разделы';
 const list=document.createElement('div');list.className='profile-nav-list';list.id='profile-sections-'+(++sequence);toggle.setAttribute('aria-controls',list.id);for(const item of items)list.append(link(item));
 const label=document.createElement('p');label.className='profile-nav-current';label.textContent='Текущий раздел: '+(current?.label||'Настройки');
 node.append(primary,toggle,label,list);
 const media=matchMedia('(max-width: 640px)');let expanded=false;
 function sync(){primary.hidden=!media.matches;toggle.hidden=!media.matches;label.hidden=!!current?.primary;list.hidden=media.matches&&!expanded;toggle.setAttribute('aria-expanded',String(media.matches&&expanded));node.dataset.expanded=String(media.matches&&expanded);}
 function close(focus=false){expanded=false;sync();if(focus)toggle.focus();}
 function clicked(event){if(event.target.closest('a'))close();}
 function outside(event){if(expanded&&!node.contains(event.target))close();}
 function keyboard(event){if(event.key==='Escape'&&expanded){event.preventDefault();close(true);}}
 toggle.addEventListener('click',()=>{expanded=!expanded;sync();});list.addEventListener('click',clicked);document.addEventListener('click',outside);node.addEventListener('keydown',keyboard);media.addEventListener('change',sync);sync();
 disposers.set(node,()=>{document.removeEventListener('click',outside);media.removeEventListener('change',sync);node.removeEventListener('keydown',keyboard);});
}
