import {createMediaGateway} from './specialist-media-gateway.js';
const origins=["https://otzovik-pr51-preview-f4umbebw5-yumis84-7003s-projects.vercel.app","https://otzovik-pr51-preview-n99qbj9rv-yumis84-7003s-projects.vercel.app"];
if(!origins.length)throw Error('Explicit SPECIALIST_ALLOWED_ORIGINS required');
Deno.serve(createMediaGateway({url:Deno.env.get('SUPABASE_URL'),anonKey:Deno.env.get('SUPABASE_ANON_KEY'),serviceKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),origins}));
