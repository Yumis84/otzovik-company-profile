// Session generation fence; no credentials or network calls.
export function createSessionFence(){
 let generation=0,user=null;
 return Object.freeze({
  transition(next){generation++;user=next??null;},
  capture(){return Object.freeze({generation,user});},
  current(ticket){return !!user&&ticket?.generation===generation&&ticket.user===user;}
 });
}
export function clearCompanyStorage(local,session){
 for(const storage of [local,session])storage.removeItem('otzovik_active_company_id');
}

export function createAuthSessionObserver(onChange){
 let initialized=false,identity=null;
 return (event,session)=>{
  const next=session?.user?.id??null;
  if(!initialized){initialized=true;identity=next;if(event!=='SIGNED_OUT')return false;}
  if(event!=='SIGNED_OUT'&&next===identity)return false;
  identity=next;onChange(next);return true;
 };
}
export async function settleForSession(fence,ticket,promise,onSuccess,onError){
 let value;
 try{value=await promise;}catch(error){if(fence.current(ticket))onError(error);return;}
 if(fence.current(ticket))onSuccess(value);
}
