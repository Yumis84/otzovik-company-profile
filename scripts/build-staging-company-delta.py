"""Build a review-only additive delta from captured canonical/staging catalogs."""
import hashlib,json,pathlib,re
root=pathlib.Path(__file__).resolve().parents[1]/'sql/candidates/staging-company-integration'
c=json.loads((root/'canonical-catalog.json').read_text());s=json.loads((root/'staging-catalog.json').read_text())
q=lambda x:'"'+x.replace('"','""')+'"'
tn=lambda t:q(t['schema'])+'.'+q(t['name'])
existing={(t['schema'],t['name']) for t in s['tables']}
existing_f={(f['schema'],f['name'],f['args']) for f in s['functions']}
seed={'add_my_company_review_source','archive_my_company_review_source','get_my_company_review_sources','record_review_source_rating_snapshot','enqueue_review_source_sync','claim_next_review_source_sync','finish_review_source_sync','recover_stale_review_source_sync_jobs','get_my_company_client_content','get_my_company_knowledge','upsert_my_company_knowledge','publish_my_company_knowledge','verify_my_company_knowledge','upsert_my_company_question_answer','respond_to_my_company_review','get_public_company_content_v1','get_public_company_profile_v2','get_public_company_profile_v3_candidate','get_public_company_access_state','get_my_company_publication_status','get_company_profile_for_worker','submit_own_review_internal','moderate_own_review','moderate_own_review_internal','publish_own_review_internal','remove_own_review_internal','record_own_review_ai_assessment_internal','get_own_review_moderation_queue','check_own_review_rate_limit_internal'}
trigger_names=set()
for t in c['triggers'] or []:
 if 'profile_publish' not in t['name']:
  m=re.search(r'EXECUTE FUNCTION (?:(\w+)\.)?(\w+)\(',t['definition'])
  if m:trigger_names.add((m.group(1) or 'public',m.group(2)))
functions=[f for f in c['functions'] if (f['schema']=='public' and f['name'] in seed) or (f['schema'],f['name']) in trigger_names]
while True:
 names={(f['schema'],f['name']) for f in functions}
 refs=set(re.findall(r'\b(private|public)\.([a-z][a-z0-9_]*)\s*\(', '\n'.join(f['definition'] for f in functions)))
 add=[f for f in c['functions'] if (f['schema'],f['name']) in refs-names and (f['schema'],f['name'],f['args']) not in existing_f]
 if not add:break
 functions+=add
functions=[f for f in functions if (f['schema'],f['name'],f['args']) not in existing_f]
assert not any('net.http_' in f['definition'] or 'rzhlcszqtuhkhfibygnk.supabase.co' in f['definition'] for f in functions),'production emitter must be excluded'
tables=[t for t in c['tables'] if (t['schema'],t['name']) not in existing]
assert all(not col['generated'] for t in tables for col in t['columns'])
lines=['-- REVIEW ONLY: existing staging salmcnhexlftrgtiryyo; never auto-apply.','BEGIN;',"SET LOCAL lock_timeout='3s'; SET LOCAL statement_timeout='60s';",'SET LOCAL search_path=pg_catalog,public,private,extensions;',"DO $pre$ BEGIN IF current_setting('server_version_num')::int < 170000 THEN RAISE EXCEPTION 'PG17 required'; END IF;", "IF to_regclass('public.specialist_profiles') IS NULL OR to_regclass('public.company_access_invitations') IS NULL THEN RAISE EXCEPTION 'expected existing staging modules absent'; END IF;"]
for t in tables:lines.append("IF to_regclass('"+t['schema']+'.'+t['name']+"') IS NOT NULL THEN RAISE EXCEPTION 'new module object already exists: "+t['name']+"'; END IF;")
lines+=['END $pre$;','CREATE SCHEMA IF NOT EXISTS private;','REVOKE ALL ON SCHEMA private FROM PUBLIC,anon,authenticated;']
for t in tables:
 cols=[]
 for col in t['columns']:
  v=q(col['name'])+' '+col['type']
  if col['identity']:v+=' GENERATED '+('ALWAYS' if col['identity']=='a' else 'BY DEFAULT')+' AS IDENTITY'
  if col['default'] is not None:v+=' DEFAULT '+col['default']
  if col['not_null']:v+=' NOT NULL'
  cols.append(v)
 lines.append('CREATE TABLE '+tn(t)+' (\n '+',\n '.join(cols)+'\n);')
lines += ['CREATE UNIQUE INDEX company_locations_company_id_id_uq ON public.company_locations USING btree(company_id,id);','CREATE UNIQUE INDEX company_services_company_id_id_uq ON public.company_services USING btree(company_id,id);']
for typ in ['p','u','c','x']:
 for t in tables:
  for con in t['constraints'] or []:
   if con['type']==typ:lines.append('ALTER TABLE '+tn(t)+' ADD CONSTRAINT '+q(con['name'])+' '+con['definition']+';')
for t in tables:
 for index in t['indexes'] or []:lines.append(index+';')
for t in tables:
 for con in t['constraints'] or []:
  if con['type']=='f':lines.append('ALTER TABLE '+tn(t)+' ADD CONSTRAINT '+q(con['name'])+' '+con['definition']+';')
for t in tables:
 lines+=['ALTER TABLE '+tn(t)+(' ENABLE' if t['rls'] else ' DISABLE')+' ROW LEVEL SECURITY;','ALTER TABLE '+tn(t)+(' FORCE' if t['force_rls'] else ' NO FORCE')+' ROW LEVEL SECURITY;','REVOKE ALL ON '+tn(t)+' FROM PUBLIC,anon,authenticated,service_role;']
 for acl in t['acl'] or []:
  if acl['grantee']=='postgres':continue
  lines.append('GRANT '+acl['privilege']+' ON '+tn(t)+' TO '+('PUBLIC' if acl['grantee']=='PUBLIC' else q(acl['grantee']))+';')
# New function bodies may be mutually dependent. Canonical SQL bodies are validated by runtime tests.
lines.append('SET LOCAL check_function_bodies=off;')
for f in functions:
 lines.append(f['definition'].replace('CREATE OR REPLACE FUNCTION','CREATE FUNCTION',1).rstrip()+';')
 sig=q(f['schema'])+'.'+q(f['name'])+'('+f['args']+')'
 lines.append('REVOKE ALL ON FUNCTION '+sig+' FROM PUBLIC,anon,authenticated,service_role;')
 for acl in f['acl'] or []:
  if acl['grantee']=='postgres':continue
  lines.append('GRANT EXECUTE ON FUNCTION '+sig+' TO '+('PUBLIC' if acl['grantee']=='PUBLIC' else q(acl['grantee']))+';')
for p in c['policies'] or []:
 if (p['schemaname'],p['tablename']) not in {(t['schema'],t['name']) for t in tables}:continue
 v='CREATE POLICY '+q(p['policyname'])+' ON '+q(p['schemaname'])+'.'+q(p['tablename'])+' AS '+p['permissive']+' FOR '+p['cmd']+' TO '+','.join('PUBLIC' if x=='public' else q(x) for x in p['roles'])
 if p['qual']:v+=' USING ('+p['qual']+')'
 if p['with_check']:v+=' WITH CHECK ('+p['with_check']+')'
 lines.append(v+';')
funcnames={(f['schema'],f['name']) for f in functions}|{(f['schema'],f['name']) for f in s['functions']}
skipped=[]
for t in c['triggers'] or []:
 if 'profile_publish' in t['name']:skipped.append(t);continue
 fun=re.search(r'EXECUTE FUNCTION (?:(\w+)\.)?(\w+)\(',t['definition'])
 if fun and (fun.group(1) or 'public',fun.group(2)) in funcnames:
  lines.append(t['definition']+';')
 else:skipped.append(t)
lines+=['COMMIT;','']
(root/'10-canonical-missing-modules.sql').write_text('\n'.join(lines))
manifest={'canonical_project':'rzhlcszqtuhkhfibygnk','staging_project':'salmcnhexlftrgtiryyo','new_tables':[t['schema']+'.'+t['name'] for t in tables],'new_functions':[f['schema']+'.'+f['name']+'('+f['args']+')' for f in functions],'deferred_triggers':[t['name'] for t in skipped],'existing_objects_modified':['public.company_locations: add canonical composite unique index','public.company_services: add canonical composite unique index'],'sql_sha256':hashlib.sha256((root/'10-canonical-missing-modules.sql').read_bytes()).hexdigest()}
(root/'delta-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:v if not isinstance(v,list) else len(v) for k,v in manifest.items()}))
