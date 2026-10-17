// Explicit public-file manifest: never copy the repository root into Pages.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
export async function buildPages(source=root,output=path.join(root,'_site')){
 const files=JSON.parse(await fs.readFile(path.join(source,'scripts/pages-files.json'),'utf8'));
 if(!Array.isArray(files)||new Set(files).size!==files.length)throw Error('Invalid public manifest');
 const allowed=new Set(files),contents=new Map();
 for(const file of files){
  if(typeof file!=='string'||file.includes('..')||file.includes('\\')||path.isAbsolute(file)||
     !/^(?:[a-z][a-z0-9-]*\.(?:html|css|js)|profile\.(?:json|md)|reviews\.json|llms\.txt|\.nojekyll|reviews\/index\.html)$/.test(file))throw Error('Unsafe public path: '+file);
  const target=path.join(source,file);
  if(!(await fs.lstat(target)).isFile())throw Error('Public file must be regular: '+file);
  const resolved=await fs.realpath(target);
  if(!resolved.startsWith((await fs.realpath(source))+path.sep))throw Error('Public path escapes source: '+file);
  contents.set(file,await fs.readFile(target));
 }
 // Static HTML/CSS resource references; runtime data URLs are tested in browser acceptance.
 for(const [file,bytes] of contents){
  if(!/\.(html|css)$/.test(file))continue;
  const sourceText=bytes.toString().replace(/(<script\b[^>]*>)[\s\S]*?<\/script>/gi,'$1</script>');
  const refs=[...sourceText.matchAll(/\b(?:src|href)\s*=\s*["']([^"']+)["']/gi),...sourceText.matchAll(/url\(\s*["']?([^\s"')]+)["']?\s*\)/gi)];
  for(const [,ref] of refs){
   if(/^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(ref)||ref.includes('${'))continue;
   const url=new URL(ref,'https://artifact.invalid/'+file);
   let local=decodeURIComponent(url.pathname.slice(1));if(local.endsWith('/'))local+='index.html';
   if(!allowed.has(local))throw Error(`Missing public dependency: ${file} -> ${ref}`);
  }
 }
 // Validate everything before replacing our build output. Never accept output=source.
 const dest=path.resolve(output),src=await fs.realpath(source);
 if(dest===src||src.startsWith(dest+path.sep))throw Error('Unsafe output directory');
 await fs.rm(dest,{recursive:true,force:true});
 for(const [file,bytes] of contents){await fs.mkdir(path.dirname(path.join(dest,file)),{recursive:true});await fs.writeFile(path.join(dest,file),bytes);}
 return files;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const files=await buildPages();console.log(`PASS Pages artifact: ${files.length} reviewed public files; static references resolved`);}
