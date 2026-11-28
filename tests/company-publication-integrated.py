"""Run against a NEW disposable PG17 database; never hosted."""
import argparse, importlib.util, json, pathlib, subprocess, tempfile, uuid, concurrent.futures
p=argparse.ArgumentParser();p.add_argument('--sql-root',required=True);p.add_argument('--generator-root',required=True);p.add_argument('--psql',required=True);p.add_argument('--fixture-root',default=str(pathlib.Path(__file__).parent));p.add_argument('--database',default='completion_v1');a=p.parse_args()
root=pathlib.Path(a.sql_root); gen=pathlib.Path(a.generator_root); fixtures=pathlib.Path(a.fixture_root)
spec=importlib.util.spec_from_file_location('worker',gen/'company-publication-worker.py');w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
db=w.Database(a.psql,55487,a.database); admin=w.Database(a.psql,55487,'postgres')
admin.query('CREATE DATABASE '+a.database+';')
def setup(target):
 target.query((fixtures/'fixtures/company-publication-base.sql').read_text(encoding='utf-8'))
 for n in ['readability.sql','reputation.sql','dto.sql','sources-gate.sql']:
  target.query((root/n).read_text(encoding='utf-8'))
 for n in ['company-publication-canonical-fixture.sql','fixtures/canonical-get_public_reviews_v1.sql','fixtures/canonical-get_public_official_qna_v1.sql']:
  target.query((fixtures/n).read_text(encoding='utf-8'))
 target.query("INSERT INTO public.company_profile_public_access(company_id,state) SELECT id,'active' FROM companies;")
 for n in ['content-dto.sql','publisher-candidate.sql','completeness.sql','complete-final.sql','owner-api.sql','artifact-reader.sql']:
  target.query((root/n).read_text(encoding='utf-8'))
setup(db)
C='00000000-0000-0000-0000-000000000001'; U='00000000-0000-0000-0000-000000000011'
db.query("UPDATE public.company_media SET status='draft'; UPDATE public.companies SET status='active',profile_status='ready' WHERE id='"+C+"'; UPDATE public.company_profile_public_access SET state='active' WHERE company_id='"+C+"';")
S=str(uuid.uuid4());R=str(uuid.uuid4());H=str(uuid.uuid4())
db.query("INSERT INTO public.review_sources(id,company_id,name,source_type,profile_url,collection_method,status) VALUES('"+S+"','"+C+"','Native','first_party_reviews','https://native.invalid','manual','published'); INSERT INTO public.reviews(id,company_id,source_id,source_url,collected_at,rating,rating_scale,content_hash,status,body,author_display_name) VALUES('"+R+"','"+C+"','"+S+"','https://native.invalid',now(),4,5,'native1','published','Native published body','Synthetic author'),('"+H+"','"+C+"','"+S+"','https://native.invalid',now(),5,5,'native2','draft','SECRET DRAFT','Hidden');")
q,qr,sr=[str(uuid.uuid4()) for _ in range(3)]
db.query("INSERT INTO private.questions_v1 VALUES('"+q+"','"+C+"',NULL,'"+qr+"','answered',now(),'Category','Program',now(),now()); INSERT INTO private.question_revisions_v1 VALUES('"+qr+"','"+C+"','Published question','ru',NULL); INSERT INTO private.official_statements_v2 VALUES('"+C+"','"+q+"',NULL,'"+sr+"'); INSERT INTO private.statement_revisions_v2 VALUES('"+sr+"','"+C+"','Published answer','published',now(),now());")
def snapshot(): return json.loads(db.query("SELECT private.get_company_complete_candidate_v1('alpha');"))
d=snapshot(); assert d['native_rating']=={'rating':4.00,'rating_scale':5,'review_count':1};assert len(d['reviews'])==1 and len(d['questions_answers'])==1
assert 'SECRET DRAFT' not in json.dumps(d); print('PASS canonical reviews/native rating/Q&A and draft isolation')
assert db.query("SELECT has_function_privilege('anon','public.get_my_company_publication_status(uuid)','EXECUTE')")=="f"
assert db.query("SELECT has_function_privilege('authenticated','public.request_my_company_publication(uuid,uuid)','EXECUTE')")=="t"
def enqueue(uid=U,key=None):
 return db.query("SELECT set_config('test.uid','"+uid+"',false); SELECT private.enqueue_company_publish_candidate('"+C+"','"+str(key or uuid.uuid4())+"');").splitlines()[-1]
def denied(fn):
 try: fn()
 except (ValueError,subprocess.CalledProcessError): return
 raise AssertionError('expected denial')
denied(lambda:enqueue('00000000-0000-0000-0000-000000000099')); print('PASS foreign enqueue rejected')
assert db.query("SELECT set_config('test.uid','"+U+"',false); SET ROLE authenticated; SELECT public.get_my_company_publication_status('"+C+"')->>'status'; RESET ROLE;").splitlines()[-1]=='unknown'
denied(lambda:db.query("SET ROLE anon; SELECT public.get_my_company_publication_status('"+C+"');"))
denied(lambda:db.query("SELECT set_config('test.uid','00000000-0000-0000-0000-000000000099',false); SET ROLE authenticated; SELECT public.get_my_company_publication_status('"+C+"');"))
print('PASS owner status API, anonymous and foreign denial under actual database roles')
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: ids=list(pool.map(lambda _:enqueue(),range(8)))
assert len(set(ids))==1;print('PASS 8 concurrent requests coalesced, durable idempotency keys')
with tempfile.TemporaryDirectory() as temp:
 result=w.run_one(db,pathlib.Path(temp)/str(uuid.uuid4()),gen/'render-profile.py'); assert result
 artifact=pathlib.Path(result['directory']);h=(artifact/'index.html').read_text(encoding='utf-8');assert 'Native published body' in h and 'Published question' in h and 'SECRET DRAFT' not in h
 assert db.query("SELECT state FROM private.company_publish_attempt_candidate WHERE id='"+ids[0]+"';")=='published'
 assert w.manifest(artifact)==result['manifest']; assert w.resolve_local(db,artifact.parent,'alpha')==artifact;print('PASS actual SQL -> original renderer -> five file readback -> proof -> published')
 enqueue();denied(lambda:w.run_one(db,pathlib.Path(temp)/str(uuid.uuid4()),gen/'render-profile.py',before_register=lambda dest,job:(dest/'profile.json').write_text('{}')))
 assert db.query("SELECT count(*) FROM private.company_publish_attempt_candidate WHERE state='building';")=='0';print('PASS tampered artifact refused, failed state')
 enqueue();denied(lambda:w.run_one(db,pathlib.Path(temp)/str(uuid.uuid4()),gen/'render-profile.py',before_register=lambda dest,job:db.query("UPDATE public.company_memberships SET verification_status='revoked' WHERE company_id='"+C+"';")))
 db.query("UPDATE public.company_memberships SET verification_status='verified' WHERE company_id='"+C+"';");print('PASS revoked requester cannot finalize')
 enqueue();denied(lambda:w.run_one(db,pathlib.Path(temp)/str(uuid.uuid4()),gen/'render-profile.py',before_register=lambda dest,job:db.query("UPDATE public.companies SET description='Changed after request' WHERE id='"+C+"';")));print('PASS stale snapshot cannot finalize')
 enqueue();denied(lambda:w.run_one(db,pathlib.Path(temp)/str(uuid.uuid4()),gen/'render-profile.py',before_register=lambda dest,job:db.query("UPDATE private.company_publish_attempt_candidate SET lease_until=now()-interval '1 second' WHERE id='"+job['id']+"';")))
 assert db.query('SELECT private.expire_publish_candidates();')=='1';print('PASS expired worker cannot finalize; expiry releases active slot')
 enqueue();denied(lambda:w.run_one(db,pathlib.Path(temp)/str(uuid.uuid4()),gen/'render-profile.py',before_register=lambda dest,job:db.query("UPDATE public.company_profile_public_access SET state='suspended' WHERE company_id='"+C+"';")))
 print('PASS suspended company cannot finalize')
 db.query("UPDATE public.company_profile_public_access SET state='active' WHERE company_id='"+C+"';")
 from PIL import Image,PngImagePlugin
 import io
 image=io.BytesIO();info=PngImagePlugin.PngInfo();info.add_text('secret','PRIVATE');Image.new('RGB',(12,12)).save(image,format='PNG',pnginfo=info)
 ms=importlib.util.spec_from_file_location('media',gen/'company-publication-media.py');media=importlib.util.module_from_spec(ms);ms.loader.exec_module(media)
 db.query("INSERT INTO public.company_media(id,company_id,media_type,storage_object_name,sort_order,status) VALUES('"+str(uuid.uuid4())+"','"+C+"','cover','"+C+"/cover/synthetic.png',0,'published');")
 enqueue(); result=w.run_one(db,pathlib.Path(temp)/str(uuid.uuid4()),gen/'render-profile.py',media_exporter=lambda d,o:media.export_media(d,o,fetch=lambda obj:image.getvalue()))
 bundle=pathlib.Path(result['directory']); assert 'media/00-image.png' in result['manifest']
 payload=json.loads((bundle/'profile.json').read_text(encoding='utf-8')); assert all('object_name' not in m for m in payload['media'])
 assert 'secret' not in Image.open(bundle/'media/00-image.png').info
 assert w.resolve_local(db,bundle.parent,'alpha')==bundle
 ps=importlib.util.spec_from_file_location('preview',gen/'company-publication-preview.py');preview=importlib.util.module_from_spec(ps);ps.loader.exec_module(preview)
 import http.server,threading,urllib.request,urllib.error
 server=http.server.ThreadingHTTPServer(('127.0.0.1',0),preview.handler(db,bundle.parent,w));thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
 url='http://127.0.0.1:'+str(server.server_port)+'/company/alpha/'
 with urllib.request.urlopen(url) as response:
  assert response.status==200 and response.headers['Cache-Control']=='no-store'; assert b'Native published body' in response.read()
 with urllib.request.urlopen(url+'media/00-image.png') as response: assert response.read().startswith(b'\x89PNG')
 print('PASS actual loopback HTTP public HTML/photo routes, no-store and image bytes')
 db.query("INSERT INTO private.review_revisions_v1(company_id,review_id,version,erased_at,redaction_status) VALUES('"+C+"','"+R+"',1,now(),'erased');")
 assert w.resolve_local(db,bundle.parent,'alpha') is None
 db.query("DELETE FROM private.review_revisions_v1 WHERE company_id='"+C+"' AND review_id='"+R+"';")
 assert w.resolve_local(db,bundle.parent,'alpha')==bundle
 print('PASS erased review invalidates previously built public artifact')
 db.query("UPDATE public.company_profile_public_access SET state='suspended' WHERE company_id='"+C+"';")
 assert w.resolve_local(db,bundle.parent,'alpha') is None
 try: urllib.request.urlopen(url)
 except urllib.error.HTTPError as error: assert error.code==404
 else: raise AssertionError('suspended company served')
 db.query("UPDATE public.company_profile_public_access SET state='active' WHERE company_id='"+C+"';")
 (bundle/'profile.json').write_text('{}'); denied(lambda:w.resolve_local(db,bundle.parent,'alpha'))
 try: urllib.request.urlopen(url)
 except urllib.error.HTTPError as error: assert error.code==503
 else: raise AssertionError('tampered artifact served')
 server.shutdown();server.server_close();thread.join()
 print('PASS HTTP suspended404, tampered503, closed server')
 print('PASS complete pipeline WITH decoded sanitized photo, manifest/readback and no private path')
denied(lambda:db.query((root/'publisher-rollback.sql').read_text(encoding='utf-8')));print('PASS nonempty rollback refuses and retains publication history')
assert db.query("SELECT count(*) FROM private.company_publish_attempt_candidate;")!='0'
print('ALL INTEGRATION GROUPS PASS; disposable database retained for inspection')

empty=a.database+'_empty'
admin.query('CREATE DATABASE '+empty+';')
e=w.Database(a.psql,55487,empty)
setup(e)
e.query((root/'publisher-rollback.sql').read_text(encoding='utf-8'))
assert e.query("SELECT to_regclass('private.company_publish_attempt_candidate') IS NULL AND to_regprocedure('private.guard_publish_artifact_candidate()') IS NULL;")=='t'
assert e.query('SELECT count(*) FROM companies;')=='2'
print('PASS empty final package rollback; original companies retained')
