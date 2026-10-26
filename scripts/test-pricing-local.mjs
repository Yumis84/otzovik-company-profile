// Disposable local PostgreSQL17 only. Does not connect to hosted projects.
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import cp from 'node:child_process';import net from 'node:net';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';import pg from 'pg';
const root=fileURLToPath(new URL('../',import.meta.url)),bin=process.env.PG_BIN||'',suffix=process.platform==='win32'?'.exe':'';
const exe=name=>bin?path.join(bin,name+suffix):name;
const version=cp.execFileSync(exe('postgres'),['--version'],{encoding:'utf8'}).trim();if(!/PostgreSQL\) 17\./.test(version))throw Error('PostgreSQL17 required');
const allowed=['tests/specialist-pricing.mjs','tests/specialist-pricing-browser.mjs','tests/specialist-pricing-media-races.mjs'];
const tests=process.argv.length>2?process.argv.slice(2):allowed;for(const file of tests)if(!allowed.includes(file))throw Error('Unknown test');
for(const file of tests){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'otzovik-pricing-')),pw=path.join(dir,'init-password'),data=path.join(dir,'data'),password=crypto.randomUUID();let started=false,exit=1;
 const server=net.createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;await new Promise(r=>server.close(r));
 try{
  fs.writeFileSync(pw,password);cp.execFileSync(exe('initdb'),['-D',data,'-U','postgres','--pwfile='+pw,'--auth=scram-sha-256','--encoding=UTF8','--locale=C'],{stdio:'ignore'});fs.unlinkSync(pw);
  cp.execFileSync(exe('pg_ctl'),['-D',data,'-l',path.join(dir,'server.log'),'-o','-h 127.0.0.1 -p '+port,'-w','start'],{stdio:'ignore'});started=true;
  const c=new pg.Client({host:'127.0.0.1',port,user:'postgres',password,database:'postgres'});await c.connect();await c.query('CREATE DATABASE otzovik_acceptance');await c.end();
  console.log('ENGINE',version,'TEST',file);
  const child=cp.spawn(process.execPath,[file],{cwd:root,env:{...process.env,TEST_DATABASE_URL:'postgres://postgres:'+encodeURIComponent(password)+'@127.0.0.1:'+port+'/otzovik_acceptance'},stdio:'inherit'});
  exit=(await new Promise(r=>child.on('exit',r)))??1;
 }finally{
  if(started)cp.execFileSync(exe('pg_ctl'),['-D',data,'-m','fast','-w','stop'],{stdio:'ignore'});
  fs.rmSync(dir,{recursive:true,force:true});
 }
 if(exit!==0)process.exit(exit);
}
