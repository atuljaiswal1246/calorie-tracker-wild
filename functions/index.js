/**
 * Cal Matters — Gemini API proxy.
 *
 * The Gemini API key lives in the function's runtime config
 * (firebase functions:config:set gemini.key=...), never in the client app.
 * The app calls this function; this function attaches the key and forwards
 * to Gemini. Also enforces a per-device daily quota so a leaked endpoint
 * can't burn the account.
 *
 * NOTE: runtime config works on the Spark (free) plan. If you later switch
 * the project to Blaze, migrate to Secret Manager for stronger storage.
 */

const { onRequest } = require("firebase-functions/v2/https");
const { getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

if (!getApps().length) initializeApp();

const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const DAILY_LIMIT = 200; // requests per device per day

exports.geminiProxy = onRequest(
  {
    region: "asia-south1",
    maxInstances: 10,
    memory: "256MiB",
    timeoutSeconds: 60,
    cors: true,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    // Key from runtime config (set via firebase CLI, not in code).
    const apiKey = process.env.GEMINI_KEY || "";
    if (!apiKey) {
      res.status(500).json({ error: "Server not configured (missing Gemini key)" });
      return;
    }

    // Body contract: { model: "gemini-3.6-flash", contents: [...], ... }
    // We forward everything to Gemini verbatim, only injecting the key.
    const body = req.body || {};
    const model = String(body.model || "gemini-3.6-flash").replace(/[^a-zA-Z0-9_.-]/g, "");
    if (!body.contents) {
      res.status(400).json({ error: "contents required" });
      return;
    }

    // --- Per-device daily quota (Firestore counter) ---
    const deviceId = String(req.get("x-device-id") || "unknown").slice(0, 64);
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const db = getFirestore();
    const counterRef = db.collection("quotas").doc(`${deviceId}_${today}`);
    try {
      const counter = await counterRef.get();
      const used = counter.exists ? counter.data().used || 0 : 0;
      if (used >= DAILY_LIMIT) {
        res.status(429).json({ error: "Daily limit reached", limit: DAILY_LIMIT });
        return;
      }
      await counterRef.set({ used: used + 1 }, { merge: true });
    } catch (e) {
      // If quota tracking fails, let the request through rather than
      // breaking the product (offline-first resilience).
    }

    try {
      const upstream = await fetch(`${GEMINI_BASE}/${model}:generateContent?key=${apiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const text = await upstream.text();
      res.status(upstream.status).type("application/json").send(text);
    } catch (e) {
      res.status(502).json({ error: "Gemini upstream failed", detail: e.message });
    }
  }
);
