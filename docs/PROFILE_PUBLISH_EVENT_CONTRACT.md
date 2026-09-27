# Profile publish event contract

## Goal

Regenerate one public company profile after a successful canonical mutation without exposing GitHub credentials to the browser.

## Event

The trusted emitter sends only:

```json
{
  "event_type": "publish-company-profile",
  "client_payload": {
    "slug": "student-agency"
  }
}
```

The public build must fetch canonical profile data itself. Browser-supplied profile fields, HTML, media paths and repository refs are never trusted as build input.

## Security boundary

The browser MUST NOT call GitHub repository_dispatch directly and MUST NOT receive a GitHub token.

The emitter must execute in a trusted server-side environment and hold a narrowly scoped credential able to trigger the public-profile repository workflow. The credential must be stored as a server-side secret.

## Mutation flow

1. Authenticated owner edits company data.
2. Existing canonical RPC validates and commits the mutation.
3. Only after successful commit, the trusted backend emits the company slug.
4. The public repository receives `publish-company-profile`.
5. Workflow validates the slug.
6. Workflow fetches canonical public data from Supabase.
7. Renderer replaces generated artifacts for that slug.
8. Workflow commits only when output changed.

## Failure semantics

Publishing is asynchronous. A failure to regenerate the static profile must not roll back a successful canonical data mutation.

Failed publish events must be retryable and observable. Repeated events for the same slug may be coalesced because the build reads current canonical state.

## Idempotency

The slug identifies the rebuild target. Multiple events are safe: the resulting artifact represents the latest canonical public state.

## Recommended emitter placement

Preferred: a small Supabase Edge Function or another trusted backend already responsible for post-mutation work.

Do not place the emitter in:
- browser JavaScript;
- public GitHub repository code containing credentials;
- static GitHub Pages;
- a Cloudflare-only path required for Russian users.

## Next activation requirement

Activation requires one server-side GitHub credential with only the permissions necessary to dispatch the public-profile build. No credential is currently added by this document.
