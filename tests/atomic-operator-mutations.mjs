import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {pathToFileURL} from 'node:url';import crypto from 'node:crypto';import pg from 'pg';
const url=new URL(process.env.TEST_DATABASE_URL||'');assert(['127.0.0.1','localhost','::1','[::1]'].includes(url.hostname)&&url.pathname==='/otzovik_acceptance','Only disposable loopback DB allowed');
const pool=new pg.Pool({connectionString:url.toString()}),dir=await fs.mkdtemp(path.join(os.tmpdir(),'atomic-mutant-'));const source=await fs.readFile(new URL('./fixtures/atomic-operator-model.mjs',import.meta.url),'utf8');
try{await pool.query(await fs.readFile(new URL('./fixtures/atomic-operator-model.sql',import.meta.url),'utf8'));
 const cases=[['aud','p.aud===call.action&&',''],['target','p.target===call.target&&',''],['consume','ON CONFLICT DO NOTHING RETURNING jti','ON CONFLICT (jti) DO UPDATE SET jti=EXCLUDED.jti RETURNING jti']];
 for(const [kind,oldValue,newValue] of cases){assert(source.includes(oldValue),'mutation anchor missing');let file=path.join(dir,kind+'.mjs');await fs.writeFile(file,source.replace(oldValue,newValue));let {atomicModel}=await import(pathToFileURL(file));let m=atomicModel(pool,{now:()=>1000}),sub=crypto.randomUUID(),target=crypto.randomUUID(),nonce=crypto.randomUUID();await m.register(sub,crypto.randomUUID());let token=await m.issue(sub,'plan_erasure',target,nonce),call={sub,action:'plan_erasure',target,nonce};
 if(kind==='aud'){let r=await m.consume(token,{...call,action:'authorize'});assert.equal(r.outcome,'done','aud mutation should violate negative expectation');}
 if(kind==='target'){let r=await m.consume(token,{...call,target:crypto.randomUUID()});assert.equal(r.outcome,'done','target mutation should violate negative expectation');}
 if(kind==='consume'){await m.consume(token,call);let r=await m.consume(token,call);assert.equal(r.outcome,'rejected','consume mutation should turn replay rejection into a committed response');}
 }
 console.log('PASS mutation detection: removing aud/target/atomic consume breaks the corresponding negative expectation');
}finally{await pool.end();await fs.rm(dir,{recursive:true,force:true});}
