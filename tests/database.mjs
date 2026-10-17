import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import {migrationSQL} from '../scripts/specialist-migration.mjs';
export const A='11111111-1111-4111-8111-111111111111';
export const B='22222222-2222-4222-8222-222222222222';
export async function database(){
 const url=process.env.TEST_DATABASE_URL;
 let pool,embedded;
 if(url){
  const u=new URL(url);
  assert(['localhost','127.0.0.1','::1','[::1]'].includes(u.hostname)&&u.pathname==='/otzovik_acceptance','Only disposable loopback otzovik_acceptance DB allowed');
  pool=new pg.Pool({connectionString:url});
 }else embedded=new PGlite();
 const query=(sql,args)=>pool?pool.query(sql,args):embedded.query(sql,args);
 const exec=sql=>pool?pool.query(sql):embedded.exec(sql);
 await exec(await fs.readFile(new URL('./fixtures/schema.sql',import.meta.url),'utf8'));
 await exec(await fs.readFile(new URL('./fixtures/company-rpcs-before.sql',import.meta.url),'utf8'));
 // Existing company must survive registry backfill unchanged.
 await query("INSERT INTO auth.users VALUES ($1),($2)",[A,B]);
 await query("INSERT INTO public.companies(id,slug,name) VALUES ('33333333-3333-4333-8333-333333333333','existing-company','Existing')");
 const before=(await query('SELECT row_to_json(c) data FROM companies c')).rows;
 await exec(await migrationSQL());
 assert.deepEqual((await query('SELECT row_to_json(c) data FROM companies c')).rows,before);
 async function session(uid,fn,role='authenticated'){
  const c=pool?await pool.connect():embedded;
  try{
   await c.query('BEGIN');
   await c.query(`SET LOCAL ROLE ${role}`);
   await c.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[uid||'']);
   const result=await fn(c);
   await c.query('COMMIT');return result;
  }catch(e){await c.query('ROLLBACK');throw e;}
  finally{if(pool)c.release();}
 }
 const call=(uid,name,args=[])=>session(uid,async c=>(await c.query(`SELECT public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) data`,args)).rows[0].data);
 return {query,exec,session,call,concurrent:!!pool,close:()=>pool?pool.end():embedded.close()};
}
