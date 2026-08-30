/**
 * Cal Matters — AI proxy (Cloudflare Worker).
 *
 * The AICredits key lives in the Worker secret `AICREDITS_KEY` (never in code
 * or the app). The app POSTs here; we attach the key and forward to
 * AICredits (OpenAI-compatible endpoint).
 *
 * The app sends an OpenAI-format chat-completions body (with optional
 * image_url parts for food photos). We forward it verbatim with the key.
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

    const apiKey = env.AICREDITS_KEY || "";
    if (!apiKey) {
      return json(500, { error: "Server not configured (missing AICREDITS_KEY)" });
    }

    let body;
    try {
      body = await request.json();
    } catch (e) {
      return json(400, { error: "Invalid JSON" });
    }
    if (!body || !body.messages) {
      return json(400, { error: "messages required" });
    }

    // --- Per-device daily quota (KV, optional binding) ---
    if (env.QUOTA) {
      const deviceId = (request.headers.get("x-device-id") || "unknown").slice(0, 64);
      const today = new Date().toISOString().slice(0, 10).replace(/-/g, "");
      const DAILY_LIMIT = 100;
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

    // Forward to AICredits (OpenAI-compatible)
    try {
      const upstream = await fetch("https://aicredits.in/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(body),
      });
      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: { "Content-Type": "application/json" },
      });
    } catch (e) {
      return json(502, { error: "AICredits upstream failed", detail: e.message });
    }
  },
};

function json(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
