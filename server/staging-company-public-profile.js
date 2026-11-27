// Staging-only artifact delivery adapter for the existing canonical publisher.
const PROJECT='https://salmcnhexlftrgtiryyo.supabase.co';
const BUCKET='company-publication-artifacts-staging';
const MIME=new Set(['text/html; charset=utf-8','text/css; charset=utf-8','application/json; charset=utf-8','text/plain; charset=utf-8','image/png','image/jpeg','image/webp']);
const LIMIT=5242880;
export function createCompanyPublicHandler({serviceKey,fetchImpl=fetch}){
 if(typeof serviceKey!=='string'||!serviceKey)throw Error('staging service key required');
 const headers={apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json'};
 const failure=status=>new Response('Profile unavailable',{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Robots-Tag':'noindex, nofollow'}});
 return async request=>{
  if(!['GET','HEAD'].includes(request.method))return failure(405);
  const url=new URL(request.url);
  const match=url.pathname.match(/^\/functions\/v1\/company-public-profile\/([a-z0-9][a-z0-9-]{0,62})\/(index\.html|profile\.(?:css|json|md)|llms\.txt|media\/[A-Za-z0-9_-]+\.(?:png|jpg|jpeg|webp))?$/);
  if(url.pathname==='/functions/v1/company-public-profile/health'&&!url.search)return Response.json({project_id:'salmcnhexlftrgtiryyo',protocol:'company-publication-v1'},{headers:{'Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow'}});
  if(!match||url.search)return failure(404);
  const slug=match[1],asset=match[2]||'index.html';
  try{
   const rpc=await fetchImpl(PROJECT+'/rest/v1/rpc/resolve_company_public_asset',{method:'POST',headers,body:JSON.stringify({p_slug:slug,p_asset:asset}),redirect:'error',signal:AbortSignal.timeout(10000)});
   if(!rpc.ok)return failure(503);
   const item=await rpc.json();if(!item)return failure(404);
   if(item.bucket!==BUCKET||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(item.company_id)||!/^[0-9a-f]{64}$/.test(item.revision)||!/^[0-9a-f]{64}$/.test(item.sha256)||item.object_name!==item.company_id+'/'+item.revision+'/'+asset||!MIME.has(item.content_type))return failure(503);
   const response=await fetchImpl(PROJECT+'/storage/v1/object/authenticated/'+BUCKET+'/'+item.object_name,{headers,redirect:'error',signal:AbortSignal.timeout(15000)});
   if(!response.ok||!response.body)return failure(503);
   const reader=response.body.getReader(),chunks=[];let total=0;
   while(true){const {done,value}=await reader.read();if(done)break;total+=value.byteLength;if(total>LIMIT){await reader.cancel();return failure(503)}chunks.push(value)}
   if(!total)return failure(503);
   const bytes=new Uint8Array(total);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length}
   const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),x=>x.toString(16).padStart(2,'0')).join('');
   if(digest!==item.sha256)return failure(503);
   return new Response(request.method==='HEAD'?null:bytes,{headers:{'Content-Type':item.content_type,'Content-Length':String(total),'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','X-Robots-Tag':'noindex, nofollow','Content-Security-Policy':"default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; object-src 'none'"}});
  }catch{return failure(503)}
 };
}
// Deployment entrypoint is intentionally separate; this source never deploys itself.
