import {createHandler} from './handler.mjs';
// Production deployment is NOT authorized. LLM/network retrieval remain absent.
Deno.serve(createHandler({url:Deno.env.get('SUPABASE_URL'),anonKey:Deno.env.get('SUPABASE_ANON_KEY'),origins:(Deno.env.get('CABINET_ALLOWED_ORIGINS')||'').split(',').map(x=>x.trim()).filter(Boolean)}));
