import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {build} from 'esbuild';
const root=fileURLToPath(new URL('../../../',import.meta.url));
export async function testServer(cfg){
 if(!['127.0.0.1','localhost'].includes(new URL(cfg.API_URL).hostname))throw Error('Loopback only');
 const vendor=await build({stdin:{contents:"export {createClient} from '@supabase/supabase-js';",resolveDir:root},bundle:true,format:'esm',write:false,platform:'browser'});
 const server=http.createServer(async(req,res)=>{res.setHeader('Cache-Control','no-store');try{const u=new URL(req.url,'http://127.0.0.1:18890');const name=u.pathname.slice(1);if(name==='cabinet-test-config.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({url:cfg.API_URL,anonKey:cfg.ANON_KEY,endpoint:cfg.API_URL+'/functions/v1/cabinet-assistant'}));return;}if(name==='vendor/supabase.js'){res.setHeader('Content-Type','text/javascript');res.end(vendor.outputFiles[0].text);return;}if(!/^account-[a-z-]+\.(html|js|css)$/.test(name))throw Error('Not found');let text=await fs.readFile(path.join(root,name),'utf8');text=text.replaceAll('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm','/vendor/supabase.js').replaceAll('https://rzhlcszqtuhkhfibygnk.supabase.co',cfg.API_URL).replaceAll('sb_publishable_yhqWJ1eWUznBkqKwPogTrw_xCdCbFA-',cfg.ANON_KEY);
 if(name.endsWith('.html')){text=text.replace(/<link[^>]+rel="icon"[^>]*>/g,'');if(name==='account-profile.html')text=text.replace('</body>','<script type="module" src="account-assistant-launcher.js"></script></body>');}
 res.setHeader('Content-Type',name.endsWith('.js')?'text/javascript':name.endsWith('.css')?'text/css':'text/html;charset=utf-8');res.end(text);
 }catch{res.statusCode=404;res.end('Not found');}});await new Promise(r=>server.listen(18890,'127.0.0.1',r));return server;
}
