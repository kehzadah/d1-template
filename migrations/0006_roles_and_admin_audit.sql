-- CrystalzCrystalz role-based administration foundation.
CREATE TABLE IF NOT EXISTS roles (
  role_key TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS player_roles (
  player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
  role_key TEXT NOT NULL REFERENCES roles(role_key),
  assigned_at TEXT NOT NULL DEFAULT (datetime('now')),
  assigned_by TEXT,
  PRIMARY KEY (player_id, role_key)
);

CREATE INDEX IF NOT EXISTS idx_player_roles_role ON player_roles(role_key, player_id);

INSERT OR IGNORE INTO roles (role_key, display_name, description) VALUES
  ('player', 'Player', 'Standard mall account'),
  ('vendor', 'Vendor', 'Independent marketplace vendor'),
  ('moderator', 'Moderator', 'Trust and safety moderation'),
  ('admin', 'Administrator', 'Mall operations administration');

CREATE TRIGGER IF NOT EXISTS assign_default_player_role
AFTER INSERT ON players
BEGIN
  INSERT OR IGNORE INTO player_roles (player_id, role_key, assigned_by)
  VALUES (NEW.player_id, 'player', 'system');
END;

CREATE TABLE IF NOT EXISTS admin_audit_log (
  audit_id TEXT PRIMARY KEY,
  actor_player_id TEXT NOT NULL REFERENCES players(player_id),
  action_key TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT,
  details_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON admin_audit_log(created_at DESC);
