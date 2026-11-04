-- Authentication and player session foundation.
ALTER TABLE players ADD COLUMN password_hash TEXT;
ALTER TABLE players ADD COLUMN email_verified_at TEXT;

CREATE TABLE IF NOT EXISTS player_sessions (
  session_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auth_rate_limits (
  fingerprint TEXT PRIMARY KEY,
  failed_attempts INTEGER NOT NULL DEFAULT 0,
  window_started_at INTEGER NOT NULL,
  blocked_until INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_player_sessions_player ON player_sessions(player_id);
CREATE INDEX IF NOT EXISTS idx_player_sessions_expiry ON player_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_blocked ON auth_rate_limits(blocked_until);
