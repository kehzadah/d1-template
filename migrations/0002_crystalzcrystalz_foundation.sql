-- CrystalzCrystalz Virtual Mall backend foundation
-- Additive migration: preserves the original template comments table.
CREATE TABLE IF NOT EXISTS mall_floors (
  floor_number INTEGER PRIMARY KEY CHECK (floor_number BETWEEN 1 AND 3),
  floor_name TEXT NOT NULL,
  floor_type TEXT NOT NULL CHECK (floor_type IN ('brand_retail','vendor_marketplace')),
  description TEXT NOT NULL DEFAULT ''
);

INSERT OR IGNORE INTO mall_floors (floor_number, floor_name, floor_type, description) VALUES
  (1, 'Level 1', 'brand_retail', 'CrystalzCrystalz brand-owned mall level'),
  (2, 'Level 2', 'brand_retail', 'Eight branded retail stores and elevator transfer hub'),
  (3, 'Level 3', 'vendor_marketplace', 'Independent vendor marketplace with twelve customizable booths');

CREATE TABLE IF NOT EXISTS stores (
  store_id TEXT PRIMARY KEY,
  floor_number INTEGER NOT NULL REFERENCES mall_floors(floor_number),
  gender TEXT NOT NULL CHECK (gender IN ('men','women')),
  store_type TEXT NOT NULL CHECK (store_type IN ('clothes','eyewear','luxury_jewelry','handcrafted_jewelry')),
  display_name TEXT NOT NULL UNIQUE,
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  sort_order INTEGER NOT NULL
);

INSERT OR IGNORE INTO stores (store_id, floor_number, gender, store_type, display_name, sort_order) VALUES
 ('men-clothes',2,'men','clothes', 'Men''s Clothes',1),
 ('men-eyewear',2,'men','eyewear', 'Men''s Sunglasses & Glasses',2),
 ('men-luxury-jewelry',2,'men','luxury_jewelry', 'Men''s Luxury Jewelry',3),
 ('men-handcrafted-jewelry',2,'men','handcrafted_jewelry', 'Men''s Handcrafted Jewelry',4),
 ('women-clothes',2,'women','clothes', 'Women''s Clothes',5),
 ('women-eyewear',2,'women','eyewear', 'Women''s Sunglasses & Glasses',6),
 ('women-luxury-jewelry',2,'women','luxury_jewelry', 'Women''s Luxury Jewelry',7),
 ('women-handcrafted-jewelry',2,'women','handcrafted_jewelry', 'Women''s Handcrafted Jewelry',8);

CREATE TABLE IF NOT EXISTS vendor_booths (
  booth_number INTEGER PRIMARY KEY CHECK (booth_number BETWEEN 1 AND 12),
  floor_number INTEGER NOT NULL DEFAULT 3 REFERENCES mall_floors(floor_number),
  vendor_player_id TEXT,
  booth_name TEXT NOT NULL,
  customization_json TEXT NOT NULL DEFAULT '{}',
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  FOREIGN KEY (vendor_player_id) REFERENCES players(player_id)
);

CREATE TABLE IF NOT EXISTS players (
  player_id TEXT PRIMARY KEY,
  email TEXT NOT NULL COLLATE NOCASE UNIQUE,
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  account_status TEXT NOT NULL DEFAULT 'pending' CHECK (account_status IN ('pending','active','suspended','closed')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS player_profiles (
  player_id TEXT PRIMARY KEY REFERENCES players(player_id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_image_key TEXT,
  bio TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS avatars (
  avatar_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
  avatar_config_json TEXT NOT NULL DEFAULT '{}',
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
  product_id TEXT PRIMARY KEY,
  store_id TEXT REFERENCES stores(store_id),
  booth_number INTEGER REFERENCES vendor_booths(booth_number),
  seller_player_id TEXT REFERENCES players(player_id),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  gender TEXT CHECK (gender IN ('men','women','unisex')),
  store_type TEXT CHECK (store_type IN ('clothes','eyewear','luxury_jewelry','handcrafted_jewelry')),
  category TEXT NOT NULL,
  subcategory TEXT NOT NULL DEFAULT '',
  rarity TEXT NOT NULL DEFAULT 'common' CHECK (rarity IN ('common','rare','epic','legendary','mythic')),
  metal TEXT CHECK (metal IN ('gold','silver') OR metal IS NULL),
  photo_key TEXT,
  price_cents INTEGER NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (NOT (gender = 'men' AND store_type = 'handcrafted_jewelry' AND lower(category) = 'watches')),
  CHECK (NOT (gender = 'men' AND store_type = 'handcrafted_jewelry' AND lower(category) = 'earrings' AND lower(subcategory) NOT IN ('stud','studs')))
);

CREATE TABLE IF NOT EXISTS inventory_items (
  inventory_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(product_id),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  acquired_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  acquisition_order_id TEXT,
  UNIQUE (player_id, product_id, acquisition_order_id)
);

CREATE TABLE IF NOT EXISTS shopping_carts (
  cart_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','checked_out','abandoned')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cart_items (
  cart_id TEXT NOT NULL REFERENCES shopping_carts(cart_id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(product_id),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  PRIMARY KEY (cart_id, product_id)
);

CREATE TABLE IF NOT EXISTS orders (
  order_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','fulfilled','cancelled','refunded')),
  subtotal_cents INTEGER NOT NULL CHECK (subtotal_cents >= 0),
  tax_cents INTEGER NOT NULL DEFAULT 0 CHECK (tax_cents >= 0),
  total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
  order_item_id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(order_id),
  product_id TEXT NOT NULL REFERENCES products(product_id),
  seller_player_id TEXT REFERENCES players(player_id),
  product_name_snapshot TEXT NOT NULL,
  unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0)
);

CREATE TABLE IF NOT EXISTS wallet_accounts (
  player_id TEXT PRIMARY KEY REFERENCES players(player_id) ON DELETE CASCADE,
  balance_credits INTEGER NOT NULL DEFAULT 0 CHECK (balance_credits >= 0),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS wallet_ledger (
  ledger_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id),
  entry_type TEXT NOT NULL CHECK (entry_type IN ('purchase','spend','refund','adjustment')),
  amount_credits INTEGER NOT NULL CHECK (amount_credits <> 0),
  reference_type TEXT NOT NULL,
  reference_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payment_records (
  payment_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL REFERENCES players(player_id),
  order_id TEXT REFERENCES orders(order_id),
  provider TEXT NOT NULL DEFAULT 'stripe',
  provider_payment_id TEXT UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('created','pending','succeeded','failed','refunded')),
  amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_events (
  event_id TEXT PRIMARY KEY,
  actor_player_id TEXT REFERENCES players(player_id),
  event_type TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mall_transit (
  transit_id TEXT PRIMARY KEY,
  elevator_name TEXT NOT NULL UNIQUE,
  location_description TEXT NOT NULL,
  from_floor INTEGER NOT NULL REFERENCES mall_floors(floor_number),
  to_floor INTEGER NOT NULL REFERENCES mall_floors(floor_number),
  CHECK (from_floor <> to_floor)
);

INSERT OR IGNORE INTO mall_transit (transit_id, elevator_name, location_description, from_floor, to_floor) VALUES
 ('elevator-a','Elevator A','Right side / Men''s Wing',1,2),
 ('elevator-b','Elevator B','Left side / Women''s Wing',2,3);

CREATE INDEX IF NOT EXISTS idx_products_store_active ON products(store_id, active);
CREATE INDEX IF NOT EXISTS idx_products_booth_active ON products(booth_number, active);
CREATE INDEX IF NOT EXISTS idx_inventory_player ON inventory_items(player_id);
CREATE INDEX IF NOT EXISTS idx_orders_player_created ON orders(player_id, created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_ledger_player_created ON wallet_ledger(player_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_events_created ON audit_events(created_at);

-- Seed the twelve independent vendor booths.
INSERT OR IGNORE INTO vendor_booths (booth_number, floor_number, booth_name) VALUES
 (1,3,'Vendor Booth 01'),(2,3,'Vendor Booth 02'),(3,3,'Vendor Booth 03'),
 (4,3,'Vendor Booth 04'),(5,3,'Vendor Booth 05'),(6,3,'Vendor Booth 06'),
 (7,3,'Vendor Booth 07'),(8,3,'Vendor Booth 08'),(9,3,'Vendor Booth 09'),
 (10,3,'Vendor Booth 10'),(11,3,'Vendor Booth 11'),(12,3,'Vendor Booth 12');
