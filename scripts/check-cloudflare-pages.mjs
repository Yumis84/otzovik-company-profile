// Read-only validation of the exact static artifact; never deploy a Worker.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const output=path.join(root,'_site');
const manifest=JSON.parse(await fs.readFile(path.join(root,'scripts/pages-files.json'),'utf8'));
const expected=new Set(manifest),actual=[];
async function walk(dir,prefix=''){
 for(const entry of await fs.readdir(dir,{withFileTypes:true})){
  const name=prefix+entry.name;
  if(entry.isDirectory())await walk(path.join(dir,entry.name),name+'/');
  else if(entry.isFile())actual.push(name);
  else throw Error('Non-regular artifact entry: '+name);
 }
}
await walk(output);
if(actual.length!==expected.size||actual.some(p=>!expected.has(p)))throw Error('Artifact differs from public allowlist');
const sha256=b=>createHash('sha256').update(b).digest('hex');
const files=[];
for(const name of actual.sort()){
 const bytes=await fs.readFile(path.join(output,name));
 const original=await fs.readFile(path.join(root,name));
 if(!bytes.equals(original))throw Error('Artifact differs from reviewed source: '+name);
 const text=bytes.toString('utf8');
 if(/sb_secret_[A-Za-z0-9_-]+/.test(text))throw Error('Secret key pattern in artifact: '+name);
 for(const jwt of text.matchAll(/eyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+/g)){
  let payload;try{payload=JSON.parse(Buffer.from(jwt[1],'base64url'));}catch{continue;}
  if(payload.role==='service_role')throw Error('Privileged JWT in artifact: '+name);
 }
 files.push({path:name,bytes:bytes.length,sha256:sha256(bytes)});
}
const swipe=await fs.readFile(path.join(output,'account-mobile-swipe.js'),'utf8');
if(!/^\s*\/\*[\s\S]*?\*\/\s*$/.test(swipe))throw Error('Page swipe entrypoint must remain inert');
await fs.mkdir(path.join(root,'reports'),{recursive:true});
await fs.writeFile(path.join(root,'reports/cloudflare-pages-artifact.json'),JSON.stringify({schema:1,buildCommand:'node scripts/build-pages.mjs',output:'_site',files},null,2)+'\n');
console.log('PASS Cloudflare Pages readiness: '+files.length+' byte-identical allowlisted files; no privileged key patterns; no page swipe; hashes outside public artifact');
