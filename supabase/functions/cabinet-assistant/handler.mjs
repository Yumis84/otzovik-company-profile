// Shared by the Edge entrypoint and disposable test server; no service-role key.
const routes={flags:{rpc:'cabinet_get_flags',fields:[]},list:{rpc:'cabinet_list_conversations',fields:[]},create:{rpc:'cabinet_create_conversation',fields:['p_company_id','p_request_id']},history:{rpc:'cabinet_get_conversation',fields:['p_id']},remove:{rpc:'cabinet_delete_conversation',fields:['p_id']},context:{rpc:'cabinet_profile_context',fields:['p_id']},send:{rpc:'cabinet_send_mock',fields:['p_conversation','p_message_id','p_text','p_expected_seq','p_hint']},reject:{rpc:'cabinet_reject_proposal',fields:['p_id']},apply:{rpc:'cabinet_apply_proposal',fields:['p_id','p_expected_hash','p_confirmed','p_edits']}};
export function createHandler({url,anonKey,origins}){
 if(!url||!anonKey||!Array.isArray(origins)||!origins.length)throw Error('Explicit server configuration required');
 return async function handle(req){
  const origin=req.headers.get('origin');const headers={'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin'};
  const answer=(status,data)=>new Response(JSON.stringify(data),{status,headers});
  if(!origins.includes(origin))return answer(403,{error:'Origin запрещён'});
  headers['Access-Control-Allow-Origin']=origin;headers['Access-Control-Allow-Headers']='authorization,content-type,apikey';headers['Access-Control-Allow-Methods']='POST,OPTIONS';
  if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
  if(req.method!=='POST')return answer(405,{error:'Метод запрещён'});
  try{
   const auth=req.headers.get('authorization');if(!auth?.startsWith('Bearer '))return answer(401,{error:'Войдите в кабинет'});
   const verified=await fetch(url+'/auth/v1/user',{headers:{apikey:anonKey,Authorization:auth},signal:AbortSignal.timeout(8000)});if(!verified.ok)return answer(401,{error:'Войдите в кабинет'});
   const reader=req.body?.getReader();if(!reader)return answer(400,{error:'Неверный запрос'});const decoder=new TextDecoder();let raw='',bytes=0;while(true){const {done,value}=await reader.read();if(done)break;bytes+=value.byteLength;if(bytes>14000){await reader.cancel();return answer(413,{error:'Запрос слишком большой'});}raw+=decoder.decode(value,{stream:true});}raw+=decoder.decode();
   let body;try{body=JSON.parse(raw);}catch{return answer(400,{error:'Неверный запрос'});}
   if(!body||typeof body!=='object'||Array.isArray(body))return answer(400,{error:'Неверный запрос'});
   const route=routes[body.action];if(!route||Object.keys(body).some(k=>k!=='action'&&!route.fields.includes(k)))return answer(422,{error:'Поля запроса запрещены'});
   const args=Object.fromEntries(route.fields.filter(k=>Object.hasOwn(body,k)).map(k=>[k,body[k]]));
   const rpc=await fetch(url+'/rest/v1/rpc/'+route.rpc,{method:'POST',headers:{apikey:anonKey,Authorization:auth,'Content-Type':'application/json'},body:JSON.stringify(args),signal:AbortSignal.timeout(12000)});
   const data=await rpc.json();if(!rpc.ok){const status=[400,401,403,404,409,413,422,429,503].includes(rpc.status)?rpc.status:502;return answer(status,{error:status===409?'Профиль или диалог изменился':status===404?'Не найдено':status===429?'Лимит запросов':status===503?'Помощник временно недоступен':'Запрос отклонён',status:data.status||undefined});}
   return answer(200,data);
  }catch{return answer(502,{error:'Помощник временно недоступен'});}
 };
}
