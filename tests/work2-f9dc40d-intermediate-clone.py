"""Restore a private logical snapshot into a NEW loopback PG17 database, never hosted."""
import argparse,hashlib,json,os,pathlib,subprocess
p=argparse.ArgumentParser();p.add_argument('--package',required=True);p.add_argument('--data',required=True);p.add_argument('--psql',required=True);p.add_argument('--database',required=True);p.add_argument('--port',type=int,default=55487);a=p.parse_args()
assert a.database.startswith('staging_clone_') and a.database.replace('_','').isalnum()
root=pathlib.Path(a.package);s=json.loads((root/'staging-catalog.json').read_text(encoding='utf-8'));aux=json.loads((root/'clone-auxiliary-catalog.json').read_text(encoding='utf-8'));data=json.loads(pathlib.Path(a.data).read_text(encoding='utf-8'))
q=lambda x:'"'+x.replace('"','""')+'"';tn=lambda t:q(t['schema'])+'.'+q(t['name'])
def run(sql,database=None):
 r=subprocess.run([a.psql,'-h','127.0.0.1','-p',str(a.port),'-U','postgres','-d',database or a.database,'-X','-qAt','-v','ON_ERROR_STOP=1'],input=sql,encoding='utf-8',errors='replace',env=dict(os.environ,PGCLIENTENCODING='UTF8'),capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr)
 return r.stdout.strip()
roles={'anon','authenticated','service_role','specialist_operator','supabase_admin','supabase_auth_admin','supabase_storage_admin','dashboard_user'}
roles|={acl['grantee'] for t in s['tables']+aux['tables'] for acl in t['acl'] or [] if acl['grantee']!='PUBLIC'}
for role in roles:run("DO $role$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='"+role+"') THEN CREATE ROLE "+q(role)+" NOLOGIN; END IF; END $role$;",'postgres')
run('ALTER ROLE service_role BYPASSRLS; ALTER ROLE specialist_operator NOINHERIT NOBYPASSRLS;','postgres')
run('CREATE DATABASE '+q(a.database)+';','postgres')
lines=['SET check_function_bodies=off;','CREATE SCHEMA auth;CREATE SCHEMA storage;CREATE SCHEMA media_internal;CREATE SCHEMA extensions;','CREATE EXTENSION pgcrypto WITH SCHEMA extensions;','SET search_path=pg_catalog,public,extensions;']
for schema in ['auth','storage','media_internal','extensions']:lines.append('GRANT USAGE ON SCHEMA '+schema+' TO anon,authenticated,service_role,specialist_operator;')
for t in aux['enums']:
 if t['schema']=='storage':lines.append('CREATE TYPE '+q(t['schema'])+'.'+q(t['name'])+' AS ENUM('+','.join("'"+x+"'" for x in t['labels'])+');')
for f in aux['metadata']['helpers']:lines.append(f['definition'].rstrip()+';')
identity_sequences={t['schema']+'.'+t['name']+'_'+col['name']+'_seq' for t in s['tables']+aux['tables'] for col in t['columns'] if col['identity']}
for seq in aux['metadata']['sequences'] or []:
 if seq['schemaname']+'.'+seq['sequencename'] not in identity_sequences:lines.append('CREATE SEQUENCE '+q(seq['schemaname'])+'.'+q(seq['sequencename'])+' AS bigint;')
tables=aux['tables']+s['tables']
for t in tables:
 cols=[]
 for col in t['columns']:
  v=q(col['name'])+' '+col['type']
  if col['identity']:v+=' GENERATED '+('ALWAYS' if col['identity']=='a' else 'BY DEFAULT')+' AS IDENTITY'
  elif col['generated']:v+=' GENERATED ALWAYS AS ('+col['default']+') STORED'
  elif col['default'] is not None:v+=' DEFAULT '+col['default']
  if col['not_null']:v+=' NOT NULL'
  cols.append(v)
 lines.append('CREATE TABLE '+tn(t)+'('+','.join(cols)+');')
for f in s['functions']:lines.append(f['definition'].rstrip()+';')
for typ in ['p','u','c','x']:
 for t in tables:
  for con in t['constraints'] or []:
   if con['type']==typ:lines.append('ALTER TABLE '+tn(t)+' ADD CONSTRAINT '+q(con['name'])+' '+con['definition']+';')
for t in tables:
 rows=data[t['schema']+'.'+t['name']] or []
 if not rows:continue
 cols=[c['name'] for c in t['columns'] if not c['generated'] and any(c['name'] in row for row in rows)]
 encoded=json.dumps(rows,ensure_ascii=False).encode().hex()
 lines.append('INSERT INTO '+tn(t)+'('+','.join(map(q,cols))+') OVERRIDING SYSTEM VALUE SELECT '+','.join('x.'+q(c) for c in cols)+' FROM jsonb_populate_recordset(NULL::'+tn(t)+",convert_from(decode('"+encoded+"','hex'),'UTF8')::jsonb) x;")
for t in tables:
 for index in t['indexes'] or []:lines.append(index+';')
for t in tables:
 for con in t['constraints'] or []:
  if con['type']=='f':lines.append('ALTER TABLE '+tn(t)+' ADD CONSTRAINT '+q(con['name'])+' '+con['definition']+';')
 lines+=['ALTER TABLE '+tn(t)+(' ENABLE' if t['rls'] else ' DISABLE')+' ROW LEVEL SECURITY;','ALTER TABLE '+tn(t)+(' FORCE' if t['force_rls'] else ' NO FORCE')+' ROW LEVEL SECURITY;','REVOKE ALL ON '+tn(t)+' FROM PUBLIC,anon,authenticated,service_role;']
 for acl in t['acl'] or []:
  if acl['grantee']=='postgres':continue
  lines.append('GRANT '+acl['privilege']+' ON '+tn(t)+' TO '+('PUBLIC' if acl['grantee']=='PUBLIC' else q(acl['grantee']))+';')
for f in s['functions']:
 sig=q(f['schema'])+'.'+q(f['name'])+'('+f['args']+')'
 lines.append('REVOKE ALL ON FUNCTION '+sig+' FROM PUBLIC,anon,authenticated,service_role,specialist_operator;')
 for acl in f['acl'] or []:
  if acl['grantee']!='postgres':lines.append('GRANT EXECUTE ON FUNCTION '+sig+' TO '+('PUBLIC' if acl['grantee']=='PUBLIC' else q(acl['grantee']))+';')
for tr in s['triggers'] or []:lines.append(tr['definition']+';')
for pol in (s['policies'] or [])+(aux['policies'] or []):
 v='CREATE POLICY '+q(pol['policyname'])+' ON '+q(pol['schemaname'])+'.'+q(pol['tablename'])+' AS '+pol['permissive']+' FOR '+pol['cmd']+' TO '+','.join('PUBLIC' if x=='public' else q(x) for x in pol['roles'])
 if pol['qual']:v+=' USING('+pol['qual']+')'
 if pol['with_check']:v+=' WITH CHECK('+pol['with_check']+')'
 lines.append(v+';')
for seq in aux['metadata']['sequences'] or []:
 if seq['last_value'] is not None:lines.append("SELECT setval('"+seq['schemaname']+'.'+seq['sequencename']+"',"+str(seq['last_value'])+',true);')
run('\n'.join(lines))
print('RESTORED actual staging table data/columns/constraints/functions/RLS/grants/policies/triggers; Auth credentials excluded; no hosted changes')
def baseline():
 out={}
 for t in tables:
  name=t['schema']+'.'+t['name'];out[name]=run("SELECT encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text COLLATE \"C\"),'[]'::jsonb)::text,'UTF8')),'hex') FROM "+tn(t)+" x"+(" WHERE id<>'company-publication-artifacts-staging'" if name=='storage.buckets' else '')+';')
 out['functions']=run("SELECT encode(sha256(convert_to(string_agg(pg_get_functiondef(p.oid),E'\\n' ORDER BY n.nspname,p.proname,oidvectortypes(p.proargtypes)),'UTF8')),'hex') FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN('public','media_internal') AND p.oid IN ("+','.join("'"+f['schema']+'.'+f['name']+'('+f['args']+")'::regprocedure::oid" for f in s['functions'])+');')
 return out
run((root/'00-preflight-readonly.sql').read_text(encoding='utf-8'))
b=baseline();run((root/'10-canonical-missing-modules.sql').read_text(encoding='utf-8'));after=baseline();assert b==after,[k for k in b if b[k]!=after[k]]
print('PASS canonical missing-module delta on actual staged clone: ALL existing rows and function bodies unchanged')
run((root/'90-rollback.sql').read_text(encoding='utf-8'))
assert b==baseline(), 'baseline changed after partial-stage rollback'
run((root/'00-preflight-readonly.sql').read_text(encoding='utf-8'))
print('PASS rollback after committed stage 10 only')
run((root/'10-canonical-missing-modules.sql').read_text(encoding='utf-8'))
run((root/'20-publisher-integration.sql').read_text(encoding='utf-8'))
assert b==baseline(), 'baseline changed after intermediate10+20'
run((root/'90-rollback.sql').read_text(encoding='utf-8'))
assert b==baseline(), 'baseline changed after intermediate10+20 rollback'
run((root/'00-preflight-readonly.sql').read_text(encoding='utf-8'))
print('PASS WORK2 independent intermediate committed10+20 rollback, baseline and preflight restored')
run((root/'10-canonical-missing-modules.sql').read_text(encoding='utf-8'))
for step in ['20-publisher-integration.sql','30-private-artifact-delivery.sql']:
 run((root/step).read_text(encoding='utf-8'))
assert b==baseline(), 'baseline changed after full apply'
run((pathlib.Path(__file__).parent/'staging-company-membership.sql').read_text())
assert b==baseline(), 'membership test did not rollback'
print('PASS canonical membership RPC isolated contract')
# Verify rollback fails closed when new module data would be lost.
run("INSERT INTO private.compatibility_flags_v1(key,enabled) VALUES('rollback_preservation_probe',false);")
try:
 run((root/'90-rollback.sql').read_text(encoding='utf-8'))
except RuntimeError as error:
 assert 'rollback refuses nonempty' in str(error), str(error)
else:raise AssertionError('rollback discarded new data')
assert run("SELECT count(*) FROM private.compatibility_flags_v1 WHERE key='rollback_preservation_probe'")== '1'
run("DELETE FROM private.compatibility_flags_v1 WHERE key='rollback_preservation_probe';")
print('PASS rollback refuses nonempty module, transaction preserved probe')
run((root/'90-rollback.sql').read_text(encoding='utf-8'))
assert b==baseline(), 'baseline data/function drift after rollback'
run((root/'00-preflight-readonly.sql').read_text(encoding='utf-8'))
print('PASS full 10/20/30 apply + guarded rollback: baseline catalog fingerprint, all rows, Storage metadata and function bodies restored')
pathlib.Path(a.data).with_name(a.database+'-baseline-hashes.json').write_text(json.dumps(b,indent=2))
print(json.dumps({'database':a.database,'preserved_tables':len(tables),'storage_objects':len(data['storage.objects']),'specialists':len(data['public.specialist_profiles']),'company_invitations':len(data['public.company_access_invitations'])}))
