/**
 * Cal Matters — Gemini API proxy (Cloudflare Worker).
 *
 * The Gemini key lives in the Worker secret `GEMINI_KEY` (never in code or
 * the app). The app POSTs here; we attach the key and forward to Gemini.
 *
 * Optional per-device daily quota via KV binding `QUOTA` — if the binding
 * is absent the worker simply skips quota checks (still safe: Cloudflare
 * free tier caps requests/day per worker).
 */

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: "Method not allowed" });
    }

    const apiKey = env.GEMINI_KEY || "";
    if (!apiKey) {
      return json(500, { error: "Server not configured (missing GEMINI_KEY)" });
    }

    let body;
    try {
      body = await request.json();
    } catch (e) {
      return json(400, { error: "Invalid JSON" });
    }
    if (!body || !body.contents) {
      return json(400, { error: "contents required" });
    }
    const model = String(body.model || "gemini-3.6-flash").replace(/[^a-zA-Z0-9_.-]/g, "");

    // --- Per-device daily quota (KV, optional binding) ---
    if (env.QUOTA) {
      const deviceId = (request.headers.get("x-device-id") || "unknown").slice(0, 64);
      const today = new Date().toISOString().slice(0, 10).replace(/-/g, "");
      const DAILY_LIMIT = 200;
      const qKey = `quota_${deviceId}_${today}`;
      try {
        const used = parseInt((await env.QUOTA.get(qKey)) || "0", 10) || 0;
        if (used >= DAILY_LIMIT) {
          return json(429, { error: "Daily limit reached", limit: DAILY_LIMIT });
        }
        await env.QUOTA.put(qKey, String(used + 1), { expirationTtl: 86400 * 2 });
      } catch (e) {
        // Quota tracking is best-effort — never break the product.
      }
    }

    // Forward to Gemini
    try {
      const upstream = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        }
      );
      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: { "Content-Type": "application/json" },
      });
    } catch (e) {
      return json(502, { error: "Gemini upstream failed", detail: e.message });
    }
  },
};

function json(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
