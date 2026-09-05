/**
 * Cal Matters — AI proxy (Cloudflare Worker).
 *
 * Three upstreams, tried in order (first success wins):
 *   1. AICredits            — secret `AICREDITS_KEY`    — model `gpt-4o-mini`
 *   2. OpenCode Zen (free)  — secret `ZEN_KEY`          — model `mimo-v2.5-free`
 *   3. OpenRouter           — secret `OPENROUTER_KEY`   — model `gpt-4o-mini`
 *
 * Circuit breaker:
 *   Each provider has a consecutive-failure counter in KV. After
 *   `FAIL_THRESHOLD` (5) consecutive failures it is suspended for a cooldown
 *   (`COOLDOWN_MS` = 30 min) and skipped in the rotation, then auto-resumed.
 *   A single success resets the counter.
 *
 *   KV keys: `cb_<provider>` -> JSON { "fails": n, "until": epochMs }
 *   Providers: aicredits, zen, openrouter.
 *
 * Optional Telegram alerting: if secrets `TELEGRAM_BOT_TOKEN` and
 * `TELEGRAM_CHAT_ID` are present, a provider being suspended sends a message
 * (throttled to 1/hour). Without them this is a no-op.
 *
 * Any secret may be absent:
 *   - missing AICREDITS_KEY    -> tier 1 skipped
 *   - missing ZEN_KEY          -> tier 2 skipped
 *   - missing OPENROUTER_KEY   -> tier 3 skipped
 *   - all missing              -> 500
 *
 * Per-device daily quota via KV binding `QUOTA` (optional binding — if
 * absent, quota checks are skipped).
 */

const AICREDITS_UPSTREAM = "https://aicredits.in/v1/chat/completions";
const ZEN_UPSTREAM = "https://opencode.ai/zen/v1/chat/completions";
const OPENROUTER_UPSTREAM = "https://openrouter.ai/api/v1/chat/completions";

const FALLBACK_MODEL = "gpt-4o-mini";
const FREE_MODEL = "mimo-v2.5-free";

const FAIL_THRESHOLD = 5;
const COOLDOWN_MS = 30 * 60 * 1000; // 30 minutes
const DAILY_LIMIT = 100;

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: "Method not allowed" });
    }

    const hasAny =
      env.AICREDITS_KEY || env.ZEN_KEY || env.OPENROUTER_KEY;
    if (!hasAny) {
      return json(500, { error: "Server not configured (no API keys)" });
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

    // Ordered rotation. A provider is skipped if its circuit breaker is open
    // (currently suspended). Each entry is [provider, upstream, key, model].
    const rotation = [
      ["aicredits", AICREDITS_UPSTREAM, env.AICREDITS_KEY, FALLBACK_MODEL],
      ["zen", ZEN_UPSTREAM, env.ZEN_KEY, FREE_MODEL],
      ["openrouter", OPENROUTER_UPSTREAM, env.OPENROUTER_KEY, FALLBACK_MODEL],
    ];

    for (const [provider, url, key, model] of rotation) {
      if (!key) continue;
      if (await isSuspended(env, provider)) continue;

      const res = await tryUpstream(url, key, model, body);
      if (res) {
        await resetBreaker(env, provider);
        return res;
      }
      await countFailure(env, provider);
    }

    return json(502, { error: "All AI providers failed" });
  },
};

/** True when the provider's circuit breaker is open (in cooldown). */
async function isSuspended(env, provider) {
  if (!env.QUOTA) return false;
  try {
    const raw = await env.QUOTA.get(`cb_${provider}`);
    if (!raw) return false;
    const { until } = JSON.parse(raw);
    return Date.now() < until;
  } catch (e) {
    return false;
  }
}

/** Record a failure; suspend the provider once threshold is reached. */
async function countFailure(env, provider) {
  if (!env.QUOTA) return;
  try {
    const raw = await env.QUOTA.get(`cb_${provider}`);
    let fails = raw ? (JSON.parse(raw).fails || 0) : 0;
    fails += 1;
    if (fails >= FAIL_THRESHOLD) {
      const until = Date.now() + COOLDOWN_MS;
      await env.QUOTA.put(`cb_${provider}`, JSON.stringify({ fails: 0, until }), {
        expirationTtl: 86400 * 2,
      });
      await notify(env, `AI provider "${provider}" failed ${FAIL_THRESHOLD}x — suspended for ${COOLDOWN_MS / 60000} min.`);
    } else {
      await env.QUOTA.put(`cb_${provider}`, JSON.stringify({ fails, until: 0 }), {
        expirationTtl: 86400 * 2,
      });
    }
  } catch (e) {
    // Circuit tracking is best-effort.
  }
}

/** A success clears the breaker counter. */
async function resetBreaker(env, provider) {
  if (!env.QUOTA) return;
  try {
    await env.QUOTA.put(`cb_${provider}`, JSON.stringify({ fails: 0, until: 0 }), {
      expirationTtl: 86400 * 2,
    });
  } catch (e) {
    // best-effort
  }
}

/**
 * Forward `body` to upstream with the given model id.
 * Returns the upstream Response on HTTP 200, or null on ANY other status
 * (or network/serialisation failure). 404/401/429/5xx all count as failure.
 */
async function tryUpstream(url, key, model, body) {
  const upstreamBody = JSON.parse(JSON.stringify(body));
  upstreamBody.model = model;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify(upstreamBody),
    });
    if (res.status !== 200) return null;
    const text = await res.text();
    return new Response(text, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return null;
  }
}

/**
 * Optional Telegram alert, throttled to one message per hour.
 * No-op when TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID are missing.
 */
async function notify(env, message) {
  if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) return;
  try {
    const last = parseInt((await env.QUOTA?.get("last_alert_ts")) || "0", 10) || 0;
    const now = Date.now();
    if (now - last < 3600000) return;
    await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: env.TELEGRAM_CHAT_ID,
        text: `${message}\nTime: ${new Date().toISOString()}`,
      }),
    });
    await env.QUOTA?.put("last_alert_ts", String(now), { expirationTtl: 86400 * 2 });
  } catch (e) {
    // Alerting is best-effort — never break the product.
  }
}

function json(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
