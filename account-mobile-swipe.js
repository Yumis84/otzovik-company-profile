/* Shared mobile-only swipe navigation for company cabinet pages. */
(()=>{'use strict';
if(!window.matchMedia('(max-width: 760px)').matches || !('ontouchstart' in window || navigator.maxTouchPoints>0))return;
const nav=document.querySelector('nav[aria-label="Навигация кабинета"]');
if(!nav)return;
const links=[...nav.querySelectorAll('a[href]')].filter(a=>!a.getAttribute('href').includes('account-home.html'));
const current=links.findIndex(a=>a.classList.contains('active'));
if(current<0)return;
let start=null,dirty=false;
const interactive='input,textarea,select,button,[contenteditable],a,[role="slider"],[role="dialog"],[data-no-swipe]';
document.addEventListener('input',e=>{if(e.target.matches('input,textarea,[contenteditable]'))dirty=true},true);
document.addEventListener('change',e=>{if(e.target.matches('select,input,textarea'))dirty=true},true);
document.addEventListener('submit',()=>{dirty=false},true);
document.addEventListener('touchstart',e=>{
if(e.touches.length!==1||e.target.closest(interactive)||e.target.closest('[style*="overflow-x"],.horizontal-scroll,.carousel')){start=null;return}
const t=e.touches[0];if(t.clientX<24||t.clientX>innerWidth-24){start=null;return}
start={x:t.clientX,y:t.clientY,time:Date.now()};
},{passive:true});
document.addEventListener('touchend',e=>{
if(!start||e.changedTouches.length!==1)return;
const t=e.changedTouches[0],dx=t.clientX-start.x,dy=t.clientY-start.y;
const elapsed=Date.now()-start.time;start=null;
if(elapsed>1300||Math.abs(dx)<65||Math.abs(dx)<Math.abs(dy)*1.35)return;
const next=current+(dx<0?1:-1);
if(next<0||next>=links.length)return;
if(dirty&&!confirm('Есть несохранённые изменения. Перейти без сохранения?'))return;
const url=new URL(links[next].href,location.href);
const company=new URLSearchParams(location.search).get('company_id');
if(company&&!url.searchParams.has('company_id'))url.searchParams.set('company_id',company);
location.assign(url.href);
},{passive:true});
})();