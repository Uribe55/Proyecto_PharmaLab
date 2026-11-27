"use strict";
// Transporte HTTP independiente. La lógica comercial permanece en las transacciones existentes.
const http = require("node:http");
const {Metrics} = require("./performance");
const {confirmOrder, operationResult} = require("./orders");
const {cancelOrder, assignOrder, transitionDelivery, approveOrder} = require("./order_actions");
const statuses = {"invalid-argument": 400, unauthenticated: 401, "permission-denied": 403,
  "not-found": 404, "already-exists": 409, "failed-precondition": 412,
  "resource-exhausted": 429, unavailable: 503};
const problem = (code, message) => Object.assign(new Error(message), {code});

function createServer({db, auth, production = false, origins = [], limit = 60}) {
  const buckets = new Map();
  const timer = setInterval(() => {
    for (const [key, value] of buckets) if (Date.now() > value.until) buckets.delete(key);
  }, 60000);
  timer.unref();
  function throttle(key, maximum) {
    if (!buckets.has(key) && buckets.size >= 10000) throw problem("resource-exhausted", "Servidor ocupado. Reintenta más tarde.");
    const now = Date.now(), prior = buckets.get(key);
    const bucket = !prior || prior.until < now ? {count: 0, until: now + 60000} : prior;
    buckets.set(key, bucket);
    if (++bucket.count > maximum) throw problem("resource-exhausted", "Demasiadas solicitudes. Reintenta con el mismo ID.");
  }
  const server = http.createServer(async (req, res) => {
    const metrics = new Metrics();
    const send = (status, body) => {
      const timings = metrics.snapshot();
      res.writeHead(status, {"Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store",
        "Server-Timing": `processing;dur=${timings.totalMs}`,
        "Access-Control-Expose-Headers": "Server-Timing",
        "X-Content-Type-Options": "nosniff", ...(status === 429 ? {"Retry-After": "60"} : {})});
      res.end(JSON.stringify(body));
    };
    try {
      if (req.url === "/health" && req.method === "GET") return send(200, {status: "ok"});
      const origin = req.headers.origin;
      if (origin) {
        if (!origins.includes(origin)) throw problem("permission-denied", "Origen no autorizado.");
        res.setHeader("Access-Control-Allow-Origin", origin);
        res.setHeader("Vary", "Origin");
        res.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
      }
      if (req.method === "OPTIONS") return send(204, null);
      // No confiar en X-Forwarded-For proporcionado por un cliente.
      throttle(`socket:${req.socket.remoteAddress}`, limit * 20);
      const match = /^Bearer ([^\s]+)$/.exec(req.headers.authorization || "");
      if (!match || match[1].length > 8192) throw problem("unauthenticated", "Inicia sesión.");
      let token;
      try { token = await metrics.measure("authenticationMs", () => auth.verifyIdToken(match[1], production)); }
      catch { throw problem("unauthenticated", "Sesión inválida o vencida. Inicia sesión nuevamente."); }
      throttle(`uid:${token.uid}`, limit);
      // Cada operación valida usuario/rol/estado DENTRO de su transacción.
      let body = {};
      if (req.method === "POST") {
        const bodyClock = new Metrics();
        if (!(req.headers["content-type"] || "").startsWith("application/json")) throw problem("invalid-argument", "Se requiere JSON.");
        const chunks = []; let size = 0;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > 65536) throw problem("invalid-argument", "Solicitud demasiado grande (máximo 64 KiB).");
          chunks.push(chunk);
        }
        try { body = JSON.parse(Buffer.concat(chunks).toString("utf8")); }
        catch { throw problem("invalid-argument", "JSON inválido."); }
        if (!body || typeof body !== "object" || Array.isArray(body)) throw problem("invalid-argument", "Solicitud inválida.");
        metrics.values.requestBodyMs = bodyClock.snapshot().totalMs;
      }
      const path = new URL(req.url, "http://localhost").pathname;
      let route, result;
      if (req.method === "POST" && path === "/api/orders") result = await confirmOrder(db, token.uid, body, {metrics, includeOrderSnapshot: true});
      else if (req.method === "GET" && (route = /^\/api\/operations\/([\w-]{1,128})$/.exec(path))) result = await operationResult(db, token.uid, route[1]);
      else if (req.method === "POST" && (route = /^\/api\/orders\/([\w-]{1,128})\/(cancel|assign|approve)$/.exec(path))) {
        const action = {cancel: cancelOrder, assign: assignOrder, approve: approveOrder}[route[2]];
        result = await action(db, token.uid, {...body, orderId: route[1]});
      } else if (req.method === "POST" && (route = /^\/api\/deliveries\/([\w-]{1,128})\/transition$/.exec(path))) {
        result = await transitionDelivery(db, token.uid, {...body, deliveryId: route[1]});
      } else throw problem("not-found", "Ruta no encontrada.");
      send(200, {data: result, ...(metrics.orderSnapshot ? {order: metrics.orderSnapshot} : {})});
    } catch (error) {
      const status = statuses[error.code] || 500;
      // Nunca registrar tokens, cuerpos, credenciales ni mensajes internos del SDK.
      if (status === 500) console.error("request_failed", {code: "internal"});
      send(status, {error: {code: status === 500 ? "internal" : error.code,
        message: status === 500 ? "No se pudo confirmar el resultado. Consulta la operación antes de reintentar." : error.message,
        ...(error.code === "failed-precondition" && error.details?.prices ? {details: {prices: error.details.prices}} : {})}});
    } finally {
      if (req.method === "POST" && req.url === "/api/orders") {
        console.log(JSON.stringify({event: "order_confirmation_metrics", status: res.statusCode,
          processUptimeSeconds: Math.round(process.uptime()), ...metrics.snapshot()}));
      }
    }
  });
  server.headersTimeout = 15000;
  server.requestTimeout = 120000;
  server.on("close", () => clearInterval(timer));
  return server;
}
module.exports = {createServer};
