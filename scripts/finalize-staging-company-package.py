"""Generate bounded rollback and complete checksums; does not connect to any DB."""
import json,re,pathlib,hashlib
base=pathlib.Path(__file__).resolve().parents[1];root=base/'sql/candidates/staging-company-integration'
m=json.loads((root/'delta-manifest.json').read_text());s=json.loads((root/'staging-catalog.json').read_text())
texts=[(root/n).read_text() for n in ['10-canonical-missing-modules.sql','20-publisher-integration.sql','30-private-artifact-delivery.sql']]
names=sorted(set(re.findall(r'CREATE (?:OR REPLACE )?FUNCTION\s+(public\.[a-z_0-9]+)', '\n'.join(texts),re.I)))
assert not ({f['schema']+'.'+f['name'] for f in s['functions']}&set(names)), 'rollback must not drop baseline functions'
tables=list(dict.fromkeys(m['new_tables']+re.findall(r'CREATE TABLE\s+(private\.[a-z_0-9]+)',texts[1],re.I)))
# All new table data must be exported/removed through approved normal operations before rollback.
lines=['-- REVIEW ONLY: reverses 10/20/30; aborts on new data; no CASCADE.','BEGIN;',"SET LOCAL lock_timeout='3s'; SET LOCAL statement_timeout='60s';",'SET LOCAL search_path=pg_catalog,public,private,extensions;', 'DO $guard$ DECLARE t text; occupied boolean; BEGIN',"IF NOT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='private') THEN RAISE EXCEPTION 'not an installed package'; END IF;"]
for t in tables:lines.append(f"IF to_regclass('{t}') IS NOT NULL THEN EXECUTE 'SELECT EXISTS(SELECT 1 FROM {t})' INTO occupied; IF occupied THEN RAISE EXCEPTION 'rollback refuses nonempty {t}: export/reconcile first'; END IF; END IF;")
lines += ["IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='company-publication-artifacts-staging') THEN RAISE EXCEPTION 'rollback refuses stored artifacts; approved Storage API cleanup required'; END IF;",'END $guard$;']
# Drop new triggers before their functions. No baseline trigger was replaced.
for text in texts:
 for tr,table in re.findall(r'CREATE TRIGGER\s+(\w+)\s+.*?\sON\s+([\w.]+)\s+.*?EXECUTE FUNCTION',text,re.I):
  if '.' not in table:table='public.'+table
  lines.append(f"DO $tr$ BEGIN IF to_regclass('{table}') IS NOT NULL THEN EXECUTE 'DROP TRIGGER IF EXISTS {tr} ON {table}'; END IF; END $tr$;")
c=json.loads((root/'canonical-catalog.json').read_text())
for pol in c['policies'] or []:
 if pol['schemaname']+'.'+pol['tablename'] in tables:
  table=pol['schemaname']+'.'+pol['tablename']
  lines.append("DO $pol$ BEGIN IF to_regclass('"+table+"') IS NOT NULL THEN EXECUTE 'DROP POLICY IF EXISTS \""+pol['policyname']+"\" ON "+table+"'; END IF; END $pol$;")
lines.append('ALTER TABLE public.company_profile_publications DROP COLUMN IF EXISTS attempt_id;')
private_names=','.join("'"+n+"'" for n in sorted(set(re.findall(r'CREATE (?:OR REPLACE )?FUNCTION\s+private\.([a-z_0-9]+)', '\n'.join(texts),re.I))))
public_names=','.join("'"+n.split('.')[1]+"'" for n in names)
lines += ['DO $functions$ DECLARE f record; BEGIN',f"FOR f IN SELECT p.oid::regprocedure::text signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE (n.nspname='private' AND p.proname IN({private_names})) OR (n.nspname='public' AND p.proname IN({public_names})) LOOP", "EXECUTE 'DROP FUNCTION '||f.signature||' RESTRICT';",'END LOOP; END $functions$;','DROP TABLE IF EXISTS '+','.join(tables)+' RESTRICT;', 'DROP INDEX public.company_locations_company_id_id_uq;', 'DROP INDEX public.company_services_company_id_id_uq;', 'DROP SCHEMA private RESTRICT;',"DELETE FROM storage.buckets WHERE id='company-publication-artifacts-staging';",'COMMIT;','']
(root/'90-rollback.sql').write_text('\n'.join(lines),encoding='utf-8',newline='\n')
m.update({'apply_order':['00-preflight-readonly.sql','10-canonical-missing-modules.sql','20-publisher-integration.sql','30-private-artifact-delivery.sql'],'rollback':'90-rollback.sql','rollback_policy':'Refuse nonempty new tables or artifacts; no CASCADE; export/reconcile new content first. Baseline data never restored over live rows.','fingerprint':{'algorithm':'md5 over canonical JSONB catalog structure, drift detection only; file integrity SHA256 separately','expected':'a3176df25a276840b49bb395a1cefe2b','coverage':'captured public tables, constraints/indexes/owners/ACL/RLS, captured function definitions/owners/ACL/config, triggers, policies; private schema must be absent','limits':'not whole database: auth/storage data and extension internals excluded'},'new_public_function_names':names,'new_tables':tables,'existing_objects_modified':['public.company_locations: additive composite unique index','public.company_services: additive composite unique index'],'staging_apply_authorized':False})
paths=sorted(p for p in root.iterdir() if p.is_file() and p.name not in ['delta-manifest.json','SHA256SUMS'])
paths += [base/n for n in ['sql/candidates/company-publication/publisher-candidate.sql','tests/publication-lease-recovery.py','scripts/build-staging-company-delta.py','scripts/build-staging-publisher-adapter.py','scripts/finalize-staging-company-package.py','tests/staging-company-clone.py','tests/staging-company-functional.sql','tests/staging-company-security.sql','tests/staging-company-delivery.sql','tests/staging-company-membership.sql','tests/staging-company-public-profile.mjs','server/staging-company-public-profile.js']]
m['files']={p.relative_to(base).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
(root/'delta-manifest.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8',newline='\n');paths.append(root/'delta-manifest.json')
(root/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(base).as_posix()+'\n' for p in paths),encoding='utf-8',newline='\n')
print('Generated bounded rollback and checksums',len(paths))
