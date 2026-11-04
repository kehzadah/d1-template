CREATE UNIQUE INDEX IF NOT EXISTS idx_vendor_applications_one_open_per_player
  ON vendor_applications(player_id)
  WHERE status IN ('pending','approved');
