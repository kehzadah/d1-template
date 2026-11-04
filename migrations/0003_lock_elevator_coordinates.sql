-- Preserve the approved physical elevator locations in the mall data.
ALTER TABLE mall_transit ADD COLUMN x REAL;
ALTER TABLE mall_transit ADD COLUMN z REAL;

UPDATE mall_transit SET x = 14.5, z = 3.4 WHERE transit_id = 'elevator-a';
UPDATE mall_transit SET x = -14.0, z = 12.0 WHERE transit_id = 'elevator-b';
