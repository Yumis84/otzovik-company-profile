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
