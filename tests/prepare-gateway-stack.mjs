import './prepare-local-stack.mjs';import fs from 'node:fs/promises';
const target='/tmp/otzovik-supabase/supabase/functions/specialist-media-gateway';await fs.mkdir(target,{recursive:true});
await fs.copyFile(new URL('../edge/specialist-media-gateway/index.ts',import.meta.url),target+'/index.ts');
await fs.copyFile(new URL('../server/specialist-media-gateway.js',import.meta.url),target+'/specialist-media-gateway.js');
await fs.writeFile('/tmp/otzovik-gateway.env','SPECIALIST_ALLOWED_ORIGINS=http://127.0.0.1:4173\n');
console.log('Prepared isolated Edge gateway, explicit loopback Origin; no hosted link');
