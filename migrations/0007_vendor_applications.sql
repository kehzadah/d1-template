-- Vendor application and review workflow.
CREATE TABLE IF NOT EXISTS vendor_applications (
  application_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
  business_name TEXT NOT NULL,
  business_description TEXT NOT NULL,
  product_category TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by TEXT REFERENCES players(player_id),
  review_note TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  reviewed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_vendor_applications_status_created
  ON vendor_applications(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_vendor_applications_player_created
  ON vendor_applications(player_id, created_at DESC);
