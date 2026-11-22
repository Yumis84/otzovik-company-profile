// Shared presentation for the existing company and specialist navigation links.
// The owning editor remains responsible for routes, authorization and visibility.
const instances=new WeakMap();let sequence=0;
export function installNavigation(nav){
 if(!nav)return;
 const existing=instances.get(nav);if(existing){existing.refresh();return;}
 if(!document.getElementById('shared-navigation-style')){
  const style=document.createElement('style');style.id='shared-navigation-style';style.textContent=`
  .shared-nav-shell{position:relative;min-width:0;max-width:100%}
  .shared-nav-shell>nav{display:flex;flex-direction:column;align-items:stretch;gap:4px;overflow:visible;max-width:100%;padding:8px;width:100%}
  .shared-nav-shell>nav a{display:block;flex:none;white-space:normal;overflow-wrap:anywhere;min-height:44px;padding:11px 13px;border-radius:9px;color:#475467;font:700 14px/1.5 system-ui;text-decoration:none}
  .shared-nav-shell>nav a:hover{background:#f2f4f7;color:#101828}
  .shared-nav-shell>nav a.active,.shared-nav-shell>nav a[aria-current=page]{background:#eaf2ff;color:#175cd3}
  .shared-nav-shell a:focus-visible,.shared-nav-toggle:focus-visible{outline:3px solid #175cd3;outline-offset:2px}
  .shared-nav-toggle{display:none;min-height:44px;padding:10px 14px;border:1px solid #d0d5dd;border-radius:10px;background:#fff;color:#344054;font:700 14px system-ui;cursor:pointer}
  .shared-nav-menu{position:absolute;z-index:30;left:0;top:calc(100% + 6px);width:min(320px,100%);max-height:min(70vh,520px);overflow:auto;padding:6px;background:#fff;border:1px solid #d0d5dd;border-radius:12px;box-shadow:0 12px 28px #10182826}
  .shared-nav-menu[hidden]{display:none!important}
  .shared-nav-menu a{display:block;min-height:44px;padding:11px 13px;border-radius:8px;color:#344054;font:700 14px/1.5 system-ui;text-decoration:none;overflow-wrap:anywhere}
  .shared-nav-menu a:hover{background:#f2f4f7}
  .shared-nav-menu a[aria-current=page]{color:#175cd3;background:#eaf2ff}
  .shared-nav-menu a:focus-visible{outline:3px solid #175cd3;outline-offset:2px}
  @media(min-width:769px){
    main.wrap:has(> .shared-nav-shell){display:grid;grid-template-columns:minmax(190px,240px) minmax(0,1fr);column-gap:24px;align-items:start}
    main.wrap:has(> .shared-nav-shell)> .shared-nav-shell{grid-column:1;grid-row:1 / span 40;position:sticky;top:20px;align-self:start;background:#fff;border:1px solid #e4e7ec;border-radius:14px}
    main.wrap:has(> .shared-nav-shell)> :not(.shared-nav-shell){grid-column:2;min-width:0}
  }
  @media(max-width:768px){.shared-nav-shell>nav{display:none}.shared-nav-toggle{display:inline-flex;align-items:center;justify-content:center}}
  @media(prefers-reduced-motion:reduce){.shared-nav-shell *{scroll-behavior:auto!important}}
  `;document.head.append(style);
 }
 const host=document.createElement('div');host.className='shared-nav-shell';nav.before(host);host.append(nav);
 const button=document.createElement('button');button.type='button';button.className='shared-nav-toggle';button.textContent='☰ Меню';button.setAttribute('aria-label','Открыть меню разделов');button.setAttribute('aria-expanded','false');
 const menu=document.createElement('div');menu.className='shared-nav-menu';menu.id='shared-nav-menu-'+(++sequence);menu.hidden=true;button.setAttribute('aria-controls',menu.id);host.insertBefore(button,nav);host.insertBefore(menu,nav);
 function refresh(){menu.replaceChildren();for(const link of nav.querySelectorAll('a')){const copy=link.cloneNode(true);copy.removeAttribute('id');copy.removeAttribute('class');if(link.matches('.active,[aria-current="page"]'))copy.setAttribute('aria-current','page');menu.append(copy);}}
 function close(focus=false){menu.hidden=true;button.setAttribute('aria-expanded','false');button.setAttribute('aria-label','Открыть меню разделов');if(focus)button.focus();}
 function reveal(link){if(!link)return;const r=link.getBoundingClientRect(),n=nav.getBoundingClientRect();nav.scrollLeft+=r.left-n.left-(nav.clientWidth-link.offsetWidth)/2;}
 button.addEventListener('click',()=>{const opening=menu.hidden;refresh();menu.hidden=!opening;button.setAttribute('aria-expanded',String(opening));button.setAttribute('aria-label',opening?'Закрыть меню разделов':'Открыть меню разделов');});
 menu.addEventListener('click',e=>{const link=e.target.closest('a');if(!link)return;const links=[...menu.querySelectorAll('a')],original=nav.querySelectorAll('a')[links.indexOf(link)];close();});
 document.addEventListener('click',e=>{if(!host.contains(e.target))close();});host.addEventListener('keydown',e=>{if(e.key==='Escape'&&!menu.hidden){e.preventDefault();close(true);}});
 host.addEventListener('focusout',e=>{if(!host.contains(e.relatedTarget))close();});
 const observer=new MutationObserver(refresh);observer.observe(nav,{childList:true,subtree:true,attributes:true,characterData:true});refresh();
 window.addEventListener('resize',()=>{if(window.innerWidth>768)close();});
 instances.set(nav,{refresh});
}
