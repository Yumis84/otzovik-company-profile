import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {database,A,B} from './database.mjs';
if(process.env.TEST_DATABASE_URL && process.env.TEST_DATABASE_URL!=='postgres://postgres@127.0.0.1:55449/otzovik_acceptance')throw Error('Local disposable fixture only');
const db=await database({editor:true});
const read=p=>fs.readFile(p,'utf8');
const catalog=async()=>({
 funcs:(await db.query("select p.oid::regprocedure::text sig,md5(prosrc) hash,proacl::text acl,proconfig from pg_proc p where pronamespace='public'::regnamespace order by 1")).rows,
 tables:(await db.query("select relname from pg_class where relnamespace='public'::regnamespace and relkind='r' order by 1")).rows.map(x=>x.relname),
 triggers:(await db.query("select tgname, tgrelid::regclass::text tab from pg_trigger where not tgisinternal and tgrelid in(select oid from pg_class where relnamespace in('public'::regnamespace,'storage'::regnamespace)) order by 1")).rows,
 policies:(await db.query("select policyname,schemaname,tablename,cmd,roles,qual,with_check,permissive from pg_policies order by 1")).rows
});
try{
 await db.exec('DROP TRIGGER specialist_object_integrity ON storage.objects');
 await db.exec(await read('sql/20261027_specialist_channels_CANDIDATE.sql'));
 await db.exec(await read('staging/recovery/baseline-functions.sql'));
 await db.exec("UPDATE storage.buckets SET file_size_limit=5242880,allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp'] WHERE id='specialist-media';");
 await db.exec(`CREATE ROLE authenticator NOLOGIN; CREATE SCHEMA media_internal;
 CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$SELECT string_to_array($1,'/')$$;
 CREATE FUNCTION storage.allow_any_operation(text[]) RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
 CREATE FUNCTION media_internal.is_published_company_media_object(text) RETURNS boolean LANGUAGE sql AS $$SELECT false$$;`);
 await db.exec(await read('staging/recovery/fixture-company-policies.sql'));
 await db.exec('CREATE ROLE supabase_storage_admin NOLOGIN; GRANT USAGE ON SCHEMA storage,public TO supabase_storage_admin; ALTER TABLE storage.objects OWNER TO supabase_storage_admin');

 const ids=[];for(let i=0;i<7;i++)ids.push((await db.call(i%2?B:A,'create_my_specialist_draft',['Owner','recovery-'+i,'Master'])).id);
 const seed=async(i,matched)=>{
 const path=ids[i]+'/portfolio/'+crypto.randomUUID()+'.png';
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('specialist-media',$1,'{\"size\":1024,\"mimetype\":\"image/png\"}')",[path]);
 if(matched)await db.query("insert into specialist_media(specialist_id,object_name,kind) values($1,$2,'portfolio')",[ids[i],path]);};
 for(let i=0;i<3;i++)await seed(i,i<2);
 const inventory=async()=> (await db.query("select (select jsonb_agg(to_jsonb(m) order by id) from specialist_media m) media,(select jsonb_agg(to_jsonb(o) order by id) from storage.objects o) objects,(select jsonb_agg(to_jsonb(p)-'version' order by id) from specialist_profiles p) profiles")).rows[0];
 const data=await inventory(),before=await catalog();
 await db.exec(await read(process.argv[2]+'/01-install.sql'));
 const after=await catalog();assert.deepEqual(await inventory(),data);
 assert.equal((await db.query('select count(*)::int n from specialist_upload_reservations where state=\'ready\'')).rows[0].n,2);
 await db.exec(await read(process.argv[2]+'/02-enable-media.sql'));await db.exec(await read(process.argv[2]+'/03-enable-public.sql'));
 const options=await db.call(A,'get_my_specialist_public_options_v1',[ids[0]]);
 assert.equal(options.filter(x=>x.type==='photo').length,1);
 await assert.rejects(db.call(B,'get_my_specialist_public_options_v1',[ids[0]]),e=>e.code==='42501');
 const rid=crypto.randomUUID(),request=[A,ids[0],rid,'portfolio','a'.repeat(64),'image/png',10,null];
 const serviceRpc=(query,args)=>db.session(null,c=>c.query(query,args),'service_role');
 const reserve='select specialist_gateway_reserve($1,$2,$3,$4,$5,$6,$7,$8) r';
 const added=(await serviceRpc(reserve,request)).rows[0].r;assert(added.upload_allowed);
 assert.equal((await serviceRpc(reserve,request)).rows[0].r.upload_allowed,false);
 await assert.rejects(serviceRpc(reserve,[B,...request.slice(1)]),e=>e.code==='42501');
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('specialist-media',$1,'{\"size\":10,\"mimetype\":\"image/png\"}')",[added.object_name]);
 await serviceRpc('select specialist_gateway_finish($1,$2,$3)',[A,ids[0],rid]);
 await serviceRpc('select specialist_gateway_begin_delete($1,$2,$3)',[A,ids[0],added.object_name]);
 await db.query("delete from storage.objects where bucket_id='specialist-media' and name=$1",[added.object_name]);
 await serviceRpc('select specialist_gateway_finish_delete($1,$2,$3)',[A,ids[0],rid]);
 assert.deepEqual(await inventory(),data);
 const receipt=await db.call(A,'publish_my_specialist_details_v1',[ids[0],1,crypto.randomUUID(),JSON.stringify(options)]);
 assert(receipt.published);
 assert.equal((await db.session(null,c=>c.query("select get_public_specialist_v1('recovery-0') d"),'anon')).rows[0].d.items.length,1);
 await db.call(A,'unpublish_my_specialist_v1',[ids[0]]);
 assert.equal((await db.session(null,c=>c.query("select get_public_specialist_v1('recovery-0') d"),'anon')).rows[0].d,null);
 await fs.writeFile(process.argv[2]+'/catalog-delta.json',JSON.stringify({before,after}));
 if(process.argv[3]){
 await db.exec(await read(process.argv[2]+'/80-quiesce.sql'));
 const digestQuery=await read(process.argv[2]+'/archive-digest.sql');
 const digest=(await db.query(digestQuery)).rows[0].md5;
 const archive=(await db.query(await read(process.argv[2]+'/archive-query.sql'))).rows.map(row=>Object.values(row)[0]).join('\n');
 const {createHash}=await import('node:crypto');
 assert.equal(createHash('md5').update(archive).digest('hex'),digest);
 await assert.rejects(db.exec(await read(process.argv[3])),/archive missing or stale/);
 await db.exec('ROLLBACK');
 await db.query("select set_config('otz.recovery_archive_digest',$1,false)",[digest]);
 await db.exec(await read(process.argv[3]));assert.deepEqual(await inventory(),data);assert.deepEqual(await catalog(),before);
 await db.exec(await read(process.argv[2]+'/baseline-check.sql'));
 }
 console.log('PASS recovery: 7 profiles, 2 registered photos, 3 objects, historical media, foreign denial, publication, unpublish'+(process.argv[3]?', inverse catalog and data equivalence':''));
}finally{await db.close();}
