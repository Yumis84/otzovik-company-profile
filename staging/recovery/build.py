"""Assemble reviewed SQL bodies without opening a database connection."""
from pathlib import Path
import json,re,sys
here=Path(__file__).resolve().parent
root=here.parents[1]
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
base=json.loads((here/'baseline.json').read_text())
files=['release/60_GATEWAY_CANDIDATE','release/65_GATEWAY_REMEDIATION_CANDIDATE','release/66_SPECIALIST_OPERATOR_CANDIDATE','20261106_specialist_publication_foundation_CANDIDATE','20261106_specialist_slug_quarantine_CANDIDATE','20261112_specialist_revision_retention_CANDIDATE','20261112_specialist_publish_CANDIDATE','20261112_specialist_public_getter_CANDIDATE','20261112_specialist_public_owner_status_CANDIDATE','20261112_specialist_public_operator_CANDIDATE','20261112_specialist_erasure_barrier_CANDIDATE','20261116_specialist_post_audit_REVIEW_CANDIDATE','20261117_publication_timeout_acl_REVIEW_CANDIDATE','20261122_specialist_public_details_CANDIDATE']
def lit(s):return "'"+s.replace("'","''")+"'"
def check(condition,message):return 'IF NOT COALESCE(('+condition+'),false) THEN RAISE EXCEPTION '+lit(message)+'; END IF;\n'
checks=check("current_user='postgres' AND EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls) AND (rolsuper OR rolcreaterole))","Expected staging migration owner")
for r in base['routines']:
 checks+=check("EXISTS(SELECT FROM pg_proc WHERE oid=to_regprocedure("+lit('public.'+r['sig'])+") AND md5(prosrc)="+lit(r['body_md5'])+" AND pg_get_userbyid(proowner)="+lit(r['owner'])+" AND proacl @> "+lit(r['acl'])+"::aclitem[] AND proacl <@ "+lit(r['acl'])+"::aclitem[])","Staging routine drift: "+r['sig'])
for tbl in ['specialist_profiles','specialist_media','specialist_contact_channels','specialist_services','specialist_channel_sets','specialist_settings','profile_slug_registry']:
 checks+=check(f"EXISTS(SELECT FROM pg_class WHERE oid=to_regclass('public.{tbl}') AND relrowsecurity AND relforcerowsecurity AND NOT has_table_privilege('anon',oid,'SELECT') AND NOT has_table_privilege('authenticated',oid,'SELECT'))","Table drift: "+tbl)
checks+=check("EXISTS(SELECT FROM storage.buckets WHERE id='specialist-media' AND NOT public AND file_size_limit=5242880 AND allowed_mime_types @> ARRAY['image/jpeg','image/png','image/webp'] AND cardinality(allowed_mime_types)=3)","Private bucket configuration mismatch")
checks+=check("NOT EXISTS(SELECT FROM pg_attribute WHERE attrelid='public.specialist_profiles'::regclass AND attname='version' AND NOT attisdropped) AND NOT EXISTS(SELECT FROM pg_roles WHERE rolname='specialist_operator') AND to_regprocedure('public.get_public_specialist_v1(text)') IS NULL","Unexpected publication baseline")
for p in base['specialist_policies']:
 checks+=check("EXISTS(SELECT FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname="+lit(p['policyname'])+" AND roles=ARRAY['authenticated']::name[] AND cmd="+lit(p['cmd'])+" AND permissive='PERMISSIVE' AND qual IS NOT DISTINCT FROM "+(lit(p['qual']) if p['qual'] else 'NULL')+" AND with_check IS NOT DISTINCT FROM "+(lit(p['with_check']) if p['with_check'] else 'NULL')+")","Storage policy drift: "+p['policyname'])
guard="DO $baseline$ BEGIN\n"+checks+"END $baseline$;\n"
(out/'baseline-check.sql').write_text(guard)
parts=[]
for f in files:
 s=(root/'sql'/(f+'.sql')).read_text()
 s=re.sub(r'^(BEGIN;|COMMIT;)\s*$', '',s,flags=re.M)
 if f.startswith('20261122'):
  s=s.replace("AND p.profile_status='draft'\n WHERE r.slug=p_slug;", "AND p.profile_status='draft' AND p.slug=r.slug\n WHERE r.slug=p_slug AND EXISTS(SELECT FROM public.profile_slug_registry g WHERE g.slug=r.slug AND g.profile_kind='specialist' AND g.profile_id=p.id);")
 parts.append('-- '+f+'\n'+s)
apply="BEGIN;\nSET LOCAL lock_timeout='5s';\nLOCK TABLE public.specialist_profiles,public.specialist_media,storage.objects IN SHARE ROW EXCLUSIVE MODE;\n"+guard+'\n'.join(parts)
apply+="""
DO $$ BEGIN
 IF EXISTS(SELECT FROM public.specialist_profiles p WHERE NOT EXISTS(SELECT FROM public.profile_slug_registry g WHERE g.profile_kind='specialist' AND g.profile_id=p.id AND g.slug=p.slug))
 THEN RAISE EXCEPTION 'Slug registry mismatch'; END IF;
 IF EXISTS(SELECT FROM public.specialist_media m LEFT JOIN storage.objects o ON o.bucket_id='specialist-media' AND o.name=m.object_name
 WHERE o.id IS NULL OR o.metadata->>'mimetype' IS NULL OR o.metadata->>'mimetype' NOT IN ('image/jpeg','image/png','image/webp')
 OR NOT coalesce((o.metadata->>'size')~'^[0-9]{1,8}$',false) OR (o.metadata->>'size')::bigint NOT BETWEEN 1 AND 5242880)
 THEN RAISE EXCEPTION 'Review mismatched historical metadata without removing objects'; END IF;
END $$;

-- Adopt only metadata already paired with an existing private object.
-- A historical upload has no client retry fingerprint. Never fabricate one.
INSERT INTO public.specialist_upload_reservations(id,profile_id,specialist_id,object_name,kind,caption,state)
SELECT gen_random_uuid(),m.specialist_id,m.specialist_id,m.object_name,m.kind,m.caption,'ready'
FROM public.specialist_media m JOIN storage.objects o ON o.bucket_id='specialist-media' AND o.name=m.object_name;
NOTIFY pgrst,'reload schema';
COMMIT;
"""
(out/'01-install.sql').write_text(apply)
(out/'02-enable-media.sql').write_text((root/'sql/release/80_ENABLE_MEDIA_CANDIDATE.sql').read_text())
(out/'03-enable-public.sql').write_text("""BEGIN;
LOCK TABLE public.specialist_publication_state IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN IF EXISTS(SELECT FROM public.specialist_publication_state WHERE state='published') THEN RAISE EXCEPTION 'Unexpected existing audience'; END IF; END $$;
UPDATE public.specialist_public_control SET enabled=true WHERE singleton;
COMMIT;
""")
manifest=json.loads((here/'manifest.json').read_text())
tables=manifest['tables']; funcs=manifest['functions']
new_objects=''.join(check("to_regclass("+lit('public.'+n)+") IS NULL",'Relation already exists: '+n) for n in tables)
new_objects+=''.join(check("to_regprocedure("+lit('public.'+f['sig'])+") IS NULL",'Routine already exists: '+f['sig']) for f in funcs)
policy_checks=''
for name,cmd,permissive,digest,roles in base['policies']:
    role_sql="ARRAY["+",".join(lit(r) for r in (roles or []))+"]::text[]"
    policy_checks+=check(f"""EXISTS(SELECT FROM pg_policy WHERE polrelid='storage.objects'::regclass AND polname={lit(name)} AND polcmd={lit(cmd)} AND polpermissive={str(permissive).lower()} AND md5(coalesce(pg_get_expr(polqual,polrelid),'')||'|'||coalesce(pg_get_expr(polwithcheck,polrelid),''))={lit(digest)} AND ARRAY(SELECT rolname::text FROM pg_roles WHERE oid=ANY(polroles) ORDER BY rolname) @> {role_sql} AND cardinality(polroles)={len(roles or [])})""",'Storage policy mismatch: '+name)
policy_checks+=check("(SELECT count(*) FROM pg_policy WHERE polrelid='storage.objects'::regclass)="+str(len(base['policies'])),"Unexpected Storage policy")
host_guard='DO $storage$ BEGIN\n'+policy_checks+'END $storage$;\n'
(out/'hosted-storage-check.sql').write_text(host_guard)
object_guard='DO $objects$ BEGIN\n'+new_objects+'END $objects$;\n'
# Supabase can grant table and function privileges through role-specific defaults.
# Normalize only new objects to the tested access matrix, inside the install transaction.
tighten=''
for n in tables:tighten+=f'REVOKE ALL ON TABLE public.{n} FROM PUBLIC,anon,authenticated,service_role;\n'
for f in funcs:
    for role in ['PUBLIC','anon','authenticated','service_role']:
        acl=f['acl'] or ''
        if not re.search(r'(?:^\{|,)'+('' if role=='PUBLIC' else role)+r'=X',acl):
            tighten+=f"REVOKE EXECUTE ON FUNCTION public.{f['sig']} FROM {role};\n"
apply=apply.replace(guard,guard+object_guard+host_guard).replace("NOTIFY pgrst,'reload schema';\nCOMMIT;",tighten+"NOTIFY pgrst,'reload schema';\nCOMMIT;")
(out/'01-install.sql').write_text(apply)
# Rescue archive is written outside the database before losing rollout-only data.
rows=[f"SELECT {lit(n)} AS relation,to_jsonb(t) AS payload FROM public.{n} t" for n in tables]
rows.append("SELECT 'specialist_profiles.version',jsonb_build_object('id',id,'version',version) FROM public.specialist_profiles")
archive="SELECT jsonb_build_object('relation',relation,'payload',payload) AS row FROM ("+' UNION ALL '.join(rows)+") records"
(out/'archive-query.sql').write_text('SELECT row::text FROM ('+archive+") records ORDER BY row::text COLLATE \"C\";\n")
digest="SELECT md5(coalesce(string_agg(row::text,E'\\n' ORDER BY row::text COLLATE \"C\"),'')) FROM ("+archive+") records"
(out/'archive-digest.sql').write_text(digest+';\n')
rb="BEGIN;\nSET LOCAL lock_timeout='5s';\nLOCK TABLE "+','.join(['public.'+n for n in tables]+['public.specialist_profiles','storage.objects','public.specialist_media'])+" IN ACCESS EXCLUSIVE MODE;\n"
rb+="DO $rollback$ BEGIN\n"+check("NOT EXISTS(SELECT FROM public.specialist_public_control WHERE enabled) AND NOT EXISTS(SELECT FROM public.specialist_upload_control WHERE enabled OR deletions_enabled)","Quiesce public and media traffic before rollback")+check("current_setting('otz.recovery_archive_digest',true)=("+digest+")","Rollback archive missing or stale")+check("NOT EXISTS(SELECT FROM public.specialist_upload_reservations WHERE state IN ('uploading','deleting')) AND NOT EXISTS(SELECT FROM public.specialist_profiles WHERE profile_status='erasing')","Reconcile in-flight work before rollback")+'END $rollback$;\n'
for n in manifest['policies']:rb+=f'DROP POLICY {n} ON storage.objects;\n'
for trg in manifest['triggers']:rb+=f"DROP TRIGGER {trg['tgname']} ON public.{trg['tab']};\n"
rb+='DROP TABLE '+','.join('public.'+n for n in tables)+';\n'
rb+='DROP FUNCTION '+','.join('public.'+f['sig'] for f in funcs)+';\n'
rb+='ALTER TABLE public.specialist_profiles DROP COLUMN version, DROP CONSTRAINT specialist_profiles_status_check;\nALTER TABLE public.specialist_profiles ADD CONSTRAINT specialist_profiles_status_check '+base['profile_check']+';\n'
defs=(here/'baseline-functions.sql').read_text()
start=defs.index('CREATE OR REPLACE FUNCTION public.delete_my_specialist_draft(')
rb+=defs[start:defs.index('REVOKE ALL ON FUNCTION',start)]
for sig in ['register_my_specialist_media(uuid,text,text,text)','delete_my_specialist_media(uuid,uuid)']:rb+='GRANT EXECUTE ON FUNCTION public.'+sig+' TO authenticated;\n'
for p in base['specialist_policies']:
    if p['cmd']=='SELECT':continue
    rb+=f"CREATE POLICY {p['policyname']} ON storage.objects FOR {p['cmd']} TO authenticated "+('USING ('+p['qual']+')' if p['qual'] else 'WITH CHECK ('+p['with_check']+')')+';\n'
rb+="REVOKE SELECT,DELETE ON storage.objects FROM specialist_operator;\nREVOKE USAGE ON SCHEMA public,storage FROM specialist_operator;\nDROP ROLE specialist_operator;\n"+guard+host_guard+"NOTIFY pgrst,'reload schema';\nCOMMIT;\n"
(out/'90-rollback.sql').write_text(rb)
# A managed Storage relation belongs to supabase_storage_admin. Only the policy
# statements run as its owner; all public DEFINER routines stay owned by postgres.
def owner_scoped(s):
    s=s.replace('BEGIN;\n',"""BEGIN;
DO $$ BEGIN
 IF NOT pg_has_role(session_user,'postgres','SET') OR NOT pg_has_role(session_user,'supabase_storage_admin','SET')
 THEN RAISE EXCEPTION 'Approved operator must already be allowed to assume both object owners'; END IF;
 IF (SELECT relowner FROM pg_class WHERE oid='storage.objects'::regclass) <> 'supabase_storage_admin'::regrole
 THEN RAISE EXCEPTION 'Unexpected Storage relation owner'; END IF;
END $$;
SET LOCAL ROLE postgres;
""",1)
    return re.sub(r'^(?:(?:CREATE|DROP) POLICY [^;]+ ON storage\.objects[^;]*;)$',
                  lambda m:'SET LOCAL ROLE supabase_storage_admin;\n'+m[0]+'\nSET LOCAL ROLE postgres;',s,flags=re.M)
def hosted_scoped(sql):
    guard = """DO $hosted$ BEGIN
 IF current_user <> 'postgres' OR
    (SELECT relowner FROM pg_class WHERE oid='storage.objects'::regclass) <> 'supabase_storage_admin'::regrole OR
    NOT coalesce((current_setting('supautils.policy_grants',true)::jsonb -> 'postgres') ? 'storage.objects',false) OR
    NOT has_table_privilege(current_user,'storage.objects','SELECT WITH GRANT OPTION') OR
    NOT has_table_privilege(current_user,'storage.objects','DELETE WITH GRANT OPTION') OR
    NOT has_schema_privilege(current_user,'storage','USAGE WITH GRANT OPTION')
 THEN RAISE EXCEPTION 'Hosted Storage delegation missing'; END IF;
END $hosted$;"""
    return sql.replace('BEGIN;\n', 'BEGIN;\n' + guard + '\n', 1)

scope = hosted_scoped if sys.argv[2:] == ['--hosted'] else owner_scoped
if sys.argv[2:] not in ([], ['--hosted']):
    raise SystemExit('Expected output directory and optional --hosted')
(out/'01-install.sql').write_text(scope(apply))
(out/'90-rollback.sql').write_text(scope(rb))

(out/'80-quiesce.sql').write_text("""BEGIN;
SET LOCAL lock_timeout='5s';
UPDATE public.specialist_public_control SET enabled=false WHERE singleton;
UPDATE public.specialist_upload_control SET enabled=false,deletions_enabled=false WHERE singleton;
COMMIT;
""")
