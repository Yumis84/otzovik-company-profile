// Server/operator module only. No CLI, environment discovery, schedule or automatic hosted execution.
// A human operator supplies externally reviewed proof; this module CANNOT establish writer quiescence.
export async function prepareSpecialistErasure({admin,owner,profile,actor,reason,proofs}){
 const check=r=>{if(r.error)throw r.error;return r.data;};
 const scope={p_owner:owner,p_specialist_id:profile};
 const call=async(name,args={})=>check(await admin.rpc(name,{...scope,...args}));
 let inventory=await call('specialist_gateway_erasure_inventory');
 if(inventory.uploads_enabled)throw Error('Disable upload admission first');
 // Make unregistered legacy objects explicit, under normal owner/path/lock validation.
 for(const name of inventory.objects){
  if(!inventory.reservations.some(r=>r.object_name===name)){
   const r=await call('specialist_gateway_begin_delete',{p_object_name:name});
   inventory.reservations.push({id:r.id,object_name:name,state:r.state});
  }
 }
 // Validate every supplied proof before retiring any reservation. No TTL or boolean-only bypass.
 for(const r of inventory.reservations){
  const p=proofs[r.id];
  if(!p||p.request_id!==r.id||p.all_writers_stopped!==true||!['provider_terminal_no_late_writer','credentials_revoked_all_writers_drained'].includes(p.kind)||typeof p.evidence_ref!=='string'||p.evidence_ref.length<8)throw Error('External reviewed no-late-writer evidence required for '+r.id);
 }
 for(const r of inventory.reservations){
  const args={p_request_id:r.id,p_actor:actor,p_reason:reason,p_proof:proofs[r.id]};
  await call('specialist_gateway_force_retire',{...args,p_phase:'begin'});
  // Actual Storage API deletes bytes AND its metadata. Never SQL-delete storage.objects.
  check(await admin.storage.from('specialist-media').remove([r.object_name]));
  await call('specialist_gateway_force_retire',{...args,p_phase:'finish'});
 }
 inventory=await call('specialist_gateway_erasure_inventory');
 if(inventory.objects.length||inventory.reservations.length)throw Error('Erasure incomplete; retain account/profile and retry');
 return {media_erased:true,profile,account_deleted:false};
}
export async function readGatewayAlerts(admin){
 const {data,error}=await admin.rpc('specialist_gateway_metrics');if(error)throw error;
 // Consumers must persist/deliver this alert in approved infrastructure; no fake alert delivery here.
 return {...data,alert:!!data.alert||data.over_quota_profiles>0};
}
