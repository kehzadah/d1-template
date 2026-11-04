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
- `GET /api/v1/stores` — eight branded retail stores
- `GET /api/v1/vendors` — twelve Level 3 vendor booths
- `GET /api/v1/catalog` — active product catalog; optional `store_id`, `booth_number`, and `limit` query parameters

The API is intentionally read-only at this foundation stage. Account creation, authentication, inventory mutations, purchases, wallet changes, and payment webhooks must be implemented with server-side authorization and transaction controls before they are exposed.

## Database

- `0001_create_comments_table.sql` is the original template migration and is retained.
- `0002_crystalzcrystalz_foundation.sql` adds the CrystalzCrystalz schema and seeds the mall floors, eight stores, twelve vendor booths, and elevator connections.

Core tables include players, player_profiles, avatars, stores, vendor_booths, products, inventory_items, shopping_carts, cart_items, orders, order_items, wallet_accounts, wallet_ledger, payment_records, audit_events, mall_floors, and mall_transit.

## Deployment

The Worker is configured in `wrangler.json` and uses the existing D1 binding `DB`. Cloudflare's connected Git deployment should run the configured deploy command and apply pending migrations before publishing the Worker.

Do not create a second database or replace the D1 binding unless the database is intentionally being migrated.
