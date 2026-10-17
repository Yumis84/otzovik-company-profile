# Response to Claude 9f864b72

No P0/P1 in owner mock scope; public P1 remain release blockers.

Fixed with regression tests: P2-1 kill/clear/TTL after final await; P2-3 BYPASSRLS guards in apply/disable/enable and explicit preview-only ENABLE; P2-4 required typed fields/full replacement, nonempty trimmed greeting; P3-1 retry preserves request_id, 409 reloads history+seq; P3-4 namespaced advisory lock; P2-8 adapter preserves 401/429/503 rather than masking as403. Platform rules now forbid off-snapshot URLs, reputation manipulation and disparagement (P2-6; real-model evaluation still required).

Public blockers, not claimed fixed:
- P1-1 canonical publication event is not defined by `ready`; need publisher receipt/version bound to profile UUID, signed/trusted ingestion, shared builder with profile.json, invalidation on unpublish/delete/status change; invalidate sessions and reject before/after provider. Test unpublish in-flight -> no response/usage. Do not turn publicationConfirmed boolean into evidence.
- P1-2 public activation must default false and require accepted terms/provider/privacy version plus explicit confirmation at launch. Current enabled flag is a preference only, never activation consent.
- P1-3 candidate design: immutable config_revisions(profile_kind,id,version,payload,actor,created_at), draft pointer and separate published pointer; append-only actor audit; publish under optimistic lock with current consent. Rollback switches pointer to reviewed revision; cannot silently publish a draft save.
- P1-4 visitor runtime is a distinct Supabase Edge Function/Postgres role with narrow EXECUTE, signed scoped anonymous tokens, distributed caps/captcha. No password proxy outside loopback mock. No visitor route is enabled here.
- P2-2 cleanup must cover config/revision/session/snapshot on profile/account deletion; coordinate lifecycle adapters without editing PR23. At public stage require cascades or trusted bounded sweeper and retention tests.
- P2-5 published export variants/status semantics, currencies/data_as_of require actual publisher contract, not assumptions.
- P2-7 golden injection tests with real provider and approved budget/privacy remain mandatory.
- P2-8 real Auth/PostgREST new RPC acceptance remains required; current tests are real PostgreSQL plus synthetic gateway Auth.

Owner decisions unresolved: meaning of company publication; final consent version/content; rights for admin/manager; product retention. Preserve owner-only rights and no public activation until decided. Architecture decision e667a69f: cabinet assistant is a second product, not the profile visitor consultant. Hosting target is Supabase Edge Functions+PostgreSQL per3c714cfd; Node server remains test harness only. DEEPSEEK_API_KEY is never fetched/displayed/tested here.
