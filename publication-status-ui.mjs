// Pure, read-only presentation of the publication status RPC; no synthetic success.
const LABELS=Object.freeze({queued:'? ??????? ?? ??????????',building:'????????? ???????',published:'????????????',failed:'?????? ??????????'});
export function publicationView(result){
 if(!result||typeof result!=='object'||!Object.hasOwn(LABELS,result.status))return {state:'unknown',label:'?????? ?????????? ?? ???????????',success:false,retry:false};
 const state=result.status;
 const published=state==='published';
 const validUrl=typeof result.public_url==='string'&&/^https:\/\/[a-z0-9.-]+(?:\/[a-zA-Z0-9_~!$&'()*+,;=:@%./-]*)?$/.test(result.public_url);
 return {state,label:LABELS[state],success:published,retry:state==='failed',publicUrl:published&&validUrl?result.public_url:null};
}
export function renderPublicationStatus(node,result){
 const view=publicationView(result);node.replaceChildren();
 const label=node.ownerDocument.createElement('span');label.textContent=view.label;node.append(label);
 if(view.publicUrl){const link=node.ownerDocument.createElement('a');link.href=view.publicUrl;link.target='_blank';link.rel='noopener noreferrer';link.textContent='??????? ????????? ???????';node.append(link);}
 return view;
}

// Canonical SQL candidate ae3ac358: request_my_company_publication(company UUID, request UUID)
// and get_my_company_publication_status(company UUID). This is NOT a deployed-API assertion.
export function createPublicationController({rpc,companyId,makeRequestId,render}){
 if(typeof rpc!=='function'||typeof render!=='function'||typeof makeRequestId!=='function'||!companyId)throw Error('Missing publication dependencies');
 let busy=false;
 async function refresh(){
  const {data,error}=await rpc('get_my_company_publication_status',{p_company_id:companyId});
  if(error)throw error;
  if(data?.company_id!==companyId)throw Error('Publication company mismatch');
  return render(data);
 }
 async function request(){
  if(busy)return {accepted:false,reason:'busy'};
  busy=true;
  try{
   const id=makeRequestId();
   if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id))throw Error('Invalid request UUID');
   const {data,error}=await rpc('request_my_company_publication',{p_company_id:companyId,p_request_id:id});
   if(error)throw error;
   if(typeof data!=='string'||!data)throw Error('Publication request not acknowledged');
   const view=await refresh();
   return {accepted:true,attemptId:data,view};
  }finally{busy=false}
 }
 return {refresh,request,get busy(){return busy}};
}
