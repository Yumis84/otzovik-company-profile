/* Unified mobile company cabinet navigation v5. */
(()=>{'use strict';
if(!window.matchMedia('(max-width: 900px)').matches)return;
const pages=[
['account-home.html','Мои компании'],['account-profile.html','Профиль'],['account-branches.html','Филиалы'],['account-services.html','Услуги'],['account-media.html','Фото'],['account-reviews.html','Отзывы'],['account-qna.html','Вопросы и ответы'],['account-sources.html','Источники рейтингов'],['account-billing.html','Тариф и оплата'],['account-ai-assistant.html','AI-ассистент'],['account-notifications.html','Уведомления'],['account-analytics.html','Статистика']
];
const current=pages.findIndex(p=>location.pathname.endsWith('/'+p[0]));
if(current<1)return;
let dirty=false,start=null;
const editable='input,textarea,select,[contenteditable="true"],[role="slider"],[role="dialog"],[data-no-swipe]';
const panel=document.createElement('div');
panel.setAttribute('aria-label','Переход между разделами');
panel.style.cssText='position:fixed;bottom:calc(10px + env(safe-area-inset-bottom, 0px));left:50%;transform:translateX(-50%);z-index:2147483000;display:flex;align-items:center;gap:12px;max-width:95vw;background:#175cd3;color:#fff;border-radius:28px;padding:8px 12px;box-shadow:0 3px 16px #0004;font:600 13px system-ui';
panel.innerHTML='<button type="button" data-dir="-1" aria-label="Предыдущий раздел" style="border:0;background:transparent;color:inherit;padding:5px 10px;font:inherit">◀</button><span style="white-space:nowrap">'+(current+1)+' / '+pages.length+' · '+pages[current][1]+'</span><button type="button" data-dir="1" aria-label="Следующий раздел" style="border:0;background:transparent;color:inherit;padding:5px 10px;font:inherit">▶</button>';
document.body.append(panel);
panel.querySelector('[data-dir="-1"]').disabled=current===0;
panel.querySelector('[data-dir="1"]').disabled=current===pages.length-1;
function navigate(step){
const next=current+step;if(next<0||next>=pages.length)return;
if(dirty&&!window.confirm('Есть несохранённые изменения. Перейти без сохранения?'))return;
const target=new URL(pages[next][0],location.href);
const company=new URLSearchParams(location.search).get('company_id');
if(company&&next!==0)target.searchParams.set('company_id',company);
location.assign(target.href);
}
panel.addEventListener('click',e=>{const btn=e.target.closest('button[data-dir]');if(btn)navigate(Number(btn.dataset.dir))});
document.addEventListener('input',e=>{if(e.target.closest('input,textarea,select,[contenteditable="true"]'))dirty=true},true);
document.addEventListener('change',e=>{if(e.target.closest('input,textarea,select'))dirty=true},true);
document.addEventListener('submit',()=>{dirty=false},true);
function begin(e){
if(e.touches.length!==1||e.target.closest(editable)){start=null;return}
const t=e.touches[0];if(t.clientX<20||t.clientX>innerWidth-20){start=null;return}
start={x:t.clientX,y:t.clientY,time:Date.now()};
}
function end(e){
if(!start||e.changedTouches.length!==1)return;
const t=e.changedTouches[0],dx=t.clientX-start.x,dy=t.clientY-start.y,elapsed=Date.now()-start.time;start=null;
if(elapsed>1600||Math.abs(dx)<55||Math.abs(dx)<Math.abs(dy)*1.4)return;
navigate(dx<0?1:-1);
}
document.addEventListener('touchstart',begin,{capture:true,passive:true});
document.addEventListener('touchend',end,{capture:true,passive:true});
document.addEventListener('touchcancel',()=>{start=null},{capture:true,passive:true});
})();
