import assert from 'node:assert/strict';import crypto from 'node:crypto';import fs from 'node:fs/promises';import {database,A} from './database.mjs';
const db=await database({editor:true});assert(db.concurrent,'Real loopback PostgreSQL required');
try{
 await db.exec(await fs.readFile(new URL('../supabase/migrations/20261026040132_specialist_service_pricing_candidate.sql',import.meta.url),'utf8'));
 const a=await db.call(A,'create_my_specialist_draft',['Race profile','pricing-races','Master']);
 const path=a.id+'/portfolio/'+crypto.randomUUID()+'.webp',meta=JSON.stringify({size:100,mimetype:'image/webp'});
 let inserted,release;const hasInserted=new Promise(r=>inserted=r),hold=new Promise(r=>release=r);
 const upload=db.session(A,async c=>{await c.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path,meta]);inserted();await hold;});
 await hasInserted;const deletion=db.call(A,'delete_my_specialist_draft',[a.id]).then(()=>({ok:true}),e=>({code:e.code}));await new Promise(r=>setTimeout(r,100));release();await upload;assert.equal((await deletion).code,'55000');
 console.log('PASS MEDIA RACE1 upload vs profile-delete: deletion refuses while object remains');
 const reg=await db.call(A,'register_my_specialist_media',[a.id,path,'portfolio',null]);assert(reg.id);
 let locked,unlock;const hasLocked=new Promise(r=>locked=r),wait=new Promise(r=>unlock=r);
 const serviceId=crypto.randomUUID();
 const saving=db.session(A,async c=>{await c.query("SELECT save_my_specialist_service_v2($1,$2,'Race service',NULL,'priced','hour',1,NULL,'RUB',NULL,true,NULL)",[a.id,serviceId]);locked();await wait;});
 await hasLocked;const path2=a.id+'/portfolio/'+crypto.randomUUID()+'.webp';
 const upload2=db.session(A,c=>c.query("INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('specialist-media',$1,$2)",[path2,meta]));
 const delete2=db.call(A,'delete_my_specialist_draft',[a.id]).then(()=>({ok:true}),e=>({code:e.code}));
 await new Promise(r=>setTimeout(r,100));unlock();await Promise.all([saving,upload2]);assert.equal((await delete2).code,'55000');
 assert.equal((await db.call(A,'get_my_specialist_services',[a.id])).find(r=>r.id===serviceId).version,1);
 console.log('PASS MEDIA RACE2 price-save vs upload vs profile-delete: no deadlock, price commits once');
 await db.session(A,c=>c.query("DELETE FROM storage.objects WHERE bucket_id='specialist-media' AND name=$1",[path]));
 await db.call(A,'delete_my_specialist_media',[a.id,reg.id]);assert.equal((await db.call(A,'get_my_specialist_media',[a.id])).length,0);
 console.log('PASS MEDIA RACE3 existing Storage-first removal and metadata delete still work');
}finally{await db.close();}
