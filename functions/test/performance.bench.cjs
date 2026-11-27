"use strict";
// Benchmark exclusivamente local, compara el HEAD anterior con el árbol modificado.
const assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path"), Module = require("node:module");
const {execFileSync} = require("node:child_process");
const {performance} = require("node:perf_hooks");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {confirmOrder: optimized} = require("../src/orders");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
assert.ok(!process.env.GOOGLE_APPLICATION_CREDENTIALS);
const baseline = new Module(path.resolve("src/baseline-benchmark.js"), module);
baseline.filename = path.resolve("src/baseline-benchmark.js");
baseline.paths = module.paths;
const baselineRevision = process.env.PHARMALAB_BASELINE_REVISION || "48c9ea37ec2c8600d673ac05cf021694a6e79e71";
assert.match(baselineRevision, /^[a-f0-9]{40}$/);
const baselineSource = execFileSync("git", ["show", `${baselineRevision}:functions/src/orders.js`], {encoding: "utf8"});
baseline._compile(baselineSource, baseline.filename);
const app = initializeApp({projectId: "demo-pharmalab"}, "benchmark"), db = getFirestore(app);
const scenarios = [{name: "1 producto / 1 lote", products: 1, lots: 1},
  {name: "3 productos / 4 lotes", products: 3, lots: 2},
  {name: "5 productos / 10 lotes", products: 5, lots: 2},
  {name: "20 productos / 100 lotes", products: 20, lots: 5}];
async function fixture(scenario) {
  const response = await fetch("http://127.0.0.1:8080/emulator/v1/projects/demo-pharmalab/databases/(default)/documents", {method: "DELETE"});
  assert.ok(response.ok);
  const batch = db.batch(), set = (p, data) => batch.set(db.doc(p), data);
  set("usuarios/bench", {rol: "cliente", estado: true});
  set("farmacia_cliente/FARM001", {usuario_id: "bench", estado: true});
  set("direcciones/DIR001", {id_cliente: "FARM001", direccion: "Demo", estado: true});
  set("configuracion/contadores_pedidos", {ultimo_numero: 1, ultimo_id: "PED001", ultimo_documento_id: "PED001"});
  set("categorias/CAT001", {nombre: "Demo"});
  const items = [];
  for (let i = 0; i < scenario.products; i++) {
    const productId = `P${i}`;
    set(`productos/${productId}`, {nombre: "Demo", precio: 10, estado: true, requiere_vencimiento: true, categoria_id: "CAT001"});
    for (let j = 0; j < scenario.lots; j++) set(`lotes_productos/L${i}_${j}`, {producto_id: productId,
      cantidad_disponible: 5, fecha_vencimiento: Timestamp.fromDate(new Date(`203${j + 1}-01-01`))});
    const quantity = scenario.products === 3 && i > 0 ? 2 : scenario.lots === 5 ? 25 : scenario.lots === 1 ? 2 : 7;
    items.push({productId, quantity, expectedPriceCents: 1000});
  }
  await batch.commit();
  return {operationId: "benchmark-operation", addressId: "DIR001", notes: "", items};
}
function measuredDb(stats) {
  return {doc: db.doc.bind(db), collection: db.collection.bind(db), runTransaction: (callback) => db.runTransaction((tx) => {
    stats.attempts++;
    const proxy = new Proxy(tx, {get(target, prop) {
      if (prop === "get" || prop === "getAll") return async (...args) => {
        stats.readRpcCalls++;
        const data = await target[prop](...args);
        stats.documentReads += Array.isArray(data) ? data.length : data.docs ? Math.max(1, data.size) : 1;
        return data;
      };
      if (["create", "update", "set", "delete"].includes(prop)) return (...args) => { stats.writes++; return target[prop](...args); };
      return typeof target[prop] === "function" ? target[prop].bind(target) : target[prop];
    }});
    return callback(proxy);
  })};
}
(async () => {
  const results = [];
  for (const scenario of scenarios) {
    const runs = [];
    for (let sample = 0; sample < 3; sample++) for (const [version, confirm] of [["before", baseline.exports.confirmOrder], ["after", optimized]]) {
      const input = await fixture(scenario), stats = {attempts: 0, readRpcCalls: 0, documentReads: 0, writes: 0};
      const start = performance.now();
      await confirm(measuredDb(stats), "bench", input);
      runs.push({version, sample, ...stats, backendMs: Math.round((performance.now() - start) * 100) / 100});
    }
    results.push({scenario: scenario.name, runs});
  }
  fs.writeFileSync("../docs/RENDIMIENTO_EMULADOR.json", JSON.stringify({environment: "Firebase Emulator Suite local; no representa Ohio-Sao Paulo", node: process.version,
    baselineRevision, baselineSha256: require("node:crypto").createHash("sha256").update(baselineSource).digest("hex"), results}, null, 2) + "\n");
  console.log(JSON.stringify(results));
})().catch((error) => { console.error(error); process.exitCode = 1; }).finally(() => deleteApp(app));
