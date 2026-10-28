// Defense-in-depth candidate. This file is NOT a trust root when executed from an untrusted PR.
// An independently controlled required CI workflow must supply the immutable expected commit
// and perform these checks before running any PR-controlled script.
import {execFileSync} from 'node:child_process';import {fileURLToPath} from 'node:url';import assert from 'node:assert/strict';
export const anchor='f809b76296b4181c1f52d3bee4692f95f3a26312';
export const protectedPaths=['scripts/company-integrity.mjs','tests/company-integrity.mjs','tests/gateway-integrity.mjs','docs/SPECIALIST_GATEWAY_HASHES_2026-10-27.json','.github/workflows/specialist-gateway.yml','.github/workflows/shared-navigation.yml','.github/workflows/pages.yml','.github/workflows/local-supabase-acceptance.yml','.github/workflows/specialist-acceptance.yml','.github/workflows/specialist-channels.yml','.github/workflows/specialist-release-browser.yml','index.html','profile.html','profile.css','profile.json','profile.md'];
export function compare(path,base,candidate){assert.deepEqual(candidate,base,'Trusted surface changed: '+path);}
export function verifyTrustedSurface(){
 const cwd=new URL('../',import.meta.url),git=(...args)=>execFileSync('git',args,{cwd});
 for(const p of protectedPaths){const base=git('show',anchor+':'+p),candidate=git('show','HEAD:'+p);compare(p,base,candidate);}
 console.log('PASS candidate anchored surface: '+protectedPaths.length+' paths match PR44; requires independently enforced CI');
}
if(process.argv[1]===fileURLToPath(import.meta.url))verifyTrustedSurface();
