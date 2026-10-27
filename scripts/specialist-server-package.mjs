// No database connection. Independent reviewed transactions; stop on first error.
export const serverPackage=[
  "sql/release/00_PREFLIGHT_CANDIDATE.sql",
  "sql/release/05_STORAGE_BARRIER_CANDIDATE.sql",
  "sql/release/10_SERVICES_CANDIDATE.sql",
  "sql/release/20_SETTINGS_CANDIDATE.sql",
  "sql/release/30_MEDIA_CANDIDATE.sql",
  "sql/release/40_CORE_LIFECYCLE_CANDIDATE.sql",
  "sql/release/50_CHANNELS_CANDIDATE.sql",
  "sql/release/60_GATEWAY_CANDIDATE.sql",
  "sql/release/65_GATEWAY_REMEDIATION_CANDIDATE.sql",
  "sql/release/70_POSTCHECK_CANDIDATE.sql"
];
