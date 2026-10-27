import {createClient} from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm';
import {isUUID,navigation} from './account-specialist-ui.js';
export const sb=createClient('https://rzhlcszqtuhkhfibygnk.supabase.co','sb_publishable_yhqWJ1eWUznBkqKwPogTrw_xCdCbFA-');
export async function context(section){
 const id=new URLSearchParams(location.search).get('id');
 const {data,error}=await sb.auth.getSession();if(error)throw Error('Не удалось проверить сессию.');
 if(!data?.session){location.replace('account-login.html?next='+encodeURIComponent(location.pathname.split('/').pop().replace(/(?:\.html)?$/i,'.html')+location.search));throw Error('Войдите в кабинет.');}
 if(!isUUID(id))throw Error('Откройте сохранённого специалиста из «Мои профили».');
 const rows=await rpc('get_my_specialists');const item=rows?.find(x=>x.id===id&&x.profile_status==='draft');if(!item)throw Error('Черновик не найден или недоступен.');
 sessionStorage.setItem('active_profile',JSON.stringify({kind:'specialist',id}));navigation(document.querySelector('.editor-nav'),id,section,item.display_name);document.getElementById('profile-name').textContent=item.display_name;return id;
}
export async function rpc(name,args={}){const {data,error}=await sb.rpc(name,args);if(error)throw error;return data;}
export function message(error){return ['40001','PT409'].includes(error?.code)?'Данные уже изменились. Обновите страницу перед сохранением.':error?.code==='42501'?'Нет доступа к черновику или сессия истекла.':error?.code==='54000'?'Достигнут лимит. Удалите ненужные элементы.':['42883','PGRST202'].includes(error?.code)?'Раздел пока недоступен. Попробуйте позже.':error?.code==='23505'?'Элемент уже существует. Для замены аватара сначала удалите прежний.':error?.code==='22023'||String(error?.code||'').startsWith('23')?'Проверьте поля и ограничения формы.':error?.constructor===Error&&error.message&&!error.code?error.message:'Не удалось подтвердить операцию. Обновите список перед повторной попыткой.';}
export function status(value){document.getElementById('status').textContent=value;}
