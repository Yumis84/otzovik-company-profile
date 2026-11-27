"""Targeted real PG17 regression; isolated SQL role claims, never hosted JWT."""
import argparse,subprocess,json,uuid,concurrent.futures,hashlib
p=argparse.ArgumentParser();p.add_argument('--psql',required=True);p.add_argument('--port',type=int,required=True);p.add_argument('--database',required=True);a=p.parse_args()
assert 55400<=a.port<=55599 and a.database.startswith('staging_clone_') and a.database.replace('_','').isalnum()
cmd=[a.psql,'-h','127.0.0.1','-p',str(a.port),'-U','postgres','-d',a.database,'-X','-qAt','-v','ON_ERROR_STOP=1']
def sql(s):
 r=subprocess.run(cmd,input=s,encoding='utf-8',errors='replace',capture_output=True,timeout=12)
 if r.returncode:raise RuntimeError(r.stderr)
 return r.stdout.strip()
c='4616c65b-5ebb-4c13-b2ef-24e2bc40d623'
owner=sql("SELECT user_id FROM public.company_memberships WHERE company_id='"+c+"' AND role='owner' LIMIT 1;")
uuid.UUID(owner)
def request(k=None):
 k=k or str(uuid.uuid4())
 return sql("SET request.jwt.claim.sub='"+owner+"';SET ROLE authenticated;SELECT public.request_my_company_publication('"+c+"','"+k+"');")
def claim(run=None):
 run=run or str(uuid.uuid4())
 value=sql("SET ROLE service_role;SELECT public.company_publish_worker_claim('"+run+"');")
 return json.loads(value) if value else None
def worker_bool(name,attempt,run):
 return sql("SET ROLE service_role;SELECT public."+name+"('"+attempt+"','"+run+"');")
def state(attempt):return sql("SELECT state FROM private.company_publish_attempt_candidate WHERE id='"+attempt+"';")
sql("INSERT INTO public.company_profile_public_access(company_id,state) VALUES('"+c+"','active');INSERT INTO private.compatibility_flags_v1(key,enabled) VALUES('staging_company_profile_delivery_ready',true);")
key=str(uuid.uuid4());old=request(key)
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: claims=list(pool.map(lambda _:claim(),range(8)))
winners=[x for x in claims if x]
assert len(winners)==1 and winners[0]['id']==old
run=winners[0]['run_id'];assert worker_bool('company_publish_worker_heartbeat',old,run)=='t'
print('PASS eight concurrent service claims: one winner; live heartbeat retained')
sql("UPDATE private.company_publish_attempt_candidate SET lease_until=clock_timestamp()-interval '1 second' WHERE id='"+old+"';")
# Lock an expired row to model an in-flight worker/expiry transaction. Claim must skip rather than wait.
held=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8',errors='replace')
held.stdin.write("BEGIN;SELECT 1 FROM private.company_publish_attempt_candidate WHERE id='"+old+"' FOR UPDATE;\n\\echo HELD\n");held.stdin.flush()
while True:
 line=held.stdout.readline()
 if line.strip()=='HELD':break
 if line=='':raise RuntimeError('lock fixture failed')
try:
 assert sql("SET lock_timeout='500ms';SET ROLE service_role;SELECT public.company_publish_worker_claim('"+str(uuid.uuid4())+"');")==''
 assert state(old)=='building'
finally:
 held.stdin.write('ROLLBACK;\n');held.stdin.close();held.stdin=None
 out,err=held.communicate(timeout=5)
 assert held.returncode==0,err
print('PASS expiry skips locked candidate without blocking/deadlock')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: assert all(x is None for x in pool.map(lambda _:claim(),range(4)))
assert state(old)=='failed' and request(key)==old
assert worker_bool('company_publish_worker_heartbeat',old,run)=='f'
assert worker_bool('company_publish_worker_fail',old,run)=='f'
assert sql("SELECT private.transition_publish_candidate('"+old+"','"+run+"','published',repeat('0',64));")=='f'
manifest={x:'0'*64 for x in ['index.html','profile.css','profile.json','profile.md','llms.txt']}
encoded=json.dumps(manifest);digest=hashlib.sha256('\n'.join(k+':'+manifest[k] for k in sorted(manifest)).encode()).hexdigest()
try:sql("SET ROLE service_role;SELECT public.company_publish_worker_register('"+old+"','"+run+"','"+encoded+"'::jsonb,'"+digest+"');")
except RuntimeError as e:assert 'unknown worker attempt' in str(e)
else:raise AssertionError('expired register allowed')
try:sql("INSERT INTO private.company_publish_artifact_candidate VALUES('"+old+"','"+run+"','"+digest+"','"+encoded+"'::jsonb);")
except RuntimeError as e:assert 'invalid or incomplete candidate' in str(e)
else:raise AssertionError('expired proof allowed')
print('PASS claim auto-expires; original key durable; expired heartbeat/fail/finalize/register/proof fenced')
new=request();assert new!=old
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: claims=list(pool.map(lambda _:claim(),range(8)))
winners=[x for x in claims if x];assert len(winners)==1 and winners[0]['id']==new
newrun=winners[0]['run_id']
assert worker_bool('company_publish_worker_heartbeat',new,run)=='f'
assert worker_bool('company_publish_worker_fail',old,run)=='f'
assert state(new)=='building'
# A heartbeat that wins the lock and extends its lease is not expired by recovery.
assert worker_bool('company_publish_worker_heartbeat',new,newrun)=='t'
assert claim() is None and state(new)=='building'
sql("INSERT INTO private.company_publish_artifact_candidate VALUES('"+new+"','"+newrun+"','"+digest+"','"+encoded+"'::jsonb);")
assert sql("SELECT private.transition_publish_candidate('"+new+"','"+newrun+"','published','"+digest+"');")=='t'
assert claim() is None and state(new)=='published' and state(old)=='failed'
assert worker_bool('company_publish_worker_fail',old,run)=='f' and state(new)=='published'
print('PASS new UUID retry one winner; wrong-run fencing; heartbeat winner preserved; published attempt never expired')
print('ALL TARGETED LEASE RECOVERY GROUPS PASS (local SQL claims, not hosted JWT)')
