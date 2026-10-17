// Generate an isolated CLI workspace. Never links to a hosted Supabase project.
import fs from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
const dir='/tmp/otzovik-supabase';
await fs.mkdir(dir,{recursive:true});
try{await fs.access(dir+'/supabase/config.toml');}catch{execFileSync('npx',['supabase','init','--workdir',dir],{stdio:'inherit'});}
let config=await fs.readFile(dir+'/supabase/config.toml','utf8');
config=config.replace(/^project_id = .*$/m,'project_id = "otzovik-local-acceptance"')
 .replace(/^site_url = .*$/m,'site_url = "http://cabinet.test/account-login.html"')
 .replace(/^additional_redirect_urls = .*$/m,'additional_redirect_urls = ["http://cabinet.test/**"]')
 .replace(/(\[auth.email\][\s\S]*?)enable_confirmations = false/,'$1enable_confirmations = true');
await fs.writeFile(dir+'/supabase/config.toml',config);
console.log('Prepared isolated local Supabase configuration; email confirmation enabled');
