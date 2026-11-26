// Public media uses the public anon credential only; never import the owner client.
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function publishedPhotoLoader({endpoint,anonKey,fetcher=fetch,urls=URL,timeout=12000}){
 const live=new Set(),controllers=new Set();let disposed=false;
 return {
 async load(slug,id){
  if(disposed||!UUID.test(id)||!/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/.test(slug)||slug.includes('--'))return null;
  const controller=new AbortController();controllers.add(controller);const timer=setTimeout(()=>controller.abort(),timeout);
  try{
   const url=new URL(endpoint);url.search=new URLSearchParams({view:'published',slug,photo:id});
   const response=await fetcher(url,{method:'POST',headers:{Authorization:'Bearer '+anonKey,apikey:anonKey},credentials:'omit',cache:'no-store',redirect:'error',signal:controller.signal});
   if(!response.ok||!['image/jpeg','image/png','image/webp'].includes((response.headers.get('content-type')||'').split(';')[0].trim().toLowerCase()))return null;
   const blob=await response.blob();if(disposed||controller.signal.aborted||!blob.size||blob.size>10*1024*1024)return null;
   const objectUrl=urls.createObjectURL(blob);live.add(objectUrl);
   return {url:objectUrl,release(){if(live.delete(objectUrl))urls.revokeObjectURL(objectUrl);}};
  }catch{return null;}finally{clearTimeout(timer);controllers.delete(controller);}
 },
 dispose(){disposed=true;for(const controller of controllers)controller.abort();controllers.clear();for(const url of live)urls.revokeObjectURL(url);live.clear();}
 };
}
