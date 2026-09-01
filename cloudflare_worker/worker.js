/**
 * Cal Matters — AI proxy (Cloudflare Worker).
 *
 * Two upstreams, primary + backup:
 *  1. OpenCode Go  — secret `OPENCODE_KEY`  (primary, cheaper)
 *  2. AICredits    — secret `AICREDITS_KEY` (backup; used only if OpenCode
 *     errors, e.g. exhausted limit). Falls back to model `gpt-4o-mini`
 *     because AICredits may not host the OpenCode model id.
 *
 * Keys never appear in code or the app. Either secret may be absent:
 *   - missing OPENCODE_KEY      -> 500 (nothing works)
 *   - missing AICREDITS_KEY     -> no backup, error is passed through
 *
 * The app sends an OpenAI-format chat-completions body (with optional
 * image_url parts for food photos, model deepseek-v4-flash-vision-exp).
 * We forward it verbatim with the key.
 *
 * Optional per-device daily quota via KV binding `QUOTA` — if the binding
 * is absent the worker simply skips quota checks (still safe: Cloudflare
 * free tier caps requests/day per worker).
 */

const OPENCODE_UPSTREAM = "https://opencode.ai/zen/go/v1/chat/completions";
const AICREDITS_UPSTREAM = "https://aicredits.in/v1/chat/completions";

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: "Method not allowed" });
    }

    const opencodeKey = env.OPENCODE_KEY || "";
    if (!opencodeKey && !env.AICREDITS_KEY) {
      return json(500, { error: "Server not configured (missing OPENCODE_KEY)" });
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

    // --- 1. Primary: OpenCode Go ---
    try {
      const upstream = await fetch(OPENCODE_UPSTREAM, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${opencodeKey}`,
        },
        body: JSON.stringify(body),
      });
      const text = await upstream.text();
      if (upstream.status === 200) {
        return new Response(text, {
          status: upstream.status,
          headers: { "Content-Type": "application/json" },
        });
      }
      // OpenCode responded with an error (exhausted limit, 5xx, etc.)
      // -> fall through to AICredits if we have a key, else pass error.
      if (env.AICREDITS_KEY) {
        return await tryAicredits(env, body);
      }
      return new Response(text, {
        status: upstream.status,
        headers: { "Content-Type": "application/json" },
      });
    } catch (e) {
      // Network failure to OpenCode -> try AICredits if we have a key.
      if (env.AICREDITS_KEY) {
        try {
          return await tryAicredits(env, body);
        } catch (e2) {
          return json(502, { error: "Both AI providers failed", detail: e2.message });
        }
      }
      return json(502, { error: "OpenCode Go upstream failed", detail: e.message });
    }
  },
};

/** Forward to AICredits with model mapped to gpt-4o-mini (its stable id). */
async function tryAicredits(env, body) {
  const fallbackBody = JSON.parse(JSON.stringify(body));
  fallbackBody.model = "gpt-4o-mini";
  const res = await fetch(AICREDITS_UPSTREAM, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.AICREDITS_KEY}`,
    },
    body: JSON.stringify(fallbackBody),
  });
  const text = await res.text();
  return new Response(text, {
    status: res.status,
    headers: { "Content-Type": "application/json" },
  });
}

function json(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
