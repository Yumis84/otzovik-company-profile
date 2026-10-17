/* Shared swipe navigation for mobile company cabinet. */
(()=>{'use strict';
if(!matchMedia('(max-width: 900px)').matches)return;
const nav=document.querySelector('nav[aria-label="Навигация кабинета"]');
if(!nav)return;
const links=[...nav.querySelectorAll('a[href]')];
const current=links.findIndex(a=>a.classList.contains('active'));
if(current<0)return;
const hint=document.createElement('div');hint.setAttribute('aria-label','Навигация по разделам');hint.style.cssText='position:fixed;bottom:12px;left:50%;transform:translateX(-50%);z-index:9999;background:#175cd3;color:white;padding:9px 14px;border-radius:24px;box-shadow:0 3px 14px #0003;display:flex;gap:12px;align-items:center;font:600 13px system-ui';hint.innerHTML='<button type="button" data-swipe-prev style="border:0;background:transparent;color:white;font:inherit;padding:2px 8px">◀</button><span>Раздел '+(current+1)+'/'+links.length+'</span><button type="button" data-swipe-next style="border:0;background:transparent;color:white;font:inherit;padding:2px 8px">▶</button>';document.body.append(hint);
function go(next){if(next<0||next>=links.length)return;if(dirty&&!confirm('Есть несохранённые изменения. Перейти без сохранения?'))return;const url=new URL(links[next].href,location.href);const company=new URLSearchParams(location.search).get('company_id');if(company&&!url.searchParams.has('company_id'))url.searchParams.set('company_id',company);location.assign(url.href)}
hint.querySelector('[data-swipe-prev]').addEventListener('click',()=>go(current-1));hint.querySelector('[data-swipe-next]').addEventListener('click',()=>go(current+1));
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
go(current+(dx<0?1:-1));
},{passive:true});
})();
