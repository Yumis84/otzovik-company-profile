# Public profile publisher architecture

## Trust boundary

`otzovik-company-profile` is the source/private-side publisher repository.
`otzovik-public-profiles` is public output only.

No Supabase service-role credential, private Storage URL, signed URL, or raw private object path may be committed to the public output repository.

## Target pipeline

1. Receive company slug.
2. Read canonical public profile data from `get_public_company_profile_v2(slug)`.
3. In a privileged runtime, identify media approved for public profile use.
4. Download approved private Storage objects to an ephemeral workspace, naming local files by media UUID.
5. Run `scripts/export-approved-media.py` to create a sanitized manifest.
6. Run the public repository's deterministic media publisher against the ephemeral files.
7. Commit only generated profile artifacts, approved media bytes and `media.json` to `otzovik-public-profiles`.
8. Delete the ephemeral workspace.

## Credentials

The future privileged workflow must use repository/environment secrets. Secrets must never be embedded in scripts or generated artifacts. Prefer a narrowly scoped server-side credential and rotate it independently of the public build.

## Publication invariant

Public pages must remain readable if Supabase is temporarily unavailable. Runtime page views must not require private Storage or privileged Supabase access.
