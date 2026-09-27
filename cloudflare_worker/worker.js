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
const ZEN_UPSTREAM = "https://opencode.ai/zen/v1/chat/completions";
const OPENROUTER_UPSTREAM = "https://openrouter.ai/api/v1/chat/completions";

const BEST_MODEL = "mimo-v2.5";
const FALLBACK_MODEL = "gpt-4o-mini";

// 3, not 5: a dead provider costs every single request a doomed round-trip
// before it is skipped, so it must be suspended quickly.
const FAIL_THRESHOLD = 3;
const COOLDOWN_MS = 30 * 60 * 1000; // 30 minutes
const DAILY_LIMIT = 100;

/** Headers OpenCode requires: a stable session id and an identifying UA. */
function goProbeHeaders(request) {
  return {
    "x-opencode-session":
      (request.headers.get("x-opencode-session") || "").trim() ||
      (request.headers.get("x-device-id") || "").trim() ||
      "cal-matters-anonymous",
    "User-Agent": "cal-matters-proxy/1.0",
  };
}

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: "Method not allowed" });
    }

    // ---- Diagnostic: which secret can actually serve a given model? ----
    // Answers with the secret's NAME and an HTTP status only. A key value is
    // never read back, logged or returned, and the probe cannot be used to
    // obtain one: it makes one real call per configured provider and reports
    // what the upstream said. Guessing which key serves a model is how we end
    // up billing the wrong account, so this is measured instead.
    const probeModel = (request.headers.get("x-cm-probe-model") || "").trim();
    if (probeModel) {
      const candidates = [
        ["go", GO_UPSTREAM, env.OPENCODE_KEY],
        ["zen", ZEN_UPSTREAM, env.ZEN_KEY],
        ["openrouter", OPENROUTER_UPSTREAM, env.OPENROUTER_KEY],
        ["aicredits", AICREDITS_UPSTREAM, env.AICREDITS_KEY],
      ];
      const results = [];
      for (const [name, url, key] of candidates) {
        if (!key) {
          results.push({ secret: name, status: "no-key-configured" });
          continue;
        }
        const extra =
          name === "go"
            ? goProbeHeaders(request)
            : { "User-Agent": "cal-matters-proxy/1.0" };
        const outcome = await tryUpstream(
          url, key, probeModel,
          {
            model: probeModel,
            messages: [{ role: "user", content: "Say ok" }],
            max_tokens: 5,
          },
          extra,
        );
        results.push(
          outcome.ok
            ? {
                secret: name,
                status: 200,
                can_serve_model: true,
                served_model: outcome.servedModel || "unknown",
              }
            : {
                secret: name,
                status: outcome.status,
                can_serve_model: false,
                // A short, non-sensitive excerpt: model ids and limit names.
                reason: String(outcome.detail || "")
                  .slice(0, 160)
                  .replace(/[A-Za-z0-9_\-]{24,}/g, "<redacted>"),
              },
        );
      }
      return json(200, {
        probe_model: probeModel,
        note: "secret NAMES and upstream status only; no key value is read or returned",
        results,
      });
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

    // ---- /health, and the paid-spend record it exposes ----
    // Reachable without a key. Reports what the proxy is actually doing and
    // what it has spent, so "we fell through to the paid tier" is a fact on a
    // page rather than something discovered later on an invoice. A tier that
    // costs money and leaves no trace is how a budget disappears quietly.
    if (!body || !body.messages) {
      return json(200, {
        ok: true,
        status: "live",
        time: new Date().toISOString(),
        secrets_configured: {
          AICREDITS_KEY: Boolean(env.AICREDITS_KEY),
          OPENCODE_KEY: Boolean(env.OPENCODE_KEY),
          OPENROUTER_KEY: Boolean(env.OPENROUTER_KEY),
          ZEN_KEY: Boolean(env.ZEN_KEY),
          note: "presence only - values are never read back or returned",
        },
        breaker: await breakerState(env),
        paid_usage: await readPaidUse(env),
      });
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
    // scan falls through to a PAID fallback.
    const goHeaders = goProbeHeaders(request);

    // Every tier's outcome for this request, so a downgrade is never silent.
    const tiers = [];

    // Test-only: `x-cm-force-provider: <name>` moves that provider to the front
    // so a single tier can be measured on its own. Needed because `go` is last
    // for latency, which means a success earlier in the list hides it entirely
    // and we cannot tell "go is broken" from "go was never tried".
    // It cannot bypass the per-device quota, and it exposes no key: the caller
    // only names a provider that is already configured here.
    const forced = (request.headers.get("x-cm-force-provider") || "").trim();
    if (forced) {
      const i = rotation.findIndex(([name]) => name === forced);
      if (i > 0) rotation.unshift(...rotation.splice(i, 1));
    }

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
        // PAID SPEND MUST NEVER BE SILENT. Whenever we answer from a billing
        // upstream we record the token count, the model actually served, and
        // the time, so /health can show what today cost. A tier that costs
        // money and leaves no trace is how a budget disappears quietly.
        if (provider !== "go") {
          await recordPaidUse(env, provider, res);
        }
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
/**
 * Record a response served by a BILLING upstream (anything that is not the
 * included `go` subscription). Keeps a per-UTC-day running total plus the last
 * single request, so /health can answer "what did today cost, and when did we
 * last fall through to the paid tier?".
 *
 * Cost is computed from the token usage the upstream reported, at list price.
 * It is an ESTIMATE from usage, not the invoice - the invoice remains the only
 * authority, and the note in /health says so.
 */
const PRICE_IN_PER_M = 0.15;   // gpt-4o-mini list
const PRICE_OUT_PER_M = 0.60;

async function recordPaidUse(env, provider, res) {
  if (!env.QUOTA) return;
  try {
    let usage = {};
    try {
      usage = JSON.parse(await res.response.clone().text()).usage || {};
    } catch (e) {
      usage = {};
    }
    const pin = Number(usage.prompt_tokens || 0);
    const pout = Number(usage.completion_tokens || 0);
    const cost = (pin / 1e6) * PRICE_IN_PER_M + (pout / 1e6) * PRICE_OUT_PER_M;

    const day = new Date().toISOString().slice(0, 10);
    const key = `paid_${day}`;
    const cur = (await env.QUOTA.get(key)) || '{"requests":0,"usd":0}';
    let agg;
    try {
      agg = JSON.parse(cur);
    } catch (e) {
      agg = { requests: 0, usd: 0 };
    }
    agg.requests = (agg.requests || 0) + 1;
    agg.usd = (agg.usd || 0) + cost;
    await env.QUOTA.put(key, JSON.stringify(agg), { expirationTtl: 86400 * 8 });

    await env.QUOTA.put(
      "paid_last",
      JSON.stringify({
        at: new Date().toISOString(),
        provider,
        requested_model: res.requestedModel || "unknown",
        served_model: res.servedModel || "unknown",
        prompt_tokens: pin,
        completion_tokens: pout,
        est_cost_usd: Number(cost.toFixed(8)),
      }),
      { expirationTtl: 86400 * 30 },
    );
  } catch (e) {
    // Accounting is best-effort; never break the product.
  }
}

async function readPaidUse(env) {
  if (!env.QUOTA) {
    return { available: false, reason: "no QUOTA binding" };
  }
  try {
    const day = new Date().toISOString().slice(0, 10);
    const agg = await env.QUOTA.get(`paid_${day}`);
    const last = await env.QUOTA.get("paid_last");
    return {
      available: true,
      today_utc: day,
      requests_billed: agg ? (JSON.parse(agg).requests || 0) : 0,
      est_cost_usd_today: agg ? Number((JSON.parse(agg).usd || 0).toFixed(6)) : 0,
      last_billed_request: last ? JSON.parse(last) : null,
      note: "ESTIMATE from token usage at list price. The upstream invoice is the only authority.",
    };
  } catch (e) {
    return { available: false, reason: "read failed" };
  }
}

/** Current circuit-breaker state for every tier, for /health. */
async function breakerState(env) {
  if (!env.QUOTA) return { available: false };
  const out = {};
  for (const p of ["go", "aicredits", "openrouter"]) {
    try {
      const raw = await env.QUOTA.get(`cb_${p}`);
      out[p] = raw ? JSON.parse(raw) : { fails: 0, until: 0, state: "not-recorded" };
    } catch (e) {
      out[p] = { error: "read failed" };
    }
  }
  const now = Date.now();
  for (const [k, v] of Object.entries(out)) {
    if (v && typeof v.until === "number") {
      v.suspended = now < v.until;
      v.suspended_for_min = v.suspended ? Math.round((v.until - now) / 60000) : 0;
    }
  }
  return { available: true, tiers: out };
}

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
      requestedModel: model,
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
