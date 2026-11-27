"use strict";
const {test, before, after, beforeEach} = require("node:test");
const assert = require("node:assert/strict");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {Timestamp} = require("firebase/firestore");
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8085");
let env;
function client(uid) { return env.authenticatedContext(uid).firestore(); }
before(async () => { env = await initializeTestEnvironment({projectId: "demo-pharmalab-client-tracking", firestore: {
  host: "127.0.0.1", port: 8085, rules: require("node:fs").readFileSync("../firestore.render.rules", "utf8")}}); });
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore(), batch = db.batch();
    for (const [path, data] of Object.entries({
      "usuarios/client": {rol: "cliente", estado: true}, "usuarios/other": {rol: "cliente", estado: true},
      "farmacia_cliente/FARM001": {usuario_id: "client", estado: true}, "farmacia_cliente/FARM002": {usuario_id: "other", estado: true},
      "pedidos/OWN": {schema_version: "transactional_multi_v1", id_cliente: "FARM001", usuario_id: "client", estado: "pendiente", numero_comercial: "PED005", total: 99, fecha_pedido: Timestamp.now(), id_entrega: "DELIVERY"},
      "pedidos/OLD": {schema_version: "spark_single_v2", id_cliente: "FARM001", estado: "entregado", total: 20, fecha_pedido: Timestamp.now()},
      "pedidos/OTHER": {id_cliente: "FARM002", estado: "pendiente", fecha_pedido: Timestamp.now()},
      "pedidos/OWN/detalle_pedido/DET001": {id_producto: "P1", cantidad: 2, precio_unitario: 10},
      "pedidos/OWN/detalle_pedido/DET002": {id_producto: "P2", cantidad: 1, precio_unitario: 79},
      "pedidos/OWN/historial_estado/CONF": {estado_nuevo: "pendiente", fecha_cambio: Timestamp.now()},
      "entregas/DELIVERY": {id_pedido: "OWN", id_repartidor: "EMP001", estado: "asignada"},
      "entregas/OTHER": {id_pedido: "OTHER", id_repartidor: "EMP002"},
      "empleado/EMP001": {usuario_id: "driver", nombre: "Privado"},
      "lotes_productos/LOT": {cantidad_disponible: 10},
    })) batch.set(db.doc(path), data);
    await batch.commit();

  });
});
test("cliente UID distinto de FARM consulta exclusivamente sus pedidos y ambas lÃ­neas", async () => {
  const db = client("client");
  const orders = await assertSucceeds(db.collection("pedidos").where("id_cliente", "==", "FARM001").orderBy("fecha_pedido", "desc").get());
  assert.equal(orders.size, 2);
  assert.equal((await assertSucceeds(db.collection("pedidos/OWN/detalle_pedido").get())).size, 2);
  await assertSucceeds(db.collection("pedidos/OWN/historial_estado").get());
  await assertSucceeds(db.doc("entregas/DELIVERY").get());
  for (const path of ["pedidos/OTHER", "entregas/OTHER", "empleado/EMP001"]) await assertFails(db.doc(path).get());
  await assertFails(db.collection("pedidos").where("id_cliente", "==", "FARM002").get());
  const other = client("other");
  await assertFails(other.collection("pedidos/OWN/detalle_pedido").get());
  await assertFails(other.collection("pedidos/OWN/historial_estado").get());
});
test("consulta no concede modificaciones de estado, historial, precio, entrega o inventario", async () => {
  const db = client("client");
  for (const [path, data] of [
    ["pedidos/OWN", {estado: "entregado"}], ["pedidos/OWN", {total: 1}],
    ["pedidos/OWN/detalle_pedido/DET001", {precio_unitario: 1}],
    ["entregas/DELIVERY", {estado: "en_ruta"}], ["lotes_productos/LOT", {cantidad_disponible: 100}],
  ]) await assertFails(db.doc(path).update(data));
  await assertFails(db.doc("pedidos/OWN/historial_estado/FAKE").set({estado_nuevo: "entregado"}));
});

