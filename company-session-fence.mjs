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

// Identity is a local invalidation hint, never an authorization decision.
export function sessionIdentity(session){
 if(!session?.user?.id||typeof session.access_token!=='string')return null;
 try{
  const part=session.access_token.split('.')[1];
  const claims=JSON.parse(atob(part.replace(/-/g,'+').replace(/_/g,'/')));
  if(claims.sub!==session.user.id||typeof claims.session_id!=='string'||!claims.session_id)return null;
  return JSON.stringify([claims.sub,claims.session_id]);
 }catch{return null;}
}
export function createAuthSessionObserver(onChange){
 let initialized=false,identity=null;
 return (event,session)=>{
  const next=sessionIdentity(session);
  if(!initialized){initialized=true;identity=next;if(event!=='SIGNED_OUT')return false;}
  if(event!=='SIGNED_OUT'&&next!==null&&next===identity)return false;
  identity=next;onChange(next);return true;
 };
}
export async function settleForSession(fence,ticket,promise,onSuccess,onError){
 let value;
 try{value=await promise;}catch(error){if(fence.current(ticket))onError(error);return;}
 if(fence.current(ticket))onSuccess(value);
}

/** Page lifetime fence. A changed identity permanently invalidates this document. */
export function createPageSessionFence(auth,onInvalidate,{allowAnonymous=false}={}){
 let identity=null,initialized=false,invalid=false;
 const invalidate=()=>{if(invalid)return;invalid=true;onInvalidate();};
 const observe=(event,session)=>{
  const next=sessionIdentity(session);
  if(event==='SIGNED_OUT'){invalidate();return;}
  if(!next&&(!allowAnonymous||session||identity!==null)){invalidate();return;}
  if(!initialized){initialized=true;identity=next;return;}
  if(identity!==next)invalidate();
 };
 auth.onAuthStateChange(observe);
 return Object.freeze({
  async start(){const result=await auth.getSession();observe('INITIAL_SESSION',result.data?.session);return !invalid&&initialized&&identity!==null;},
  current(){return !invalid&&initialized&&identity!==null;},
  anonymous(){return allowAnonymous&&!invalid&&initialized&&identity===null;},
  invalidate
 });
}
