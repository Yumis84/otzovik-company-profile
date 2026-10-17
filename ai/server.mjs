import http from 'node:http';
import fs from 'node:fs/promises';
import {Gateway,AiError} from './gateway.mjs';
import {fileURLToPath} from 'node:url';
// Real provider deliberately unavailable until explicit approval and deployment review.
export function createServer({repository,authenticate,login,origin,ttlMs}){
 const gateway=new Gateway({repository,ttlMs});
 const server=http.createServer(async(req,res)=>{
  res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'");
  try{
   const url=new URL(req.url,'http://localhost');
   if(req.method==='GET'&&['/','/client.mjs','/style.css'].includes(url.pathname)){
    const name=url.pathname==='/'?'index.html':url.pathname.slice(1);res.setHeader('Content-Type',name.endsWith('.mjs')?'text/javascript':name.endsWith('.css')?'text/css':'text/html; charset=utf-8');res.end(await fs.readFile(new URL(name,import.meta.url)));return;
   }
   if(req.method!=='POST'||req.headers.origin!==origin)throw new AiError(403,'Origin запрещён');
   let raw='';for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>16000)throw new AiError(413,'Слишком большой запрос');}
   let b;try{b=JSON.parse(raw);}catch{throw new AiError(400,'Неверный JSON');}
   if(url.pathname==='/api/login'){gateway.limit('login',10);if(!login)throw new AiError(503,'Вход не настроен');const result=await login(b);res.setHeader('Content-Type','application/json');res.end(JSON.stringify(result));return;}
   const actor=await authenticate(req.headers.authorization);if(!actor)throw new AiError(401,'Требуется вход');
   let result;
   const {profile_kind:k,profile_id:id}=b;
   if(url.pathname==='/api/config')result=await repository.config(actor,k,id);
   else if(url.pathname==='/api/save')result=await repository.save(actor,k,id,b.expected_version,b.settings);
   else if(url.pathname==='/api/start')result=await gateway.start(actor,k,id);
   else if(url.pathname==='/api/chat')result=await gateway.chat(actor,b);
   else if(url.pathname==='/api/history')result=await gateway.history(actor,b.token,k,id);
   else if(url.pathname==='/api/clear')result=await gateway.clear(actor,b.token,k,id);
   else throw new AiError(404,'Не найдено');
   res.setHeader('Content-Type','application/json');res.end(JSON.stringify(result));
  }catch(e){res.statusCode=e.status||500;res.setHeader('Content-Type','application/json');res.end(JSON.stringify({error:e.status?e.message:'Ошибка сервера'}));}
 });
 const cleanup=setInterval(()=>gateway.cleanup(),10000);cleanup.unref();server.on('close',()=>clearInterval(cleanup));return {server,gateway};
}
export function supabaseAdapter({url,key}){
 async function request(path,token,body){const r=await fetch(url+path,{method:body?'POST':'GET',headers:{apikey:key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(8000)});const data=await r.json();if(!r.ok)throw new AiError([400,401,403,409,429,503].includes(r.status)?r.status:502,'Доступ или запрос отклонён');return data;}
 return {login:async({email,password})=>{if(typeof email!=='string'||typeof password!=='string'||email.length>254||password.length>256)throw new AiError(400,'Неверный вход');const d=await request('/auth/v1/token?grant_type=password',key,{email,password});return {access_token:d.access_token};},authenticate:async header=>{const token=header?.startsWith('Bearer ')?header.slice(7):null;if(!token)return null;const user=await request('/auth/v1/user',token);return {id:user.id,token};},repository:{config:(a,k,id)=>request('/rest/v1/rpc/get_my_ai_config',a.token,{profile_kind:k,profile_id:id}),save:(a,k,id,v,settings)=>request('/rest/v1/rpc/save_my_ai_config',a.token,{profile_kind:k,profile_id:id,expected_version:v,settings}),snapshot:(k,id,a)=>request('/rest/v1/rpc/get_my_ai_snapshot',a.token,{profile_kind:k,profile_id:id})}};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 if(process.env.AI_PROVIDER&&process.env.AI_PROVIDER!=='mock')throw Error('Only mock provider authorized');
 const {AI_SUPABASE_URL:url,AI_PUBLISHABLE_KEY:key}=process.env;
 if(!url||!key||!key.startsWith('sb_publishable_'))throw Error('Explicit isolated Supabase URL and publishable key required');
 const adapter=supabaseAdapter({url,key});const port=Number(process.env.PORT||8787);
 const {server}=createServer({...adapter,origin:`http://127.0.0.1:${port}`,ttlMs:Number(process.env.AI_PREVIEW_TTL_MS||1800000)});server.listen(port,'127.0.0.1',()=>console.log(`Owner mock preview: http://127.0.0.1:${port}`));
}
