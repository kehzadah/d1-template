interface Env {
  DB: D1Database;
}

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "content-type, authorization",
};

const SESSION_DAYS = 30;
const PBKDF2_ITERATIONS = 310000;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), { status, headers });
}

function randomHex(bytes = 32): string {
  const data = crypto.getRandomValues(new Uint8Array(bytes));
  return Array.from(data, b => b.toString(16).padStart(2, "0")).join("");
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, c => c.charCodeAt(0));
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("");
}

async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: PBKDF2_ITERATIONS, hash: "SHA-256" },
    key,
    256
  );
  return `pbkdf2_sha256$${PBKDF2_ITERATIONS}$${bytesToBase64(salt)}$${bytesToBase64(new Uint8Array(bits))}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split("$");
  if (parts.length !== 4 || parts[0] !== "pbkdf2_sha256") return false;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations < 100000 || iterations > 1000000) return false;
  const salt = base64ToBytes(parts[2]);
  const expected = base64ToBytes(parts[3]);
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
    key,
    expected.length * 8
  );
  const actual = new Uint8Array(bits);
  if (actual.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ expected[i];
  return diff === 0;
}

function validEmail(value: unknown): value is string {
  return typeof value === "string" && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function validUsername(value: unknown): value is string {
  return typeof value === "string" && /^[a-zA-Z0-9_]{3,24}$/.test(value);
}

async function requestBody(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const value = await request.json();
    return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

async function currentPlayer(request: Request, env: Env) {
  const authorization = request.headers.get("authorization") || "";
  const match = authorization.match(/^Bearer ([A-Fa-f0-9]{64})$/);
  if (!match) return null;
  const tokenHash = await sha256(match[1]);
  return await env.DB.prepare(
    "SELECT p.player_id, p.email, p.username, p.account_status, p.created_at, pp.display_name, pp.avatar_image_key, pp.bio FROM player_sessions s JOIN players p ON p.player_id = s.player_id LEFT JOIN player_profiles pp ON pp.player_id = p.player_id WHERE s.token_hash = ? AND s.expires_at > datetime('now') AND p.account_status = 'active' LIMIT 1"
  ).bind(tokenHash).first<Record<string, unknown>>();
}

async function authRateLimited(request: Request, env: Env, email: string): Promise<boolean> {
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const fingerprint = await sha256(email.toLowerCase() + "|" + ip);
  const row = await env.DB.prepare(
    "SELECT failed_attempts, window_started_at, blocked_until FROM auth_rate_limits WHERE fingerprint = ?"
  ).bind(fingerprint).first<{ failed_attempts: number; window_started_at: number; blocked_until: number }>();
  const now = Math.floor(Date.now() / 1000);
  if (!row) return false;
  if (row.blocked_until > now) return true;
  if (now - row.window_started_at > 900) {
    await env.DB.prepare("DELETE FROM auth_rate_limits WHERE fingerprint = ?").bind(fingerprint).run();
    return false;
  }
  return false;
}

async function recordFailedLogin(request: Request, env: Env, email: string): Promise<void> {
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const fingerprint = await sha256(email.toLowerCase() + "|" + ip);
  const now = Math.floor(Date.now() / 1000);
  const row = await env.DB.prepare(
    "SELECT failed_attempts, window_started_at FROM auth_rate_limits WHERE fingerprint = ?"
  ).bind(fingerprint).first<{ failed_attempts: number; window_started_at: number }>();
  if (!row || now - row.window_started_at > 900) {
    await env.DB.prepare(
      "INSERT OR REPLACE INTO auth_rate_limits (fingerprint, failed_attempts, window_started_at, blocked_until) VALUES (?, 1, ?, 0)"
    ).bind(fingerprint, now).run();
    return;
  }
  const attempts = row.failed_attempts + 1;
  const blockedUntil = attempts >= 8 ? now + 900 : 0;
  await env.DB.prepare(
    "UPDATE auth_rate_limits SET failed_attempts = ?, blocked_until = ? WHERE fingerprint = ?"
  ).bind(attempts, blockedUntil, fingerprint).run();
}

async function clearFailedLogins(request: Request, env: Env, email: string): Promise<void> {
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const fingerprint = await sha256(email.toLowerCase() + "|" + ip);
  await env.DB.prepare("DELETE FROM auth_rate_limits WHERE fingerprint = ?").bind(fingerprint).run();
}

async function createSession(env: Env, playerId: string): Promise<string> {
  const token = randomHex(32);
  const tokenHash = await sha256(token);
  const sessionId = randomHex(16);
  await env.DB.prepare(
    "INSERT INTO player_sessions (session_id, player_id, token_hash, expires_at) VALUES (?, ?, ?, datetime('now', ?))"
  ).bind(sessionId, playerId, tokenHash, `+${SESSION_DAYS} days`).run();
  return token;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    try {
      if (url.pathname === "/" || url.pathname === "/health") {
        const result = await env.DB.prepare("SELECT 1 AS database_connected").first<{ database_connected: number }>();
        return json({ service: "CrystalzCrystalz Virtual Mall API", status: "ok", database: result?.database_connected === 1 ? "connected" : "unavailable", api_version: "v1" });
      }

      if (url.pathname === "/api/v1/auth/register" && request.method === "POST") {
        const body = await requestBody(request);
        if (!body || !validEmail(body.email) || !validUsername(body.username) || typeof body.password !== "string" || body.password.length < 12 || body.password.length > 128) {
          return json({ error: "invalid_input", message: "Provide a valid email, a username of 3–24 letters/numbers/underscores, and a password of 12–128 characters." }, 400);
        }
        const email = body.email.trim().toLowerCase();
        const username = body.username.trim();
        const existing = await env.DB.prepare("SELECT player_id FROM players WHERE email = ? COLLATE NOCASE OR username = ? COLLATE NOCASE LIMIT 1").bind(email, username).first();
        if (existing) return json({ error: "account_exists", message: "That email or username is already registered." }, 409);

        const playerId = `player_${randomHex(16)}`;
        const passwordHash = await hashPassword(body.password);
        await env.DB.batch([
          env.DB.prepare("INSERT INTO players (player_id, email, username, password_hash, account_status) VALUES (?, ?, ?, ?, 'active')").bind(playerId, email, username, passwordHash),
          env.DB.prepare("INSERT INTO player_profiles (player_id, display_name) VALUES (?, ?)").bind(playerId, username),
          env.DB.prepare("INSERT INTO wallet_accounts (player_id, balance_credits) VALUES (?, 0)").bind(playerId, 0),
        ]);
        const token = await createSession(env, playerId);
        return json({
          message: "Account created.",
          player: { player_id: playerId, email, username, account_status: "active" },
          session: { token, token_type: "Bearer", expires_in_days: SESSION_DAYS },
          security_note: "Email verification and recovery delivery must be configured before public launch.",
        }, 201);
      }

      if (url.pathname === "/api/v1/auth/login" && request.method === "POST") {
        const body = await requestBody(request);
        if (!body || !validEmail(body.email) || typeof body.password !== "string" || body.password.length > 128) {
          return json({ error: "invalid_input", message: "Provide a valid email and password." }, 400);
        }
        const email = body.email.trim().toLowerCase();
        if (await authRateLimited(request, env, email)) return json({ error: "temporarily_locked", message: "Too many failed attempts. Try again in 15 minutes." }, 429);
        const player = await env.DB.prepare("SELECT player_id, email, username, password_hash, account_status FROM players WHERE email = ? COLLATE NOCASE LIMIT 1").bind(email).first<{ player_id: string; email: string; username: string; password_hash: string | null; account_status: string }>();
        const verified = player?.password_hash ? await verifyPassword(body.password, player.password_hash) : false;
        if (!player || !verified || player.account_status !== "active") {
          await recordFailedLogin(request, env, email);
          return json({ error: "invalid_credentials", message: "Email or password is incorrect, or the account is unavailable." }, 401);
        }
        await clearFailedLogins(request, env, email);
        const token = await createSession(env, player.player_id);
        return json({ message: "Signed in.", player: { player_id: player.player_id, email: player.email, username: player.username }, session: { token, token_type: "Bearer", expires_in_days: SESSION_DAYS } });
      }

      if (url.pathname === "/api/v1/auth/me" && request.method === "GET") {
        const player = await currentPlayer(request, env);
        if (!player) return json({ error: "unauthorized", message: "A valid player session is required." }, 401);
        return json({ player });
      }

      if (url.pathname === "/api/v1/auth/logout" && request.method === "POST") {
        const authorization = request.headers.get("authorization") || "";
        const match = authorization.match(/^Bearer ([A-Fa-f0-9]{64})$/);
        if (match) {
          const tokenHash = await sha256(match[1]);
          await env.DB.prepare("DELETE FROM player_sessions WHERE token_hash = ?").bind(tokenHash).run();
        }
        return json({ message: "Signed out." });
      }

      if (request.method !== "GET" && request.method !== "HEAD") {
        return json({ error: "method_not_allowed", message: "This endpoint does not accept that method." }, 405);
      }

      if (url.pathname === "/api/v1/config") {
        return json({
          product: "CrystalzCrystalz Virtual Mall",
          api_version: "v1",
          mall: {
            floors: 3,
            branded_store_count: 8,
            independent_vendor_booth_count: 12,
            branded_stores_floor: 2,
            vendor_marketplace_floor: 3,
            elevators: [
              { id: "elevator-a", name: "Elevator A", floors: [1, 2], location: "Right side / Men's Wing", position: { x: 14.5, z: 3.4 } },
              { id: "elevator-b", name: "Elevator B", floors: [2, 3], location: "Left side / Women's Wing", position: { x: -14, z: 12 } },
            ],
            transfer_rule: "Level 2 is the transfer hub; there is no direct Level 1 to Level 3 elevator.",
          },
          jewelry: { metals: ["gold", "silver"], rarity: ["common", "rare", "epic", "legendary", "mythic"], attachment_categories: ["wrist", "neck", "ears", "fingers"] },
        });
      }

      if (url.pathname === "/api/v1/player/inventory") {
        const player = await currentPlayer(request, env);
        if (!player) return json({ error: "unauthorized", message: "A valid player session is required." }, 401);
        const { results } = await env.DB.prepare(
          "SELECT i.inventory_id, i.product_id, i.quantity, i.acquired_at, p.name, p.description, p.category, p.subcategory, p.rarity, p.metal, p.photo_key FROM inventory_items i JOIN products p ON p.product_id = i.product_id WHERE i.player_id = ? ORDER BY i.acquired_at DESC"
        ).bind(player.player_id).all();
        return json({ data: results, count: results.length });
      }

      if (url.pathname === "/api/v1/player/wallet") {
        const player = await currentPlayer(request, env);
        if (!player) return json({ error: "unauthorized", message: "A valid player session is required." }, 401);
        const wallet = await env.DB.prepare(
          "SELECT balance_credits, updated_at FROM wallet_accounts WHERE player_id = ?"
        ).bind(player.player_id).first();
        return json({ wallet: wallet || { balance_credits: 0 } });
      }

      if (url.pathname === "/api/v1/player/orders") {
        const player = await currentPlayer(request, env);
        if (!player) return json({ error: "unauthorized", message: "A valid player session is required." }, 401);
        const { results } = await env.DB.prepare(
          "SELECT order_id, status, subtotal_cents, tax_cents, total_cents, currency, created_at, updated_at FROM orders WHERE player_id = ? ORDER BY created_at DESC LIMIT 50"
        ).bind(player.player_id).all();
        return json({ data: results, count: results.length });
      }

      if (url.pathname === "/api/v1/floors") {
        const { results } = await env.DB.prepare("SELECT floor_number, floor_name, floor_type, description FROM mall_floors ORDER BY floor_number").all();
        return json({ data: results });
      }

      if (url.pathname === "/api/v1/transit") {
        const { results } = await env.DB.prepare("SELECT transit_id, elevator_name, location_description, from_floor, to_floor, x, z FROM mall_transit ORDER BY elevator_name").all();
        return json({ data: results, transfer_rule: "Level 2 is the transfer hub; there is no direct Level 1 to Level 3 elevator." });
      }

      if (url.pathname === "/api/v1/store-layouts") {
        const [zoneRows, featureRows] = await Promise.all([
          env.DB.prepare("SELECT store_id, zone_key, display_name, zone_type, sort_order FROM store_zones ORDER BY store_id, sort_order").all(),
          env.DB.prepare("SELECT store_id, feature_key, enabled FROM store_features ORDER BY store_id, feature_key").all(),
        ]);
        const layouts = new Map<string, { zones: unknown[]; features: Record<string, boolean> }>();
        for (const row of zoneRows.results as Array<{ store_id: string; zone_key: string; display_name: string; zone_type: string; sort_order: number }>) {
          if (!layouts.has(row.store_id)) layouts.set(row.store_id, { zones: [], features: {} });
          layouts.get(row.store_id)!.zones.push({ key: row.zone_key, name: row.display_name, type: row.zone_type, sort_order: row.sort_order });
        }
        for (const row of featureRows.results as Array<{ store_id: string; feature_key: string; enabled: number }>) {
          if (!layouts.has(row.store_id)) layouts.set(row.store_id, { zones: [], features: {} });
          layouts.get(row.store_id)!.features[row.feature_key] = row.enabled === 1;
        }
        return json({ data: Object.fromEntries(layouts) });
      }

      if (url.pathname === "/api/v1/stores") {
        const { results } = await env.DB.prepare("SELECT store_id, floor_number, gender, store_type, display_name FROM stores WHERE active = 1 ORDER BY sort_order").all();
        return json({ data: results, count: results.length });
      }

      if (url.pathname === "/api/v1/vendors") {
        const { results } = await env.DB.prepare("SELECT booth_number, floor_number, booth_name, vendor_player_id, customization_json FROM vendor_booths WHERE active = 1 ORDER BY booth_number").all();
        return json({ data: results, count: results.length });
      }

      if (url.pathname === "/api/v1/catalog") {
        const storeId = url.searchParams.get("store_id");
        const boothNumber = url.searchParams.get("booth_number");
        const parsedLimit = Number(url.searchParams.get("limit") || 50);
        const limit = Number.isFinite(parsedLimit) ? Math.min(Math.max(parsedLimit, 1), 100) : 50;
        if (storeId && boothNumber) return json({ error: "invalid_filter", message: "Use store_id or booth_number, not both." }, 400);
        let query = "SELECT product_id, store_id, booth_number, name, description, gender, store_type, category, subcategory, rarity, metal, photo_key, price_cents, currency FROM products WHERE active = 1";
        const values: (string | number)[] = [];
        if (storeId) { query += " AND store_id = ?"; values.push(storeId); }
        if (boothNumber) { query += " AND booth_number = ?"; values.push(Number(boothNumber)); }
        query += " ORDER BY name LIMIT ?";
        values.push(limit);
        const { results } = await env.DB.prepare(query).bind(...values).all();
        return json({ data: results, count: results.length });
      }

      return json({ error: "not_found", message: "Endpoint not found.", available_endpoints: ["/health", "/api/v1/config", "/api/v1/floors", "/api/v1/transit", "/api/v1/stores", "/api/v1/store-layouts", "/api/v1/vendors", "/api/v1/catalog", "/api/v1/auth/register", "/api/v1/auth/login", "/api/v1/auth/me", "/api/v1/auth/logout", "/api/v1/player/inventory", "/api/v1/player/wallet", "/api/v1/player/orders"] }, 404);
    } catch (error) {
      console.error("CrystalzCrystalz API error:", error);
      return json({ error: "internal_error", message: "The request could not be completed." }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
