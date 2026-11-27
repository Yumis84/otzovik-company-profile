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
