import fs from 'node:fs';import cp from 'node:child_process';import assert from 'node:assert/strict';import crypto from 'node:crypto';
const root=new URL('../',import.meta.url);
const basis='76b3fa7a99df04d320b022a5a777fdbdf897b826';
const contextImport="import {installNavigation} from './account-shared-navigation.js';\n";
const anchor="ensureHomeNav();\nensureSourcesNav();\n";
const install="installNavigation(document.querySelector('main nav[aria-label=\"Навигация кабинета\"]'));\n";
const cssAddition='/* Keep the existing profile form within narrow mobile viewports. */\n.editor-layout .editor,.editor-layout .editor fieldset{min-width:0}\n@media(max-width:400px){.editor-head{flex-wrap:wrap}}\n';
export function approvedCompanyVersion(file,original){
 if(file==='account-company-context.js'){
  assert.equal(original.split(anchor).length,2,'Company navigation insertion anchor must be unique');
  return contextImport+original.replace(anchor,anchor+install);
 }
 if(file==='account-profile.css')return original+cssAddition;
 if(file==='account-home.html'){
  const old='<span class="status">Черновик · только вам</span>';
  assert.equal(original.split(old).length,2,'Specialist status replacement must be unique');
  return original.replace(old,'<span class="status">Публикация — в редакторе</span>');
 }
 return original;
}
export function checkCompanyBytes(file,original,actual){
 if(file==='account-profile.html'){
  assert.equal(crypto.createHash('sha256').update(actual).digest('hex'),'9470e3d9bfcce336ecf623acb3b5c4c3564e6b73d65c872c1cfa093e60137401','Unexpected company change: '+file);
  return;
 }
 if(file==='account-access.html'){
  assert.equal(crypto.createHash('sha256').update(actual).digest('hex'),'344a4fb0e9bf16abcc3b6bdca462dd3f03151adfdfaf0ac5f9f26c6e80e507e5','Unexpected company change: '+file);
  return;
 }
assert.equal(actual,approvedCompanyVersion(file,original),'Unexpected company change: '+file);}
export function checkCompanyIntegrity(manifest){
 assert.equal(manifest.basis,basis,'Company baseline cannot drift');
 const git=(...args)=>cp.execFileSync('git',args,{cwd:root,encoding:'utf8'});
 const protectedSource=JSON.parse(git('show','a5a9a09c75646337b3037e6d62cc3281cd625d99:docs/SPECIALIST_GATEWAY_HASHES_2026-10-27.json'));
 assert.deepEqual(manifest.companySource,protectedSource.companySource,'Protected company file list cannot be weakened');
 for(const file of manifest.companySource.files){const original=git('show',basis+':'+file),actual=git('show','HEAD:'+file);checkCompanyBytes(file,original,actual);assert.equal(fs.readFileSync(new URL('../'+file,import.meta.url),'utf8').replace(/\r\n/g,'\n'),actual,'Worktree differs from HEAD: '+file);}
 const changed=git('diff','--name-only',basis,'HEAD','--','account*.html','account*.js','account*.css').trim().split('\n').filter(Boolean);
 for(const file of changed){if(file.startsWith('account-specialist-')||file==='account-create-specialist.html')continue;assert(['account-company-context.js','account-profile.css','account-shared-navigation.js','account-home.html','account-access.html','account-profile.html'].includes(file),'Unexpected company path: '+file);}
 const shared=fs.readFileSync(new URL('../account-shared-navigation.js',import.meta.url),'utf8').replace(/\r\n/g,'\n');
 const expected='261c7d602b1ed94b63466e4b8e7d9bc65e4dfdd33a852c0d02060cc682b6788e';assert.equal(crypto.createHash('sha256').update(shared).digest('hex'),expected,'Shared navigation drift');
 assert.equal(git('show','HEAD:account-shared-navigation.js'),shared,'Shared navigation worktree drift');
 console.log('PASS company guard: '+manifest.companySource.files.length+' protected files; three exact transformations, pinned invitation escaping and pinned shared menu');
}
