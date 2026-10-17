import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {buildPages} from '../scripts/build-pages.mjs';
const root=new URL('../',import.meta.url).pathname;
const temp=await fs.mkdtemp(path.join(os.tmpdir(),'otzovik-pages-'));
try{
 const output=path.join(temp,'public');const files=await buildPages(root,output);
 for(const file of files)assert.deepEqual(await fs.readFile(path.join(output,file)),await fs.readFile(path.join(root,file)));
 for(const file of ['sql','tests','scripts','docs','agent-logs','node_modules','package.json','.github'])await assert.rejects(fs.stat(path.join(output,file)),{code:'ENOENT'});
 for(const file of ['account-create-specialist.html','account-company-context.js','account-mobile-swipe.js','profile.json','reviews/index.html','.nojekyll'])assert(files.includes(file));
 const source=path.join(temp,'fixture');await fs.mkdir(path.join(source,'scripts'),{recursive:true});
 await fs.writeFile(path.join(source,'index.html'),'<link href="missing.css">');
 await fs.writeFile(path.join(source,'scripts/pages-files.json'),JSON.stringify(['index.html']));
 await assert.rejects(buildPages(source,output),/Missing public dependency/);
 assert(await fs.stat(path.join(output,'index.html'))); // Failed validation preserves prior artifact.
 await fs.writeFile(path.join(source,'scripts/pages-files.json'),JSON.stringify(['../index.html']));
 await assert.rejects(buildPages(source,output),/Unsafe public path/);
 await fs.writeFile(path.join(source,'scripts/pages-files.json'),JSON.stringify(['public.js']));
 await fs.symlink(path.join(root,'account-company-context.js'),path.join(source,'public.js'));
 await assert.rejects(buildPages(source,output),/must be regular/);
 console.log(`PASS Pages: ${files.length} byte-identical files; dependencies, exclusions, traversal and symlink guards`);
}finally{await fs.rm(temp,{recursive:true,force:true});}
