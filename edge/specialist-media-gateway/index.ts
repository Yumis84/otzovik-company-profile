import {createMediaGateway} from './specialist-media-gateway.js';
const origins=(Deno.env.get('SPECIALIST_ALLOWED_ORIGINS')||'').split(',').map(s=>s.trim()).filter(Boolean);
if(!origins.length)throw Error('Explicit SPECIALIST_ALLOWED_ORIGINS required');
Deno.serve(createMediaGateway({url:Deno.env.get('SUPABASE_URL'),anonKey:Deno.env.get('SUPABASE_ANON_KEY'),serviceKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),origins}));
