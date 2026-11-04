# CrystalzCrystalz Virtual Mall API

Cloudflare Worker + D1 foundation for the CrystalzCrystalz Unity virtual mall.

## Current architecture

- Cloudflare Worker: API runtime
- Cloudflare D1: relational application database
- Unity: 3D mall client (separate project; not included in this repository)

## Deployed API routes

- `GET /health` — Worker and D1 health check
- `GET /api/v1/config` — locked mall configuration
- `GET /api/v1/floors` — three mall floors
- `GET /api/v1/transit` — elevator connections and approved coordinates
- `GET /api/v1/stores` — eight branded retail stores
- `GET /api/v1/store-layouts` — approved zones, fitting-room features, and category layouts
- `GET /api/v1/vendors` — twelve Level 3 vendor booths
- `GET /api/v1/catalog` — active product catalog; optional `store_id`, `booth_number`, and `limit` query parameters

## Player authentication

- `POST /api/v1/auth/register` — create a player account (email, username, password)
- `POST /api/v1/auth/login` — sign in and receive a bearer session token
- `GET /api/v1/auth/me` — validate the current session and read the player profile
- `POST /api/v1/auth/logout` — revoke the current bearer session
- `GET /api/v1/player/inventory` — read the signed-in player's inventory
- `GET /api/v1/player/wallet` — read the signed-in player's credit balance
- `GET /api/v1/player/orders` — read the signed-in player's recent orders

## Mall administration (admin role required)

- `GET /api/v1/admin/overview` — account, vendor booth, catalog, order, and pending-payment counts
- `GET /api/v1/admin/players` — recent player accounts and assigned roles; optional `limit` (1–100)
- `GET /api/v1/admin/vendors` — all vendor booth assignments and activation states

Admin routes require a valid bearer session and the `admin` role. New accounts receive only the `player` role automatically; there is no public role-escalation endpoint. To provision the first administrator, register the intended account, then run this SQL in the connected D1 database console (replace the email with the exact account email):

```sql
INSERT OR IGNORE INTO player_roles (player_id, role_key, assigned_by)
SELECT player_id, 'admin', 'manual-d1-provisioning'
FROM players
WHERE email = 'admin@example.com';
```

This grants administrator access to that account. Keep the account credentials private and assign the role only to a trusted operator.

Passwords are stored as PBKDF2-SHA-256 hashes (310,000 iterations with a random salt). Session tokens are random and only their SHA-256 hashes are stored. Login attempts are rate-limited by a hashed email/IP fingerprint.

Registration currently activates an account immediately. Email verification, password reset delivery, email verification, password reset delivery, and production abuse monitoring are not yet configured. Do not open public registration broadly until those controls are implemented.

Inventory, purchases, wallet changes, vendor edits, and payment webhooks remain unavailable for writes. The role tables and admin audit log are in place, but management write actions still require transactional authorization and audit controls before they are enabled.

## Database

- `0001_create_comments_table.sql` is the original template migration and is retained.
- `0002_crystalzcrystalz_foundation.sql` adds the core CrystalzCrystalz schema and seeds the mall floors, eight stores, twelve vendor booths, and elevator connections.
- `0003_lock_elevator_coordinates.sql` records the approved elevator coordinates.
- `0004_player_authentication.sql` adds password/session and login-rate-limit storage.
- `0005_store_layouts_and_catalog_rules.sql` adds store zones and fitting-room/category rules.
- `0006_roles_and_admin_audit.sql` adds player/vendor/moderator/admin roles and an admin audit log.

Store layout data preserves the clothing zones (Streetwear, Luxury, Casual, Glam, fitting rooms), eyewear categories (no fitting rooms), men's handcrafted jewelry restrictions (stud earrings only and no watches), and the approved luxury jewelry categories. Core tables include players, player_profiles, avatars, stores, vendor_booths, store_zones, store_features, products, inventory_items, shopping_carts, cart_items, orders, order_items, wallet_accounts, wallet_ledger, payment_records, audit_events, mall_floors, mall_transit, player_sessions, auth_rate_limits, roles, player_roles, and admin_audit_log.

## Deployment

The Worker is configured in `wrangler.json` and uses the existing D1 binding `DB`. Cloudflare's connected Git deployment should run the configured deploy command and apply pending migrations before publishing the Worker.

Do not create a second database or replace the D1 binding unless the database is intentionally being migrated.
