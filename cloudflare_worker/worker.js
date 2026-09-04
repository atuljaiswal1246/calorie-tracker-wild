/**
 * Cal Matters — AI proxy (Cloudflare Worker).
 *
 * Four upstreams, in order (first success wins):
 *   1. OpenCode Zen (free)  — secret `ZEN_KEY`          — model `mimo-v2.5-free`
 *   2. OpenCode Go (paid)   — secret `OPENCODE_KEY`     — model `mimo-v2.5`
 *   3. AICredits            — secret `AICREDITS_KEY`    — model `gpt-4o-mini`
 *   4. OpenRouter           — secret `OPENROUTER_KEY`   — model `gpt-4o-mini`
 *
 * Free-tier lifecycle (KV):
 *   - `free_started_at` (epoch ms) written on first successful free call.
 *   - If the free tier is used longer than 10 days it is auto-disabled
 *     (free tier models get retired by the provider, so don't rely on it
 *     forever). Disabled means tier 1 is skipped until a human intervenes.
 *   - 404/401/403 from the free tier (model removed / auth broken) disables
 *     it permanently — that is the "provider retired the model" case.
 *   - 429/5xx/network errors are treated as transient: we fall through to
 *     tier 2 for that request and put the free tier in a 30-minute cooldown
 *     (`free_cooldown_until`), so a rate-limited free endpoint is not
 *     hammered but is retried automatically once it recovers.
 *   - Manual re-enable: delete KV keys `free_disabled` and `free_started_at`
 *     (and `free_cooldown_until`) in the Cloudflare dashboard. The 10-day
 *     clock restarts on the next successful free call.
 *
 * Optional Telegram alerting: if secrets `TELEGRAM_BOT_TOKEN` and
 * `TELEGRAM_CHAT_ID` are present, free-tier failures/expiry send a message
 * (throttled to 1/hour via KV `last_free_alert_ts`). Without them this is a
 * no-op — nothing is sent.
 *
 * Any secret may be absent:
 *   - missing ZEN_KEY           -> tier 1 skipped, tier 2 becomes primary
 *   - missing OPENCODE_KEY      -> tier 2 skipped
 *   - missing AICREDITS_KEY     -> tier 3 skipped
 *   - missing OPENROUTER_KEY    -> tier 4 skipped
 *   - all missing               -> 500
 *
 * Per-device daily quota via KV binding `QUOTA` (optional binding — if
 * absent, quota checks are skipped).
 */

const ZEN_UPSTREAM = "https://opencode.ai/zen/v1/chat/completions";
const GO_UPSTREAM = "https://opencode.ai/zen/go/v1/chat/completions";
const AICREDITS_UPSTREAM = "https://aicredits.in/v1/chat/completions";
const OPENROUTER_UPSTREAM = "https://openrouter.ai/api/v1/chat/completions";

const FREE_MODEL = "mimo-v2.5-free";
const PAID_MODEL = "mimo-v2.5";
const FALLBACK_MODEL = "gpt-4o-mini";
const FREE_TTL_DAYS = 10;
const DAILY_LIMIT = 100;

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: "Method not allowed" });
    }

    const hasAny =
      env.ZEN_KEY || env.OPENCODE_KEY || env.AICREDITS_KEY || env.OPENROUTER_KEY;
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

    // --- Decide whether the free tier is viable ---
    let tryFree = false;
    try {
      const disabled = await env.QUOTA?.get("free_disabled");
      if (!disabled) {
        const started = await env.QUOTA?.get("free_started_at");
        if (started) {
          const ageMs = Date.now() - parseInt(started, 10);
          if (ageMs > FREE_TTL_DAYS * 86400000) {
            // Auto-expire: free tier used long enough, retire it.
            await env.QUOTA?.put("free_disabled", "expired", { expirationTtl: 86400 * 30 });
            await notify(env, `🕐 Free model expired after ${FREE_TTL_DAYS} days. Switched to Go (${PAID_MODEL}). Re-enable manually via KV if needed.`);
            tryFree = false;
          } else {
            // Transient cooldown? 429/5xx recently — wait it out.
            const cooldown = parseInt((await env.QUOTA?.get("free_cooldown_until")) || "0", 10) || 0;
            tryFree = Date.now() >= cooldown;
          }
        } else {
          tryFree = true; // first time — allow, clock set below on success
        }
      }
    } catch (e) {
      // No KV binding / read failure — conservatively skip free tier.
      tryFree = false;
    }

    // --- Tier 1: Zen free ---
    if (tryFree && env.ZEN_KEY) {
      const res = await tryUpstream(ZEN_UPSTREAM, env.ZEN_KEY, FREE_MODEL, body);
      if (res) {
        try {
          await env.QUOTA?.put("free_started_at", String(Date.now()), { expirationTtl: 86400 * 40 });
        } catch (e) {}
        return res;
      }
      // Free tier failed. Distinguish permanent (model gone) from transient.
      const permanent = await isPermanentFreeFailure(ZEN_UPSTREAM, env.ZEN_KEY, FREE_MODEL, body);
      if (permanent) {
        // 404/401/403 — the free model is gone for good; retire it.
        try {
          await env.QUOTA?.put("free_disabled", "failed", { expirationTtl: 86400 * 30 });
        } catch (e) {}
        await notify(env, `⚠️ Free model (${FREE_MODEL}) permanently failed (404/auth). Switched to Go (${PAID_MODEL}).`);
      } else {
        // Transient (429/5xx) — cooldown 30 min, retry later.
        try {
          await env.QUOTA?.put("free_cooldown_until", String(Date.now() + 1800000), { expirationTtl: 86400 * 2 });
        } catch (e) {}
        await notify(env, `⚠️ Free model (${FREE_MODEL}) rate-limited/failed. Using Go (${PAID_MODEL}) for now; will retry free in ~30 min.`);
      }
    }

    // --- Tier 2: OpenCode Go (paid) ---
    if (env.OPENCODE_KEY) {
      const res = await tryUpstream(GO_UPSTREAM, env.OPENCODE_KEY, PAID_MODEL, body);
      if (res) return res;
    }

    // --- Tier 3: AICredits ---
    if (env.AICREDITS_KEY) {
      const res = await tryUpstream(AICREDITS_UPSTREAM, env.AICREDITS_KEY, FALLBACK_MODEL, body);
      if (res) return res;
    }

    // --- Tier 4: OpenRouter ---
    if (env.OPENROUTER_KEY) {
      const res = await tryUpstream(OPENROUTER_UPSTREAM, env.OPENROUTER_KEY, FALLBACK_MODEL, body);
      if (res) return res;
    }

    return json(502, { error: "All AI providers failed" });
  },
};

/**
 * Returns true when the free-tier failure is permanent (model removed,
 * auth/key broken) vs transient (rate limit, 5xx, network).
 * Performs one lightweight probe: 404/401/403 => permanent.
 */
async function isPermanentFreeFailure(url, key, model, body) {
  try {
    const probeBody = JSON.parse(JSON.stringify(body));
    probeBody.model = model;
    probeBody.max_tokens = 5;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify(probeBody),
    });
    return [401, 403, 404].includes(res.status);
  } catch (e) {
    return false; // network issue — treat as transient
  }
}

/**
 * Forward `body` to upstream with the given model id.
 * Returns the upstream Response on HTTP 200, or null on ANY other status
 * (or network/serialisation failure). 404/401/429/5xx all count as failure
 * so the caller can fall through to the next tier.
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
    // Drain text once — we reuse it for responses or fail-fast logging.
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
    const last = parseInt((await env.QUOTA?.get("last_free_alert_ts")) || "0", 10) || 0;
    const now = Date.now();
    if (now - last < 3600000) return; // throttle: max 1/hour
    await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: env.TELEGRAM_CHAT_ID,
        text: `${message}\nTime: ${new Date().toISOString()}`,
      }),
    });
    await env.QUOTA?.put("last_free_alert_ts", String(now), { expirationTtl: 86400 * 2 });
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
