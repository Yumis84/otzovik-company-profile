"""Independent Work2 functional acceptance. Disposable local PG17 only; no hosted JWT claim."""
from pathlib import Path
import argparse,importlib.util,uuid,json,io,hashlib,http.server,threading,urllib.request,urllib.error,subprocess
from PIL import Image,PngImagePlugin
p=argparse.ArgumentParser();p.add_argument('--port',type=int,required=True);p.add_argument('--psql',required=True);p.add_argument('--generator-root',required=True);p.add_argument('--output',required=True);a=p.parse_args()
assert a.port==55489,'Only dedicated Work2 local cluster'
root=Path(__file__).resolve().parents[1];gen=Path(a.generator_root);output=Path(a.output);output.mkdir(parents=True,exist_ok=True)
def module(name,file):
 spec=importlib.util.spec_from_file_location(name,file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
w=module('work2worker',gen/'company-publication-worker.py');media=module('work2media',gen/'company-publication-media.py');preview=module('work2preview',gen/'company-publication-preview.py')
admin=w.Database(a.psql,a.port,'postgres');name='work2_republish_acceptance';admin.query('CREATE DATABASE '+name+';');db=w.Database(a.psql,a.port,name)
def apply(file):db.query(file.read_text(encoding='utf-8'))
apply(root/'tests/fixtures/company-publication-base.sql')
for n in ['readability.sql','reputation.sql','dto.sql','sources-gate.sql']:apply(root/'sql/candidates/company-publication'/n)
for n in ['company-publication-canonical-fixture.sql','fixtures/canonical-get_public_reviews_v1.sql','fixtures/canonical-get_public_official_qna_v1.sql']:apply(root/'tests'/n)
db.query("INSERT INTO public.company_profile_public_access(company_id,state) SELECT id,'active' FROM companies;")
for n in ['content-dto.sql','publisher-candidate.sql','completeness.sql','complete-final.sql','owner-api.sql','artifact-reader.sql']:apply(root/'sql/candidates/company-publication'/n)
C='00000000-0000-0000-0000-000000000001';U='00000000-0000-0000-0000-000000000011'
image=io.BytesIO();info=PngImagePlugin.PngInfo();info.add_text('private-test-metadata','not-for-public');Image.new('RGB',(48,32),'#175cd3').save(image,format='PNG',pnginfo=info);source=image.getvalue();sourcehash=hashlib.sha256(source).hexdigest()
db.query("INSERT INTO public.company_media(id,company_id,media_type,storage_object_name,sort_order,status) VALUES('"+str(uuid.uuid4())+"','"+C+"','cover','"+C+"/cover/source.png',0,'published');")
def owner(sql):return db.query("BEGIN; SELECT set_config('test.uid','"+U+"',true); SET LOCAL ROLE authenticated; "+sql+"; COMMIT;").splitlines()[-1]
def request(key=None):return owner("SELECT public.request_my_company_publication('"+C+"','"+str(key or uuid.uuid4())+"')")
def status():return json.loads(owner("SELECT public.get_my_company_publication_status('"+C+"')"))
def export(d,o):return media.export_media(d,o,fetch=lambda _:source)
def build(renderer=None,exporter=export):return w.run_one(db,output,renderer or gen/'render-profile.py',media_exporter=exporter)
def failure(fn):
 try:fn()
 except (ValueError,RuntimeError,subprocess.CalledProcessError):return
 raise AssertionError('Expected injected generation failure')
events=[]
def passed(label):events.append(label);print('PASS WORK2 '+label,flush=True)
key=uuid.uuid4();attempt=request(key);assert request(key)==attempt;assert status()['status']=='queued';passed('real authenticated DB owner request and durable UUID replay -> queued')
first=build();assert first and status()['status']=='published';old=Path(first['directory']);oldmanifest=w.manifest(old);oldphotos={n:h for n,h in oldmanifest.items() if n.startswith('media/')};assert oldphotos
assert request(key)==attempt;assert w.run_one(db,output,gen/'render-profile.py',media_exporter=export) is None;passed('queue -> actual image sanitize/renderer/proof -> published; replay does not rebuild')
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),preview.handler(db,output,w));thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start();url='http://127.0.0.1:'+str(server.server_port)+'/company/alpha/'
def read(route=''):
 with urllib.request.urlopen(url+route) as r:
  assert r.status==200 and r.headers.get('Cache-Control')=='no-store'
  return r.read()
try:
 assert b'Synthetic Alpha' in read();photo=next(iter(oldphotos));photobytes=read(photo);assert Image.open(io.BytesIO(photobytes)).size==(48,32);passed('actual loopback HTTP public HTML and sanitized photo readable')
 bad=output.parent/'work2-render-failure.py';bad.write_text('raise SystemExit(23)\n',encoding='utf-8')
 failedid=request();failure(lambda:build(bad));assert status()['status']=='failed';assert db.query("SELECT state FROM private.company_publish_attempt_candidate WHERE id='"+failedid+"'")=='failed'
 assert w.manifest(old)==oldmanifest and read(photo)==photobytes and w.resolve_local(db,output,'alpha')==old;passed('renderer failure marks failed and preserves readable prior version/photo bytes')
 assert request(uuid.UUID(db.query("SELECT request_key FROM private.company_publish_attempt_candidate WHERE id='"+failedid+"'")))==failedid
 retry=request();assert retry!=failedid and status()['status']=='queued';same=build();assert status()['status']=='published';assert w.manifest(old)==oldmanifest;assert read(photo)==photobytes;passed('new UUID retry after failure republishes; prior artifact and source photo unchanged')
 before=Path(same['directory']);beforemanifest=w.manifest(before)
 db.query("UPDATE public.companies SET description='Independent Work2 second public version' WHERE id='"+C+"';")
 assert status()['status']=='unknown'
 try:read()
 except urllib.error.HTTPError as e:assert e.code==404
 else:raise AssertionError('Stale previous snapshot was served')
 assert w.manifest(before)==beforemanifest;passed('changed draft invalidates old public snapshot without deleting old version files')
 request();second=build();assert second['revision']!=same['revision'];assert b'Independent Work2 second public version' in read();assert read(photo)==photobytes;assert w.manifest(before)==beforemanifest;assert w.manifest(old)==oldmanifest;passed('edited profile republished via queue; new version served and previous files/photos retained')
 current=Path(second['directory']);currentmanifest=w.manifest(current)
 def broken_media(d,o):raise RuntimeError('injected media transport failure')
 request();failure(lambda:build(exporter=broken_media));assert status()['status']=='failed'
 assert w.resolve_local(db,output,'alpha')==current and w.manifest(current)==currentmanifest and read(photo)==photobytes;passed('media transport failure preserves last valid public version and photos')
 assert hashlib.sha256(source).hexdigest()==sourcehash;assert db.query('SELECT count(*) FROM public.companies')=='2';passed('original two synthetic companies and source image bytes preserved')
 result={'backend_sha':'4e9a41e3ff1f6f5cd94f716630577fca80bf0d89','generator_sha':'3af1bdbe396d168e8b09a19396c5ca3e1b32d095','database':name,'port':a.port,'checks':events,'first_revision':first['revision'],'second_revision':second['revision'],'source_photo_sha256':sourcehash,'media_transport':'mocked read; actual image decode/reencode','auth':'actual PG authenticated role and fixture auth.uid, not hosted JWT','http':'actual loopback only'}
 (output.parent/'republish-result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
finally:
 server.shutdown();server.server_close();thread.join()
print('PASS WORK2 all additional republish/failure/version/photo preservation checks',flush=True)
