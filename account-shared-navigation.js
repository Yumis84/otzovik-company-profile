// Shared presentation for the existing company and specialist navigation links.
// The owning editor remains responsible for routes, authorization and visibility.
const instances=new WeakMap();let sequence=0;
export function installNavigation(nav){
 if(!nav)return;
 const existing=instances.get(nav);if(existing){existing.refresh();return;}
 if(!document.getElementById('shared-navigation-style')){
  const style=document.createElement('style');style.id='shared-navigation-style';style.textContent=`
  .shared-nav-shell{position:relative;min-width:0;max-width:100%}
  .shared-nav-shell>nav{display:flex;flex-wrap:nowrap;gap:7px;overflow-x:auto;overflow-y:hidden;max-width:100%;scrollbar-width:none;overscroll-behavior-inline:contain;-webkit-overflow-scrolling:touch}
  .shared-nav-shell>nav::-webkit-scrollbar{display:none}
  .shared-nav-shell>nav a{flex:none;white-space:nowrap}
  .shared-nav-toggle{position:absolute;right:0;top:0;min-height:44px;padding:8px 10px;border:1px solid #d0d5dd;border-radius:9px;background:#fff;color:#344054;font:700 14px system-ui;cursor:pointer}
  .shared-nav-menu{position:absolute;z-index:30;right:0;top:48px;max-height:min(65vh,480px);overflow:auto;width:min(280px,100%);padding:6px;background:white;border:1px solid #d0d5dd;border-radius:10px;box-shadow:0 6px 20px #10182826}
  .shared-nav-menu[hidden]{display:none!important}.shared-nav-menu a{display:block;min-height:44px;padding:11px;border-radius:8px;color:#344054;font:700 14px system-ui;text-decoration:none;white-space:normal}.shared-nav-menu a[aria-current=page]{color:#175cd3;background:#eaf2ff}.shared-nav-menu a:focus-visible,.shared-nav-toggle:focus-visible{outline:2px solid #175cd3;outline-offset:2px}
  .shared-nav-shell>nav{padding-right:0;width:calc(100% - 94px);min-height:48px;align-items:center}
  `;document.head.append(style);
 }
 const host=document.createElement('div');host.className='shared-nav-shell';nav.before(host);host.append(nav);
 const button=document.createElement('button');button.type='button';button.className='shared-nav-toggle';button.textContent='☰ Меню';button.setAttribute('aria-expanded','false');
 const menu=document.createElement('div');menu.className='shared-nav-menu';menu.id='shared-nav-menu-'+(++sequence);menu.hidden=true;button.setAttribute('aria-controls',menu.id);host.insertBefore(button,nav);host.insertBefore(menu,nav);
 function refresh(){menu.replaceChildren();for(const link of nav.querySelectorAll('a')){const copy=link.cloneNode(true);copy.removeAttribute('id');copy.removeAttribute('class');if(link.matches('.active,[aria-current="page"]'))copy.setAttribute('aria-current','page');menu.append(copy);}}
 function close(focus=false){menu.hidden=true;button.setAttribute('aria-expanded','false');if(focus)button.focus();}
 function reveal(link){if(!link)return;const r=link.getBoundingClientRect(),n=nav.getBoundingClientRect();nav.scrollLeft+=r.left-n.left-(nav.clientWidth-link.offsetWidth)/2;}
 button.addEventListener('click',()=>{const opening=menu.hidden;refresh();menu.hidden=!opening;button.setAttribute('aria-expanded',String(opening));});
 menu.addEventListener('click',e=>{const link=e.target.closest('a');if(!link)return;const links=[...menu.querySelectorAll('a')],original=nav.querySelectorAll('a')[links.indexOf(link)];reveal(original);close();});
 document.addEventListener('click',e=>{if(!host.contains(e.target))close();});host.addEventListener('keydown',e=>{if(e.key==='Escape'&&!menu.hidden){e.preventDefault();close(true);}});
 host.addEventListener('focusout',e=>{if(!host.contains(e.relatedTarget))close();});
 const observer=new MutationObserver(refresh);observer.observe(nav,{childList:true,subtree:true,attributes:true,characterData:true});refresh();
 const revealCurrent=()=>requestAnimationFrame(()=>reveal(nav.querySelector('.active,[aria-current="page"]')));
 window.addEventListener('resize',revealCurrent);revealCurrent();
 instances.set(nav,{refresh});
}
