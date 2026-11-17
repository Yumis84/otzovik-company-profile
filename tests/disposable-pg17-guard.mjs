// Pre-connection gate only: this does not prove that the process at loopback is disposable.
// The runner MUST additionally attest clean Docker, create its own stack and pin its identity.
export function validateDisposableConfiguration(env, connectionString) {
  if (env.GITHUB_ACTIONS !== 'true' || env.RUNNER_ENVIRONMENT !== 'github-hosted') throw new Error('GitHub-hosted runner required');
  if (env.OTZ_DISPOSABLE_CONFIRM !== 'new-stack-only') throw new Error('Disposable attestation missing');
  for (const key of ['DOCKER_HOST','SUPABASE_ACCESS_TOKEN','PGHOST','PGHOSTADDR','PGSERVICE','PGSERVICEFILE','PGDATABASE','PGUSER','PGPASSWORD','PGPORT','PGOPTIONS','PGSSLMODE','DATABASE_URL']) {
    if (env[key]) throw new Error(`Unexpected connection environment: ${key}`);
  }
  let url;
  try { url = new URL(connectionString); } catch { throw new Error('Invalid disposable URL'); }
  if (!['postgres:','postgresql:'].includes(url.protocol) || url.hostname !== '127.0.0.1' || url.port !== '54322' || url.pathname !== '/postgres' || url.search || url.hash) throw new Error('Only the pinned loopback endpoint is permitted');
  if (!url.username || !url.password) throw new Error('Local test credentials required');
  return {host:'127.0.0.1',port:54322,database:'postgres',user:decodeURIComponent(url.username),password:decodeURIComponent(url.password),ssl:false,connectionTimeoutMillis:3000};
}
