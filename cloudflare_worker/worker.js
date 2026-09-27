/**
 * Cal Matters — AI proxy (Cloudflare Worker).
 *
 * Three upstreams, tried in order (first success wins):
 *   1. OpenCode Go (paid)   — secret `OPENCODE_KEY`     — model `mimo-v2.5`
 *   2. AICredits            — secret `AICREDITS_KEY`    — model `gpt-4o-mini`
 *   3. OpenRouter           — secret `OPENROUTER_KEY`   — model `gpt-4o-mini`
 *
 * Circuit breaker:
 *   Each provider has a consecutive-failure counter in KV. After
 *   `FAIL_THRESHOLD` (5) consecutive failures it is suspended for a cooldown
 *   (`COOLDOWN_MS` = 30 min) and skipped in the rotation, then auto-resumed.
 *   A single success resets the counter.
 *
 *   KV keys: `cb_<provider>` -> JSON { "fails": n, "until": epochMs }
 *   Providers: go, aicredits, openrouter.
 *
 * Optional Telegram alerting: if secrets `TELEGRAM_BOT_TOKEN` and
 * `TELEGRAM_CHAT_ID` are present, a provider being suspended sends a message
 * (throttled to 1/hour). Without them this is a no-op.
 *
 * Any secret may be absent:
 *   - missing OPENCODE_KEY     -> tier 1 skipped
 *   - missing AICREDITS_KEY    -> tier 2 skipped
 *   - missing OPENROUTER_KEY   -> tier 3 skipped
 *   - all missing              -> 500
 *
 * Per-device daily quota via KV binding `QUOTA` (optional binding — if
 * absent, quota checks are skipped).
 */

const AICREDITS_UPSTREAM = "https://aicredits.in/v1/chat/completions";
const GO_UPSTREAM = "https://opencode.ai/zen/go/v1/chat/completions";
const OPENROUTER_UPSTREAM = "https://openrouter.ai/api/v1/chat/completions";

const BEST_MODEL = "mimo-v2.5";
const FALLBACK_MODEL = "gpt-4o-mini";

// 3, not 5: a dead provider costs every single request a doomed round-trip
// before it is skipped, so it must be suspended quickly.
const FAIL_THRESHOLD = 3;
const COOLDOWN_MS = 30 * 60 * 1000; // 30 minutes
const DAILY_LIMIT = 100;

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: "Method not allowed" });
    }

    const hasAny =
      env.AICREDITS_KEY || env.OPENCODE_KEY || env.OPENROUTER_KEY;
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
    //
    // `go` is LAST on purpose. Measured 2026-09-27: from a Cloudflare Worker
    // (datacenter IP) OpenCode Go answers 429 every time — the abuse filter
    // that KB-06 warns about. Putting it first cost every scan a doomed
    // round-trip of extra latency. It stays in the rotation so it resumes
    // automatically if/when Go accepts Worker traffic again; its cheap
    // $0.14/$0.28 per 1M pricing means it should be promoted the moment it
    // works, since it beats the paid fallback.
    const rotation = [
      ["aicredits", AICREDITS_UPSTREAM, env.AICREDITS_KEY, FALLBACK_MODEL],
      ["openrouter", OPENROUTER_UPSTREAM, env.OPENROUTER_KEY, FALLBACK_MODEL],
      ["go", GO_UPSTREAM, env.OPENCODE_KEY, BEST_MODEL],
    ];

    // OpenCode Go REQUIRES a stable `x-opencode-session` and an identifying
    // User-Agent (https://opencode.ai/docs/go/#where-can-i-use-it). Without
    // them it answers 400 MissingSessionID, the tier dies silently, and every
    // scan falls through to a PAID fallback. Session = the caller's own
    // session id when it sends one, else the stable per-install device id.
    const goHeaders = {
      "x-opencode-session":
        (request.headers.get("x-opencode-session") || "").trim() ||
        (request.headers.get("x-device-id") || "").trim() ||
        "cal-matters-anonymous",
      "User-Agent": "cal-matters-proxy/1.0",
    };

    // Every tier's outcome for this request, so a downgrade is never silent.
    const tiers = [];
    for (const [provider, url, key, model] of rotation) {
      if (!key) {
        tiers.push(`${provider}:nokey`);
        continue;
      }
      if (await isSuspended(env, provider)) {
        tiers.push(`${provider}:suspended`);
        continue;
      }

      const res = await tryUpstream(
        url,
        key,
        model,
        body,
        provider === "go" ? goHeaders : null,
      );
      if (res.ok) {
        await resetBreaker(env, provider);
        // Tell the truth about who actually answered. The app used to be
        // silently downgraded to a weaker model with nothing in the logs.
        const headers = new Headers(res.response.headers);
        headers.set("x-cm-provider", provider);
        headers.set("x-cm-requested-model", model);
        headers.set("x-cm-served-model", res.servedModel || "unknown");
        headers.set("x-cm-tiers", tiers.concat(`${provider}:ok`).join(" "));
        // Which tiers actually hold a non-empty key. A secret that exists by
        // NAME but is blank is skipped in silence and looks like a healthy
        // fallback — this header is how that stops being invisible.
        headers.set(
          "x-cm-keys",
          [
            ["go", env.OPENCODE_KEY],
            ["aicredits", env.AICREDITS_KEY],
            ["openrouter", env.OPENROUTER_KEY],
          ]
            .filter(([, k]) => Boolean(k) && String(k).trim().length > 0)
            .map(([n]) => n)
            .join(",") || "none",
        );
        return new Response(res.response.body, {
          status: 200,
          headers,
        });
      }
      // Record WHY it failed — the old code swallowed the status entirely,
      // which is how a dead provider stayed invisible.
      tiers.push(`${provider}:${res.status}`);
      await recordFailure(env, provider, res.status, res.detail);
      await countFailure(env, provider);
    }

    return json(502, {
      error: "All AI providers failed",
      tiers: tiers.join(" "),
    });
  },
};

/**
 * Persist the real reason an upstream refused, so a failure is diagnosable
 * instead of silent. Never stores the key or the request body.
 * KV key: `err_<provider>` -> { status, detail, at }
 */
async function recordFailure(env, provider, status, detail) {
  if (!env.QUOTA) return;
  try {
    await env.QUOTA.put(
      `err_${provider}`,
      JSON.stringify({
        status: status ?? 0,
        detail: String(detail || "").slice(0, 180),
        at: Date.now(),
      }),
      { expirationTtl: 86400 * 7 },
    );
  } catch (e) {
    // Diagnostics are best-effort — never break the product.
  }
}

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

/** A success clears the breaker counter and any stored failure reason. */
async function resetBreaker(env, provider) {
  if (!env.QUOTA) return;
  try {
    await env.QUOTA.put(`cb_${provider}`, JSON.stringify({ fails: 0, until: 0 }), {
      expirationTtl: 86400 * 2,
    });
    await env.QUOTA.delete(`err_${provider}`);
  } catch (e) {
    // best-effort
  }
}

/**
 * Forward `body` to upstream with the given model id.
 * Returns {ok:true, response, servedModel} on HTTP 200, otherwise
 * {ok:false, status, detail} — 404/401/429/5xx and network errors all count
 * as failure, and the reason is handed back so it can be recorded.
 */
async function tryUpstream(url, key, model, body, extraHeaders) {
  const upstreamBody = JSON.parse(JSON.stringify(body));
  upstreamBody.model = model;
  const headers = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${key}`,
  };
  if (extraHeaders) Object.assign(headers, extraHeaders);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(upstreamBody),
    });
    if (res.status !== 200) {
      let detail = "";
      try {
        detail = (await res.text()).slice(0, 180);
      } catch (e) {
        detail = "(body unreadable)";
      }
      return { ok: false, status: res.status, detail };
    }
    const text = await res.text();
    // The upstream may answer with a different model than we asked for
    // (a silent downgrade). Read it back so the caller can report it.
    let servedModel = "";
    try {
      servedModel = JSON.parse(text).model || "";
    } catch (e) {
      // not JSON — leave blank
    }
    return {
      ok: true,
      response: new Response(text, {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
      servedModel,
    };
  } catch (e) {
    return { ok: false, status: 0, detail: String(e && e.message) || "network" };
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
