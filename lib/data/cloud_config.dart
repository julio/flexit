/// Supabase REST config for cloud backup.
///
/// The publishable key below is a *client* key — it is meant to ship inside
/// the app binary. Access to the single `backups` row is governed by a
/// permissive row-level-security policy (no login), which the user explicitly
/// chose: this is a personal workout log, not sensitive data. The secret /
/// service_role key and the database password are NOT in the repo.
const cloudUrl = 'https://mfuybukljlklesytyguw.supabase.co';
const cloudKey = 'sb_publishable_gL3s0AWG66JpCzne_1rbxg_JmeD5vTm';

/// Single row that holds the full snapshot (one user, one device-of-record).
const cloudBackupRowId = 'flexit-primary';
