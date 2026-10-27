// Server-only handler shared with the Edge adapter. No signed upload tokens or direct client Storage writes.
const LIMIT=5242880,MAX_BODY=7100000,uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// HTTP and legacy embedded statuses must both describe a terminal rejection.
// 408, 409, 5xx and unknown/network outcomes retain the reservation.
export async function isDefiniteStorageRejection(response){
 if(response.status<400||response.status>=500||[408,409].includes(response.status))return false;
 let body;try{body=await response.clone().json();}catch{return false;}
 if(!body||typeof body!=='object')return false;
 const status=Number(body.statusCode??body.status??response.status);
 if(!Number.isInteger(status)||status<400||status>=500||[408,409].includes(status))return false;
 if(/timeout|internal|unknown|alreadyexists|duplicate/i.test(String(body.code||body.error||'')))return false;
 return true;
}
export function createMediaGateway({url,anonKey,serviceKey,origins=[],fetcher=fetch}){
 const base=new URL(url);if(!['https:','http:'].includes(base.protocol)||base.username||base.password||base.search||base.hash||!anonKey||!serviceKey)throw Error('Invalid server configuration');
 const endpoint=base.origin,serviceHeaders={apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json'};
 async function rpc(name,args){
  const res=await fetcher(endpoint+'/rest/v1/rpc/'+name,{method:'POST',headers:serviceHeaders,body:JSON.stringify(args),signal:AbortSignal.timeout(15000)});
  const data=await res.json();if(!res.ok){const e=Error('Request failed');e.code=data.code;e.status=data.code==='42501'?403:['PT409','40001','23505','23503'].includes(data.code)?409:data.code==='54000'?429:data.code==='55000'?503:400;throw e;}return data;
 }
 async function jsonBody(request){
  if(Number(request.headers.get('content-length')||0)>MAX_BODY)throw Object.assign(Error(),{status:413});
  const reader=request.body?.getReader();if(!reader)throw Object.assign(Error(),{status:400});const parts=[];let size=0;
  for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>MAX_BODY){await reader.cancel();throw Object.assign(Error(),{status:413});}parts.push(value);}
  const bytes=new Uint8Array(size);let offset=0;for(const p of parts){bytes.set(p,offset);offset+=p.length;}return JSON.parse(new TextDecoder().decode(bytes));
 }
 function image(body){
  if(typeof body.data!=='string'||body.data.length>Math.ceil(LIMIT/3)*4||!body.data||!/^[A-Za-z0-9+/]+={0,2}$/.test(body.data))throw Object.assign(Error(),{status:400});
  let raw;try{raw=atob(body.data);}catch{throw Object.assign(Error(),{status:400});}
  const bytes=Uint8Array.from(raw,c=>c.charCodeAt(0));if(bytes.length>LIMIT||!bytes.length)throw Object.assign(Error(),{status:413});
  const starts=seq=>seq.every((x,i)=>bytes[i]===x),ascii=(start,end)=>String.fromCharCode(...bytes.slice(start,end));
  const valid=body.mime==='image/png'?starts([137,80,78,71,13,10,26,10]):body.mime==='image/jpeg'?starts([255,216,255]):body.mime==='image/webp'?ascii(0,4)==='RIFF'&&ascii(8,12)==='WEBP':false;
  if(!valid)throw Object.assign(Error(),{status:415});return bytes;
 }
 return async request=>{
  const origin=request.headers.get('origin'),cors=origin&&origins.includes(origin)?{'Access-Control-Allow-Origin':origin,'Vary':'Origin'}:{};
  const response=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store',...cors}});
  if(origin&&!origins.includes(origin))return response(403,{error:'Origin denied'});
  if(request.method==='OPTIONS')return new Response(null,{status:204,headers:{...cors,'Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'}});
  if(request.method!=='POST')return response(405,{error:'POST required'});
  try{
   const authorization=request.headers.get('authorization')||'';if(!/^Bearer [A-Za-z0-9_.-]+$/.test(authorization))return response(401,{error:'Authentication required'});
   const auth=await fetcher(endpoint+'/auth/v1/user',{headers:{apikey:anonKey,Authorization:authorization},signal:AbortSignal.timeout(10000)});
   if(!auth.ok)return response(401,{error:'Authentication required'});const user=await auth.json();if(!uuid.test(user.id||'')||user.is_anonymous)return response(401,{error:'Verified account required'});
   const body=await jsonBody(request);if(!uuid.test(body.specialist_id||''))return response(400,{error:'Invalid profile'});
   const owner={p_owner:user.id,p_specialist_id:body.specialist_id};
   if(body.action==='upload'){
    if(!uuid.test(body.request_id||'')||!['avatar','portfolio'].includes(body.kind)||body.caption!==null&&typeof body.caption!=='string'||(body.caption||'').length>500)return response(400,{error:'Invalid upload'});
    const bytes=image(body),digest=await crypto.subtle.digest('SHA-256',bytes),fingerprint=Array.from(new Uint8Array(digest),x=>x.toString(16).padStart(2,'0')).join('');
    const r=await rpc('specialist_gateway_reserve',{...owner,p_request_id:body.request_id,p_kind:body.kind,p_fingerprint:fingerprint,p_mime:body.mime,p_size:bytes.length,p_caption:body.caption});
    if(r.state==='deleted'||r.state==='deleting')return response(409,{error:'Запрос завершён. Выберите файл ещё раз.',reservation_released:r.state==='deleted'});
    if(r.upload_allowed){
     // Exactly one attempt per reservation. An uncertain result MUST retain the slot.
     const upload=await fetcher(endpoint+'/storage/v1/object/specialist-media/'+r.object_name,{method:'POST',headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':body.mime,'x-upsert':'false'},body:bytes,signal:AbortSignal.timeout(25000)});
     if(!upload.ok){
      if(await isDefiniteStorageRejection(upload)){
       await rpc('specialist_gateway_reject',{...owner,p_request_id:body.request_id,p_http_status:upload.status});
       return response(422,{error:'Storage отклонил загрузку. Выберите файл ещё раз.',request_id:body.request_id,reservation_released:true});
      }
      return response(409,{error:'Upload not confirmed; reservation retained',request_id:body.request_id});
     }
    }
    return response(200,{media:await rpc('specialist_gateway_finish',{...owner,p_request_id:body.request_id})});
   }
   if(body.action==='delete'){
    const r=await rpc('specialist_gateway_begin_delete',{...owner,p_object_name:body.object_name});
    if(r.state!=='deleted'){
     const removed=await fetcher(endpoint+'/storage/v1/object/specialist-media',{method:'DELETE',headers:serviceHeaders,body:JSON.stringify({prefixes:[r.object_name]}),signal:AbortSignal.timeout(15000)});
     if(!removed.ok)return response(409,{error:'Deletion pending; metadata and quota retained'});
    }
    return response(200,await rpc('specialist_gateway_finish_delete',{...owner,p_request_id:r.id}));
   }
   if(body.action==='reconcile')return response(200,{dry_run:true,reservations:await rpc('specialist_gateway_reconcile',owner)});
   if(body.action==='recover'&&uuid.test(body.request_id||''))return response(200,{media:await rpc('specialist_gateway_finish',{...owner,p_request_id:body.request_id})});
   return response(400,{error:'Unsupported action'});
  }catch(e){return response(e.status||503,{error:e.code==='54000'?'Photo limit reached; pending uploads occupy slots':e.code==='55000'?'Media changes temporarily disabled':e.code==='42501'?'Access denied':'Operation not confirmed; refresh before retrying',code:e.code||'GATEWAY_ERROR'});}
 };
}
