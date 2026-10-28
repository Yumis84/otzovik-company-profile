# Synthetic safety preparation — candidate only

Basis: PR44 f809b762, REQUEST 194af7e8, Claude a1061475. Do not deploy or connect this harness to hosted, production, real users or keys. The code is deliberately under tests/fixtures, uses ephemeral keys and in-memory state, and cannot authorize an actual Supabase RPC or Storage operation.

## Operator credentials and lost-login support

`tests/fixtures/synthetic-safety.mjs` models a signature-verified identity assertion with synthetic MFA, a distinct signing key, 60-second subject/profile/request-scoped credential, replay rejection, online revocation and disabled-identity checks on every simulated use. It tests mismatched subject/scope/audience, stale MFA, expiry, forgery, replay and revocation. Both identity provider and revocation store are fake and live in one process: this is **not** a verified MFA provider, trusted issuer, durable atomic store, Supabase JWT integration, or a deployed revocation mechanism. Do not wire these tokens directly into PostgREST/Storage: existing role policies do not check their JTI. A real implementation requires a separately reviewed trusted identity/MFA verifier, independent issuer and signing service, persistent atomic replay/revocation records, per-use enforcement at all RPC and Storage entry points, cryptographic key rotation, concurrency/failure behavior and independently verified identity-to-person binding. Until tested through actual Auth/PostgREST/Storage, issuer/MFA/revocation remain BLOCKED.

Lost-login fixture requires a non-subject requester and two distinct reviewers, logs only synthetic IDs and never issues an authorization or deletes data. It is an audit-state exercise, **not** a real subject-verification or legal support process. Owner/legal policy for evidence, independent verification, consent/legal basis, time-limited case-specific approval, audit/retention, appeal and fraud escalation is unapproved; real flow remains NOT IMPLEMENTED. Never use test assertions as proof or bypass ownership by SQL.

## Writer inventory and drain evidence

| Writer class | Candidate evidence to collect after separate approval | Current |
|---|---|---|
| Gateway and background executions | generation, deployed code, admission freeze, all invocation IDs and provider-authoritative join/termination | UNKNOWN |
| privileged SDK/REST and service keys | named holders, generations, capability inventory and verified revocation | UNKNOWN |
| Storage direct upload, signed URLs, TUS and multipart | complete issued capabilities, expiry/revocation and provider terminal status of each admitted request | UNKNOWN |
| scheduled jobs, queues, retries and legacy deployments | exhaustive registry, disabled generation, complete execution inventory and proof of no later POST or commit | UNKNOWN |
| operator/backfill/manual paths | identities, scoped capabilities, access freeze and independent reviewer | UNKNOWN |

Two independent reviewers must sign inventory completeness and per-writer evidence. Preserve restricted evidence references and opaque fingerprints; never save tokens, emails, image bytes or credentials. D1 freeze, D2 fence, D3 join every pre-POST execution and D4 provider-authoritative remote drain remain BLOCKED. The worksheet validator returns `providerDrainVerified=false` and `allowDeletion=false` even for a fully populated synthetic worksheet. Quiet logs, timeout, TTL, absence or key rotation alone are not proof. A genuinely fresh separately approved isolated target may establish a clean provenance/no inherited writers only with independently documented provider configuration and an exhaustive inventory; do not manufacture proof here.

## Monitoring and rollback

The harness tests alert payload, acknowledged mock delivery, rejected missing acknowledgment and transport failure. It does not deploy an alert sink, on-call policy or delivery monitoring. Required hosted evidence: end-to-end critical orphan and stale-begin alert, delivery, acknowledgment, retries, escalation, separate operator and failure drills. The rollback function produces an inert sequence only, refuses non-local target and never calls a service. Approved real rollback requires a project-specific reviewed plan: stop admission, preserve RLS/FK/audit and quarantined data, account for pending writers and credential generations, validate one previous UI artifact, review/approve each action and document verification. Do not disable barriers to speed recovery. Neither mock delivery nor dry-run closes these gates.

## Owner decisions — blank, not authorization

| Decision | Options/questions | Status |
|---|---|---|
| Test target | Identify disposable project, region, exact SHA, costs, synthetic accounts, window, operator and rollback | NOT CHOSEN; no project created |
| Storage | strict20 + quarantine vs independently reviewed alternative; new bucket/cutover | NOT DECIDED |
| Auth | confirmation, SMTP, recovery, rate limits, issuer/MFA, independent operators | NOT DECIDED |
| Retention | audit/tombstone/confirmation/authorization minimum, deletion and legal basis | NOT DECIDED |
| Cohort | synthetic-only bounds, stop conditions, on-call, later separate real-user decision | NOT DECIDED |
| TTL | 15-minute authorization/begin candidate vs reviewed alternative | NOT DECIDED |

## CI trust boundary and public pages

The PR44 guard is self-referential if a PR can change its checker, manifest and workflow together. `scripts/trusted-surface-candidate.mjs` compares the PR44 guard, manifest and named workflows plus `index.html`, `profile.html`, `profile.css`, `profile.json`, `profile.md` against immutable PR44 commit f809b762. It demonstrates rejection of changes to those paths. This list is a **bounded review scope**, not a complete audit of every public asset. Critically, a PR author can alter or skip this candidate check and its workflow. The actual trust root must be an independently administered required check/workflow pinned outside the PR, protected branch/ruleset and review ownership for the guard, manifest, workflows and public assets. This task does not change repository ACL, branch protection or workflow administration; therefore P2 self-modification and workflow-bypass risk remains OPEN until independently configured and tested. No claim that an ordinary PR workflow can enforce itself.

## Test interpretation and gates

Run `node tests/synthetic-security.mjs` and `node tests/trusted-surface-candidate.mjs` locally. The former has no network or real keys. Existing loopback-only disposable CI exercises real local Supabase separately; it cannot verify hosted issuer, MFA, provider drain or real delivery. PG16/17 results must be reported separately. Hosted synthetic still NO-GO without all A–H, independent review and explicit project-specific authorization; pilot and production require separate gates.
