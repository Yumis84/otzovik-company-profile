import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {pgcrypto} from '@electric-sql/pglite/contrib/pgcrypto';

// Disposable catalog fixture. No remote endpoints, credentials or user data.
const db = new PGlite({extensions: {pgcrypto}});
const root = new URL('../sql/candidates/company-invitations-review/', import.meta.url);
const snapshot = JSON.parse(await fs.readFile(new URL('source-snapshot.json', root), 'utf8'));
const candidate = await fs.readFile(new URL('01-candidate.sql', root), 'utf8');
const owner = '11111111-1111-4111-8111-111111111111';
const recipient = '22222222-2222-4222-8222-222222222222';
const stranger = '33333333-3333-4333-8333-333333333333';
const noEmail = '44444444-4444-4444-8444-444444444444';
const company = '55555555-5555-4555-8555-555555555555';
let passed = 0;
async function test(name, action) {
  await action();
  passed++;
  console.log('PASS ' + name);
}
async function session(uid, sql, args = [], role = 'authenticated', rollback = false) {
  assert(['authenticated', 'anon'].includes(role));
  await db.exec('BEGIN; SET LOCAL ROLE ' + role);
  try {
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [uid || '']);
    const result = await db.query(sql, args);
    await db.exec(rollback ? 'ROLLBACK' : 'COMMIT');
    return result.rows[0]?.data;
  } catch (error) {
    await db.exec('ROLLBACK');
    throw error;
  }
}
const rpc = (uid, name, args = []) => session(uid,
  'SELECT public.' + name + '(' + args.map((_, i) => '$' + (i + 1)).join(',') + ') AS data', args);
const issue = () => rpc(owner, 'owner_invite_existing_company_user', [company, 'recipient@example.test', 'manager']);
try {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    CREATE SCHEMA auth; CREATE SCHEMA extensions;
    CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
    CREATE TABLE auth.users(id uuid PRIMARY KEY,email text);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    CREATE TABLE public.companies(id uuid PRIMARY KEY,name text,slug text);
    CREATE TABLE public.company_memberships(company_id uuid REFERENCES companies,
      user_id uuid REFERENCES auth.users,role text,verification_status text,
      verification_method text,verified_at timestamptz,created_at timestamptz DEFAULT now(),
      PRIMARY KEY(company_id,user_id));`);
  await db.query('INSERT INTO auth.users VALUES ($1,$2),($3,$4),($5,$6),($7,NULL)',
    [owner,'owner@example.test',recipient,'recipient@example.test',stranger,'stranger@example.test',noEmail]);
  await db.query("INSERT INTO companies VALUES ($1,'Fixture','fixture')", [company]);
  await db.query("INSERT INTO company_memberships(company_id,user_id,role,verification_status) VALUES ($1,$2,'owner','verified')",[company,owner]);
  await db.exec(candidate);
  let invitation = await issue();
  await test('reproduce original null-email acceptance in rolled-back fixture', async () => {
    const original = snapshot.functions.find(f => f.signature === 'accept_my_company_invitation(uuid)').definition;
    await db.exec(original);
    const result = await session(noEmail, 'SELECT public.accept_my_company_invitation($1) AS data', [invitation.invitation_id], 'authenticated', true);
    assert.equal(result.status, 'accepted');
    assert.equal((await db.query('SELECT count(*)::int n FROM company_memberships WHERE user_id=$1',[noEmail])).rows[0].n,0);
    const corrected = candidate.match(/CREATE OR REPLACE FUNCTION public\.accept_my_company_invitation\(p_invitation_id uuid\)[\s\S]*?end \$function\$;/i)?.[0];
    assert(corrected);
    await db.exec(corrected);
  });
  await test('corrected acceptance rejects null email', async () => {
    await assert.rejects(rpc(noEmail,'accept_my_company_invitation',[invitation.invitation_id]), e => e.code==='42501');
  });
  await test('foreign email cannot accept or read another invitation', async () => {
    await assert.rejects(rpc(stranger,'accept_my_company_invitation',[invitation.invitation_id]));
    assert.deepEqual(await rpc(stranger,'get_my_pending_company_invitations'),[]);
    assert.equal(await rpc(stranger,'decline_my_company_invitation',[invitation.invitation_id]),false);
  });
  await test('owner authorization and role validation', async () => {
    await assert.rejects(rpc(stranger,'get_my_company_access',[company]),e=>e.code==='42501');
    await assert.rejects(rpc(stranger,'owner_invite_existing_company_user',[company,'recipient@example.test','admin']));
    await assert.rejects(rpc(owner,'owner_invite_existing_company_user',[company,'recipient@example.test','owner']));
  });
  await test('invitation list exposes only matching recipient', async () => {
    const list = await rpc(recipient,'get_my_pending_company_invitations');
    assert.equal(list.length,1); assert.equal(list[0].id,invitation.invitation_id);
    assert.deepEqual(await rpc(owner,'get_my_pending_company_invitations'),[]);
  });
  await test('anonymous execution and direct table access denied', async () => {
    await assert.rejects(session(null,'SELECT public.get_my_pending_company_invitations() AS data',[],'anon'),e=>e.code==='42501');
    await assert.rejects(session(recipient,'SELECT * FROM public.company_access_invitations'),e=>e.code==='42501');
  });
  await test('expiry denies membership creation', async () => {
    await db.query("UPDATE company_access_invitations SET expires_at=now()-interval '1 second' WHERE id=$1",[invitation.invitation_id]);
    assert.equal((await rpc(recipient,'accept_my_company_invitation',[invitation.invitation_id])).status,'expired');
    assert.equal((await db.query('SELECT count(*)::int n FROM company_memberships WHERE user_id=$1',[recipient])).rows[0].n,0);
    invitation = await issue();
  });
  await test('decline and owner revocation retain isolation', async () => {
    assert.equal(await rpc(recipient,'decline_my_company_invitation',[invitation.invitation_id]),true);
    invitation=await issue();
    await assert.rejects(rpc(stranger,'revoke_company_access_invitation',[invitation.invitation_id]),e=>e.code==='42501');
    assert.equal(await rpc(owner,'revoke_company_access_invitation',[invitation.invitation_id]),true);
    invitation=await issue();
  });
  await test('token acceptance denies foreign and missing-email recipients', async () => {
    await assert.rejects(rpc(stranger,'accept_company_access_invitation',[invitation.token]));
    await assert.rejects(rpc(noEmail,'accept_company_access_invitation',[invitation.token]));
    assert.equal((await rpc(recipient,'get_my_pending_company_invitations')).length,1);
  });
  await test('matching token recipient receives role inside a rolled-back fixture', async () => {
    const result = await session(recipient,'SELECT public.accept_company_access_invitation($1) AS data',[invitation.token],'authenticated',true);
    assert.equal(result.status,'accepted');
    assert.equal(result.role,'manager');
    assert.equal((await db.query('SELECT count(*)::int n FROM company_memberships WHERE user_id=$1',[recipient])).rows[0].n,0);
  });
  await test('matching recipient accepts once and receives invited role', async () => {
    assert.equal((await rpc(recipient,'accept_my_company_invitation',[invitation.invitation_id])).status,'accepted');
    await assert.rejects(rpc(recipient,'accept_my_company_invitation',[invitation.invitation_id]));
    const rows = await db.query('SELECT role FROM company_memberships WHERE user_id=$1',[recipient]);
    assert.deepEqual(rows.rows,[{role:'manager'}]);
  });
  await test('all restored RPCs pin search_path and deny anon', async () => {
    const rows=await db.query("SELECT proname,proconfig,has_function_privilege('anon',oid,'EXECUTE') AS anon FROM pg_proc WHERE pronamespace='public'::regnamespace AND prosecdef");
    assert.equal(rows.rows.length,7);
    for(const row of rows.rows){assert.equal(row.anon,false);assert.deepEqual(row.proconfig,['search_path=""']);}
  });
  await test('rollback refuses to discard invitation data', async () => {
    const rollback = await fs.readFile(new URL('90-rollback.sql',root),'utf8');
    await assert.rejects(db.exec(rollback)); await db.exec('ROLLBACK');
    assert((await db.query("SELECT to_regclass('public.company_access_invitations') AS t")).rows[0].t);
  });
  await test('empty-module rollback preserves original companies and memberships', async () => {
    const companiesBefore=(await db.query('SELECT * FROM companies ORDER BY id')).rows;
    const membersBefore=(await db.query('SELECT * FROM company_memberships ORDER BY company_id,user_id')).rows;
    // Discard only rows in this disposable in-memory fixture to meet rollback's empty-module boundary.
    await db.exec('DELETE FROM public.company_access_invitations');
    const rollback=await fs.readFile(new URL('90-rollback.sql',root),'utf8');
    await db.exec(rollback);
    assert.equal((await db.query("SELECT to_regclass('public.company_access_invitations') AS table_name")).rows[0].table_name,null);
    for(const item of snapshot.functions){
      const row=(await db.query('SELECT to_regprocedure($1) AS fn',['public.'+item.signature])).rows[0];
      assert.equal(row.fn,null,item.signature+' removed');
    }
    assert.deepEqual((await db.query('SELECT * FROM companies ORDER BY id')).rows,companiesBefore);
    assert.deepEqual((await db.query('SELECT * FROM company_memberships ORDER BY company_id,user_id')).rows,membersBefore);
  });
  console.log('PASS '+passed+' disposable invitation regression groups');
} finally { await db.close(); }
