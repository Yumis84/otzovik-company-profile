import {sb} from './account-specialist-api.js';
async function gateway(body){
 const {data,error}=await sb.functions.invoke('specialist-media-gateway',{body});
 if(error){let detail;try{detail=await error.context.json();}catch{}throw Object.assign(Error(detail?.error||'Операция с фотографией не подтверждена. Обновите список перед повтором.'),{reservationReleased:detail?.reservation_released===true});}
 return data;
}
export async function gatewayUpload(id,requestId,kind,image,caption){
 const data=await new Promise((resolve,reject)=>{const r=new FileReader();r.onerror=()=>reject(Error('Не удалось прочитать фотографию'));r.onload=()=>resolve(String(r.result).split(',')[1]);r.readAsDataURL(image);});
 return gateway({action:'upload',specialist_id:id,request_id:requestId,kind,mime:image.type,data,caption});
}
export const gatewayDelete=(id,path)=>gateway({action:'delete',specialist_id:id,object_name:path});

export const gatewayReconcile=id=>gateway({action:'reconcile',specialist_id:id});
export const gatewayRecover=(id,requestId)=>gateway({action:'recover',specialist_id:id,request_id:requestId});
