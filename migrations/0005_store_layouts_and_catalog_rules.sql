-- Store layouts and category constraints from the approved retail specification.
CREATE TABLE IF NOT EXISTS store_zones (
  zone_id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL REFERENCES stores(store_id) ON DELETE CASCADE,
  zone_key TEXT NOT NULL,
  display_name TEXT NOT NULL,
  zone_type TEXT NOT NULL CHECK (zone_type IN ('clothing_style','fitting_room','eyewear_category','jewelry_category')),
  sort_order INTEGER NOT NULL,
  UNIQUE (store_id, zone_key)
);

CREATE TABLE IF NOT EXISTS store_features (
  store_id TEXT NOT NULL REFERENCES stores(store_id) ON DELETE CASCADE,
  feature_key TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
  PRIMARY KEY (store_id, feature_key)
);

-- Both clothing stores have the four approved style zones and fitting rooms.
INSERT OR IGNORE INTO store_zones VALUES
 ('men-clothes-streetwear','men-clothes','streetwear','Streetwear','clothing_style',1),
 ('men-clothes-luxury','men-clothes','luxury','Luxury','clothing_style',2),
 ('men-clothes-casual','men-clothes','casual','Casual','clothing_style',3),
 ('men-clothes-glam','men-clothes','glam','Glam','clothing_style',4),
 ('men-clothes-fitting','men-clothes','fitting-rooms','Fitting Rooms','fitting_room',5),
 ('women-clothes-streetwear','women-clothes','streetwear','Streetwear','clothing_style',1),
 ('women-clothes-luxury','women-clothes','luxury','Luxury','clothing_style',2),
 ('women-clothes-casual','women-clothes','casual','Casual','clothing_style',3),
 ('women-clothes-glam','women-clothes','glam','Glam','clothing_style',4),
 ('women-clothes-fitting','women-clothes','fitting-rooms','Fitting Rooms','fitting_room',5);

-- Eyewear stores have no fitting rooms.
INSERT OR IGNORE INTO store_zones VALUES
 ('men-eyewear-sunglasses','men-eyewear','sunglasses','Sunglasses','eyewear_category',1),
 ('men-eyewear-glasses','men-eyewear','glasses','Glasses','eyewear_category',2),
 ('women-eyewear-sunglasses','women-eyewear','sunglasses','Sunglasses','eyewear_category',1),
 ('women-eyewear-glasses','women-eyewear','glasses','Glasses','eyewear_category',2);

-- Luxury jewelry: watches allowed.
INSERT OR IGNORE INTO store_zones VALUES
 ('men-luxury-rings','men-luxury-jewelry','rings','Rings','jewelry_category',1),
 ('men-luxury-necklaces','men-luxury-jewelry','necklaces','Necklaces','jewelry_category',2),
 ('men-luxury-earrings','men-luxury-jewelry','earrings','Earrings','jewelry_category',3),
 ('men-luxury-bracelets','men-luxury-jewelry','bracelets','Bracelets','jewelry_category',4),
 ('men-luxury-watches','men-luxury-jewelry','watches','Watches','jewelry_category',5),
 ('women-luxury-rings','women-luxury-jewelry','rings','Rings','jewelry_category',1),
 ('women-luxury-necklaces','women-luxury-jewelry','necklaces','Necklaces','jewelry_category',2),
 ('women-luxury-earrings','women-luxury-jewelry','earrings','Earrings','jewelry_category',3),
 ('women-luxury-bracelets','women-luxury-jewelry','bracelets','Bracelets','jewelry_category',4),
 ('women-luxury-watches','women-luxury-jewelry','watches','Watches','jewelry_category',5);

-- Handcrafted jewelry: no watches; men's earrings are studs only.
INSERT OR IGNORE INTO store_zones VALUES
 ('men-handcrafted-rings','men-handcrafted-jewelry','rings','Rings','jewelry_category',1),
 ('men-handcrafted-necklaces','men-handcrafted-jewelry','necklaces','Necklaces','jewelry_category',2),
 ('men-handcrafted-studs','men-handcrafted-jewelry','earrings-studs','Earrings (Studs Only)','jewelry_category',3),
 ('men-handcrafted-bracelets','men-handcrafted-jewelry','bracelets','Bracelets','jewelry_category',4),
 ('women-handcrafted-rings','women-handcrafted-jewelry','rings','Rings','jewelry_category',1),
 ('women-handcrafted-necklaces','women-handcrafted-jewelry','necklaces','Necklaces','jewelry_category',2),
 ('women-handcrafted-earrings','women-handcrafted-jewelry','earrings','Earrings','jewelry_category',3),
 ('women-handcrafted-bracelets','women-handcrafted-jewelry','bracelets','Bracelets','jewelry_category',4);

INSERT OR IGNORE INTO store_features (store_id, feature_key, enabled) VALUES
 ('men-clothes','fitting_rooms',1),('women-clothes','fitting_rooms',1),
 ('men-eyewear','fitting_rooms',0),('women-eyewear','fitting_rooms',0);
