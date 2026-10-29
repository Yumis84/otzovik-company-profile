// Synthetic detector only. The caller must supply this policy and seed from an independent trusted source.
// A PR-controlled copy (including tests and CI) cannot enforce itself.
import {execFileSync} from 'node:child_process';import assert from 'node:assert/strict';
export const anchor='400d16123ec9e09e5db2d425a9742f59231ff291';
const root=new URL('../',import.meta.url);const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8'});
export function baselinePaths(){const pages=JSON.parse(git('show',anchor+':scripts/pages-files.json'));const workflows=git('ls-tree','-r','--name-only',anchor,'--','.github/workflows').trim().split('\n').filter(Boolean);return [...new Set([...pages,...workflows,'package.json','package-lock.json','scripts/pages-files.json','scripts/company-integrity.mjs','scripts/trusted-surface-candidate.mjs','tests/company-integrity.mjs','tests/gateway-integrity.mjs','tests/trusted-surface-candidate.mjs','docs/SPECIALIST_GATEWAY_HASHES_2026-10-27.json'])].sort();}
export function compare(path,expected,actual){assert.equal(actual,expected,'protected path changed: '+path);}
export function checkAnchored(){for(const p of baselinePaths())compare(p,git('show',anchor+':'+p),git('show','HEAD:'+p));return baselinePaths().length;}
