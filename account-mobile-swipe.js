/* Shared swipe navigation for mobile company cabinet. */
(()=>{'use strict';
if(!matchMedia('(max-width: 760px)').matches)return;
const nav=document.querySelector('nav[aria-label="Навигация кабинета"]');
if(!nav)return;
const links=[...nav.querySelectorAll('a[href]')].filter(a=>!a.getAttribute('href').includes('account-home.html'));
const current=links.findIndex(a=>a.classList.contains('active'));
if(current<0)return;
let touch=null,dirty=false;
const skip='input,textarea,select,[contenteditable="true"],[role="slider"],[role="dialog"],[data-no-swipe]';
document.addEventListener('input',e=>{if(e.target.closest('input,textarea,select,[contenteditable="true"]'))dirty=true},true);
document.addEventListener('change',e=>{if(e.target.closest('input,textarea,select'))dirty=true},true);
document.addEventListener('submit',()=>{dirty=false},true);
document.addEventListener('touchstart',e=>{
if(e.touches.length!==1||e.target.closest(skip)){touch=null;return}
const t=e.touches[0];
if(t.clientX<20||t.clientX>innerWidth-20){touch=null;return}
touch={x:t.clientX,y:t.clientY,at:Date.now()};
},{passive:true});
document.addEventListener('touchcancel',()=>touch=null,{passive:true});
document.addEventListener('touchend',e=>{
if(!touch||e.changedTouches.length!==1)return;
const t=e.changedTouches[0],dx=t.clientX-touch.x,dy=t.clientY-touch.y,elapsed=Date.now()-touch.at;
touch=null;
if(elapsed>1400||Math.abs(dx)<55||Math.abs(dx)<Math.abs(dy)*1.3)return;
const next=current+(dx<0?1:-1);
if(next<0||next>=links.length)return;
if(dirty&&!confirm('Есть несохранённые изменения. Перейти без сохранения?'))return;
const url=new URL(links[next].href,location.href);
const company=new URLSearchParams(location.search).get('company_id');
if(company&&!url.searchParams.has('company_id'))url.searchParams.set('company_id',company);
location.assign(url.href);
},{passive:true});
})();
