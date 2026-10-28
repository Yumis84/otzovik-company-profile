// Privileged operator process only; custom operator identity, NOT the Edge service key.
// No CLI, environment/key discovery, schedules, hosted calls or automatic authorization.
const check=r=>{if(r.error)throw r.error;return r.data;};
async function identity(operator){return check(await operator.auth.getUser()).user.id;}
export async function planSpecialistErasure({operator,owner,profile,authorization}){
 await identity(operator);
 return check(await operator.rpc('specialist_operator_plan_erasure',{p_owner:owner,p_specialist_id:profile,p_authorization_id:authorization}));
}
export async function prepareSpecialistErasure({operator,owner,profile,authorization,plan,reason,proofs}){
 if(!operator||!plan?.planned||plan.authorization_id!==authorization)throw Error('Explicit two-phase erasure plan required');
 const actor=await identity(operator),scope={p_owner:owner,p_specialist_id:profile};
 const call=async(name,args={})=>check(await operator.rpc(name,{...scope,...args}));
 const inventory=await call('specialist_gateway_erasure_inventory');
 if(inventory.uploads_enabled)throw Error('Disable upload admission first');
 const ids=inventory.reservations.map(r=>r.id).sort(),planned=plan.reservations.map(r=>r.id).sort();
 if(JSON.stringify(ids)!==JSON.stringify(planned))throw Error('Inventory changed; create and review a fresh plan');
 for(const r of inventory.reservations){
  const p=proofs?.[r.id];
  if(!p||p.request_id!==r.id||p.authorization_id!==authorization||p.mode!=='confirmed_erasure'||p.all_writers_stopped!==true||!['provider_terminal_no_late_writer','credentials_revoked_all_writers_drained'].includes(p.kind)||typeof p.evidence_ref!=='string'||p.evidence_ref.length<8)throw Error('External reviewed no-late-writer evidence and confirmed erasure required for '+r.id);
 }
 for(const r of inventory.reservations){
  const args={p_request_id:r.id,p_actor:actor,p_reason:reason,p_proof:proofs[r.id]};
  await call('specialist_gateway_force_retire',{...args,p_phase:'begin'});
  // Operator's narrow Storage policy opens ONLY the exact audited begin path.
  check(await operator.storage.from('specialist-media').remove([r.object_name]));
  await call('specialist_gateway_force_retire',{...args,p_phase:'finish'});
 }
 const final=await call('specialist_gateway_erasure_inventory');
 if(final.objects.length||final.reservations.length)throw Error('Erasure incomplete; retain account/profile and retry with a refreshed plan');
 return {media_erased:true,profile,account_deleted:false};
}
export async function cleanupSpecialistOrphan({operator,request,proof}){
 await identity(operator);
 const call=async phase=>check(await operator.rpc('specialist_operator_cleanup_orphan',{p_request_id:request,p_phase:phase,p_proof:proof}));
 const begin=await call('begin');check(await operator.storage.from('specialist-media').remove([begin.object_name]));return call('finish');
}
export async function readGatewayAlerts(client){
 const data=check(await client.rpc('specialist_gateway_metrics'));
 return {...data,alert:data.severity==='critical'||data.severity==='warning',severity:data.severity};
}
