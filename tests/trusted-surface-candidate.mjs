import assert from 'node:assert/strict';import {compare,verifyTrustedSurface,protectedPaths} from '../scripts/trusted-surface-candidate.mjs';
for(const path of protectedPaths){const original=Buffer.from('trusted bytes'),modified=Buffer.from('tampered and rehashed');compare(path,original,original);assert.throws(()=>compare(path,original,modified),/Trusted surface changed/);}
verifyTrustedSurface();console.log('PASS candidate trust-surface mutation checks; PR-supplied check itself is not trusted');
