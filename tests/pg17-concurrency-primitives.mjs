// Driver primitives only. No connection is opened by importing this file.
// Callers must prove a newly created isolated Supabase before supplying clients.
export async function waitForBlocked({observer, blockedPid, blockingPid, timeoutMs=3000}) {
  const until=Date.now()+timeoutMs;
  while(Date.now()<until){
    const {rows}=await observer.query('SELECT $1::int = ANY(pg_catalog.pg_blocking_pids($2::int)) AS blocked',[blockingPid,blockedPid]);
    if(rows[0]?.blocked===true)return;
    await new Promise(resolve=>setTimeout(resolve,25));
  }
  throw new Error('Expected blocking relation not observed before deadline');
}
export async function closeClients(clients){
  const outcomes=await Promise.allSettled(clients.map(client=>client.end()));
  if(outcomes.some(outcome=>outcome.status==='rejected'))throw new Error('One or more test connections failed to close');
}
