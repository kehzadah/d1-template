interface Env {
  DB: D1Database;
}

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, HEAD, OPTIONS",
  "access-control-allow-headers": "content-type, authorization",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), { status, headers });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ error: "method_not_allowed", message: "This API is read-only during the foundation phase." }, 405);
    }

    try {
      if (url.pathname === "/" || url.pathname === "/health") {
        const result = await env.DB.prepare("SELECT 1 AS database_connected").first<{ database_connected: number }>();
        return json({
          service: "CrystalzCrystalz Virtual Mall API",
          status: "ok",
          database: result?.database_connected === 1 ? "connected" : "unavailable",
          api_version: "v1",
        });
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
              { id: "elevator-a", name: "Elevator A", floors: [1, 2], location: "Right side / Men's Wing" },
              { id: "elevator-b", name: "Elevator B", floors: [2, 3], location: "Left side / Women's Wing" },
            ],
            transfer_rule: "Level 2 is the transfer hub; there is no direct Level 1 to Level 3 elevator.",
          },
          jewelry: {
            metals: ["gold", "silver"],
            rarity: ["common", "rare", "epic", "legendary", "mythic"],
            attachment_categories: ["wrist", "neck", "ears", "fingers"],
          },
        });
      }

      if (url.pathname === "/api/v1/floors") {
        const { results } = await env.DB.prepare(
          "SELECT floor_number, floor_name, floor_type, description FROM mall_floors ORDER BY floor_number"
        ).all();
        return json({ data: results });
      }

      if (url.pathname === "/api/v1/stores") {
        const { results } = await env.DB.prepare(
          "SELECT store_id, floor_number, gender, store_type, display_name FROM stores WHERE active = 1 ORDER BY sort_order"
        ).all();
        return json({ data: results, count: results.length });
      }

      if (url.pathname === "/api/v1/vendors") {
        const { results } = await env.DB.prepare(
          "SELECT booth_number, floor_number, booth_name, vendor_player_id, customization_json FROM vendor_booths WHERE active = 1 ORDER BY booth_number"
        ).all();
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

      return json({
        error: "not_found",
        message: "Endpoint not found.",
        available_endpoints: ["/health", "/api/v1/config", "/api/v1/floors", "/api/v1/stores", "/api/v1/vendors", "/api/v1/catalog"],
      }, 404);
    } catch (error) {
      console.error("CrystalzCrystalz API error:", error);
      return json({ error: "internal_error", message: "The request could not be completed." }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
