// Shared profile lifecycle. Server RPC/RLS remain the authorization boundary.
export const isUUID=id=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id||'');
export async function profileRPC(client,name,args={}){const {data,error}=await client.rpc(name,args);if(error)throw error;return data;}
export function createCabinet({client,adapter,location=globalThis.location,sessionStorage=globalThis.sessionStorage,localStorage=globalThis.localStorage}){
 if(!['company','specialist'].includes(adapter?.kind))throw Error('Неизвестный тип профиля.');
 let current=null;
 async function load(){
  current=null;
  const params=new URLSearchParams(location.search);
  if((params.has('profile_kind')&&params.get('profile_kind')!==adapter.kind)||params.has(adapter.otherIdKey))throw Error('Откройте нужный профиль из «Мои профили».');
  const {data,error}=await client.auth.getSession();if(error)throw Error('Не удалось проверить сессию.');
  if(!data?.session){const page=location.pathname.split('/').pop();const next=(page.endsWith('.html')?page:page+'.html')+location.search;location.replace('account-login.html?next='+encodeURIComponent(next));throw Error('Войдите в кабинет.');}
  const id=params.get(adapter.idKey);if(!isUUID(id))throw Error('Некорректная ссылка на профиль. Откройте его из «Мои профили».');
  const rows=await adapter.list(client);
  const context=adapter.select(rows,id);if(!context)throw Object.assign(Error(adapter.unavailable),{code:'42501'});
  current=context;
  try{sessionStorage?.setItem('active_profile',JSON.stringify({kind:adapter.kind,id}));if(adapter.kind==='company'){sessionStorage?.setItem('otzovik_active_company_id',id);localStorage?.setItem('otzovik_active_company_id',id);}}catch{}
  return context;
 }
 async function saveBasic(values){
  const context=await load(); // Recheck current session and membership, never cached authorization.
  if(!context.canEdit)throw Object.assign(Error('Нет прав на изменение профиля.'),{code:'42501'});
  const result=await adapter.saveBasic(client,context.id,values);
  if(adapter.savedRecord(result)?.id!==context.id)throw Error('Не удалось подтвердить сохранение.');
  return result;
 }
 return {load,saveBasic,get current(){return current;}};
}
