"use strict";
const {test, before, beforeEach, after} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {execFileSync} = require("node:child_process");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, getDoc, getDocs, collection, setDoc, updateDoc, query, where, runTransaction, serverTimestamp} = require("firebase/firestore");
const {confirmOrder, operationResult} = require("../src/orders");
const {cancelOrder, assignOrder, transitionDelivery} = require("../src/order_actions");

// No fallback a credenciales/base real. Todos los borrados de este test son del emulador demo.
assert.match(process.env.FIRESTORE_EMULATOR_HOST || "", /^(127\.0\.0\.1|localhost):8080$/);
assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST || "", /^(127\.0\.0\.1|localhost):9099$/);
const projectId = "demo-pharmalab";
const app = initializeApp({projectId});
const db = getFirestore(app);
let env;
const date = (iso) => Timestamp.fromDate(new Date(iso));
const request = (operationId = "operation-1", quantity = 2, more = {}) => ({
  operationId, addressId: "DIR001", notes: "Llamar antes", items: [
    {productId: "PROD001", quantity, expectedPriceCents: 15000},
  ], ...more,
});
const confirm = (data = request(), uid = "client-a", options) => confirmOrder(db, uid, data, options);
const stock = async (id) => (await db.doc(`lotes_productos/${id}`).get()).get("cantidad_disponible");
const orderCount = async () => (await db.collection("pedidos").get()).size;

before(async () => {
  env = await initializeTestEnvironment({projectId,
    firestore: {host: "127.0.0.1", port: 8080, rules: fs.readFileSync("../firestore.rules", "utf8")}});
});
beforeEach(async () => {
  await env.clearFirestore();
  const batch = db.batch();
  for (const [path, data] of Object.entries({
    "usuarios/client-a": {rol: "cliente", estado: true, nombre: "Cliente A"},
    "usuarios/client-b": {rol: "cliente", estado: true, nombre: "Cliente B"},
    "usuarios/seller": {rol: "vendedor", estado: true},
    "empleado/EMP_SELLER": {usuario_id: "seller", cargo: "Vendedor", estado: true},
    "usuarios/driver": {rol: "repartidor", estado: true},
    "usuarios/admin": {rol: "administrador", estado: true},
    "farmacia_cliente/FARM001": {usuario_id: "client-a", estado: true, nombre_farmacia: "Farmacia A", telefono: "70000000"},
    "farmacia_cliente/FARM002": {usuario_id: "client-b", estado: true, nombre_farmacia: "Farmacia B"},
    "direcciones/DIR001": {id_cliente: "FARM001", nombre: "Principal", direccion: "Av. A 123", referencia: "Puerta azul", estado: true},
    "direcciones/DIR002": {id_cliente: "FARM002", nombre: "Principal", direccion: "Av. B 456", estado: true},
    "productos/PROD001": {nombre: "Paracetamol", precio: 150, estado: true, requiere_vencimiento: true,
      presentacion: "Caja de 2 blísteres de 10 tabletas", unidadMedida: "Caja", unidad_por_envase: 20},
    "categorias/CAT001": {nombre: "Genéricos"},
    "lotes_productos/LOTE001": {producto_id: "PROD001", cantidad_disponible: 5, fecha_vencimiento: date("2035-01-01T04:00:00Z")},
    "lotes_productos/LOTE003": {producto_id: "PROD001", cantidad_disponible: 10, fecha_vencimiento: date("2036-01-01T04:00:00Z")},
    "lotes_productos/VENCIDO": {producto_id: "PROD001", cantidad_disponible: 100, fecha_vencimiento: date("2000-01-01T04:00:00Z")},
    "configuracion/contadores_pedidos": {ultimo_numero: 1, ultimo_id: "PED001", ultimo_documento_id: "PED001"},
    "configuracion/contadores_farmacia": {ultimo_numero: 2, ultimo_id: "FARM002", ultimo_uid: "client-b"},
    "pedidos/PED001": {estado: "pendiente", fecha_pedido: date("2026-01-01T12:00:00Z"), id_cliente: "FARM001", id_direccion: "DIR001", total: 150},
    "pedidos/PED001/detalle_pedido/DET001": {id_producto: "PROD001", cantidad: 1, precio_unitario: 150, subtotal: 150},
  })) batch.set(db.doc(path), data);
  await batch.commit();
});
after(async () => { await env.cleanup(); await deleteApp(app); });

test("pedido válido: precio comercial, snapshot, detalle e historial atómicos", async () => {
  const result = await confirm();
  assert.notEqual(result.orderId, result.number);
  const order = await db.doc(`pedidos/${result.orderId}`).get();
  assert.equal(order.get("total"), 300);
  assert.equal(order.get("estado"), "pendiente");
  assert.equal(order.get("id_cliente"), "FARM001");
  const line = await order.ref.collection("detalle_pedido").doc("DET001").get();
  assert.equal(line.get("cantidad"), 2); // 2 cajas, NO 40 tabletas.
  assert.equal(line.get("unidad_por_envase"), 20);
  assert.equal(await stock("LOTE001"), 3);
  const events = await order.ref.collection("historial_estado").get();
  assert.equal(events.size, 1);
  assert.equal(events.docs[0].get("usuario_id"), "client-a");
  await db.doc("direcciones/DIR001").update({direccion: "Otra dirección"});
  assert.equal((await order.ref.get()).get("entrega.direccion"), "Av. A 123");
});
test("carrito vacío y cantidades inválidas no escriben", async () => {
  for (const value of [0, -1, 1.5, "2", 10001]) {
    await assert.rejects(confirm(request("bad", value)), {code: "invalid-argument"});
  }
  await assert.rejects(confirm(request("empty", 1, {items: []})), {code: "invalid-argument"});
  assert.equal(await orderCount(), 1);
  assert.equal(await stock("LOTE001"), 5);
});
test("producto inactivo", async () => {
  await db.doc("productos/PROD001").update({estado: false});
  await assert.rejects(confirm(), {code: "failed-precondition"});
  assert.equal(await stock("LOTE001"), 5);
});
test("precio modificado exige nueva revisión", async () => {
  await db.doc("productos/PROD001").update({precio: 160});
  await assert.rejects(confirm(), (e) => e.details.prices.PROD001 === 16000);
  assert.equal(await orderCount(), 1);
  assert.equal(await stock("LOTE001"), 5);
  await confirm(request("reviewed", 2, {items: [{productId: "PROD001", quantity: 2, expectedPriceCents: 16000}]}));
});
test("stock insuficiente no considera lotes vencidos", async () => {
  await assert.rejects(confirm(request("large", 16)), {code: "failed-precondition"});
  await db.doc("lotes_productos/LOTE001").delete();
  await db.doc("lotes_productos/LOTE003").delete();
  await assert.rejects(confirm(), {code: "failed-precondition"});
  assert.equal(await stock("VENCIDO"), 100);
});
test("FEFO reparte 8 cajas entre 2 lotes", async () => {
  const result = await confirm(request("multi", 8));
  assert.equal(await stock("LOTE001"), 0);
  assert.equal(await stock("LOTE003"), 7);
  const line = await db.doc(`pedidos/${result.orderId}/detalle_pedido/DET001`).get();
  assert.deepEqual(line.get("asignaciones_lotes"), [{id_lote: "LOTE001", cantidad: 5}, {id_lote: "LOTE003", cantidad: 3}]);
});

test("casos 01/02: 100 unidades; 25 de un lote y 45 de dos lotes FEFO", async () => {
  await db.doc("lotes_productos/LOTE001").update({cantidad_disponible: 100});
  await confirm(request("single", 25));
  assert.equal(await stock("LOTE001"), 75);
  await db.doc("lotes_productos/LOTE001").update({cantidad_disponible: 30});
  await db.doc("lotes_productos/LOTE003").update({cantidad_disponible: 70});
  const result = await confirm(request("two-lots", 45));
  assert.equal(await stock("LOTE001"), 0);
  assert.equal(await stock("LOTE003"), 55);
  assert.equal((await db.doc(`pedidos/${result.orderId}`).get()).get("lineas").length, 1);
});

async function threeProducts() {
  await db.doc("lotes_productos/LOTE001").update({cantidad_disponible: 30});
  await db.doc("lotes_productos/LOTE003").update({cantidad_disponible: 70});
  for (const [name, available] of [["B", 50], ["C", 25]]) {
    await db.doc(`productos/${name}`).set({nombre: name, precio: 2, estado: true, requiere_vencimiento: false});
    await db.doc(`lotes_productos/${name}`).set({producto_id: name, cantidad_disponible: available});
  }
  return request("three", 1, {items: [
    {productId: "PROD001", quantity: 45, expectedPriceCents: 15000},
    {productId: "B", quantity: 20, expectedPriceCents: 200},
    {productId: "C", quantity: 5, expectedPriceCents: 200},
  ]});
}
test("caso 03: tres productos, cuatro lotes, un pedido y total histórico", async () => {
  const result = await confirm(await threeProducts());
  assert.equal(await stock("LOTE001"), 0); assert.equal(await stock("LOTE003"), 55);
  assert.equal(await stock("B"), 30); assert.equal(await stock("C"), 20);
  const order = await db.doc(`pedidos/${result.orderId}`).get();
  assert.equal(order.get("lineas").length, 3);
  assert.equal(order.get("total"), 6800);
  assert.equal((await order.ref.collection("detalle_pedido").get()).size, 3);
  assert.equal((await order.ref.collection("movimientos_inventario").get()).size, 4);
  assert.equal(order.get("numero_comercial"), "PED002");
  assert.equal((await db.doc("configuracion/contadores_pedidos").get()).get("ultimo_id"), "PED002");
});
test("caso 04: falla el último producto sin descontar ninguno", async () => {
  const input = await threeProducts(); input.items[2].quantity = 26;
  await assert.rejects(confirm(input), (e) => e.details.available === 25);
  assert.equal(await stock("LOTE001"), 30); assert.equal(await stock("B"), 50);
  assert.equal(await orderCount(), 1);
});
test("casos 05/06: lotes inactivos, bloqueados, no comercializables y sin fecha no participan", async () => {
  for (const [key, value] of [["estado", false], ["bloqueado", true], ["comercializable", false]]) {
    await db.doc("lotes_productos/LOTE001").update({estado: true, bloqueado: false, comercializable: true, [key]: value});
    await assert.rejects(confirm(request(`bad-${key}`, 11)), {code: "failed-precondition"});
    assert.equal(await stock("LOTE001"), 5);
  }
  await db.doc("lotes_productos/LOTE001").update({estado: true, bloqueado: false, comercializable: true, fecha_vencimiento: null});
  await assert.rejects(confirm(request("no-date", 11)), {code: "failed-precondition"});
});
test("vencimiento por día Bolivia: sigue vigente hasta terminar el día comercial", async () => {
  await db.doc("lotes_productos/LOTE001").update({fecha_vencimiento: date("2026-11-27T04:00:00Z")});
  await confirm(request("same-day", 2), "client-a", {now: () => new Date("2026-11-28T03:59:59Z")});
  assert.equal(await stock("LOTE001"), 3);
});
test("caso 07: 3 blísteres + 2 cajas comparten 100 unidades base y descuentan 70", async () => {
  await db.doc("productos/PROD001").update({inventario_unidad: "base", presentaciones_venta: [
    {id: "blister", nombre: "Blíster", unidades_base: 10, precio: 15, estado: true},
    {id: "caja", nombre: "Caja", unidades_base: 20, precio: 28, estado: true},
  ]});
  await db.doc("lotes_productos/LOTE001").update({cantidad_disponible: 100});
  const result = await confirm(request("variants", 1, {items: [
    {productId: "PROD001", presentationId: "blister", quantity: 3, expectedPriceCents: 1500},
    {productId: "PROD001", presentationId: "caja", quantity: 2, expectedPriceCents: 2800},
  ]}));
  assert.equal(await stock("LOTE001"), 30);
  const order = await db.doc(`pedidos/${result.orderId}`).get();
  assert.deepEqual(order.get("lineas").map((l) => l.cantidad_inventario), [30, 40]);
  assert.equal(order.get("total"), 101);
  assert.equal((await order.ref.collection("movimientos_inventario").get()).size, 1);
});
test("presentaciones: no admite factores o precios inventados, ni sobreventa acumulada", async () => {
  await assert.rejects(confirm(request("forged", 1, {items: [{productId: "PROD001", presentationId: "fake", quantity: 1, expectedPriceCents: 1}]})), {code: "failed-precondition"});
  await db.doc("productos/PROD001").update({inventario_unidad: "base", presentaciones_venta: [
    {id: "ten", nombre: "Diez", unidades_base: 10, precio: 10, estado: true},
    {id: "twenty", nombre: "Veinte", unidades_base: 20, precio: 20, estado: true},
  ]});
  await assert.rejects(confirm(request("oversell", 1, {items: [
    {productId: "PROD001", presentationId: "ten", quantity: 1, expectedPriceCents: 1000},
    {productId: "PROD001", presentationId: "twenty", quantity: 1, expectedPriceCents: 2000},
  ]})), {code: "failed-precondition"});
  assert.equal(await stock("LOTE001"), 5);
});
test("casos 09/10: cancelación atómica e idempotente devuelve cada lote histórico", async () => {
  const input = await threeProducts();
  const result = await confirm(input);
  const cancel = () => cancelOrder(db, "client-a", {orderId: result.orderId, action: "cancel", reason: "Corrección"});
  await assert.rejects(cancelOrder(db, "client-a", {orderId: result.orderId, action: "cancel", reason: "Prueba"}, {beforeCommit: () => {throw Error("fallo");}}));
  assert.equal(await stock("LOTE001"), 0);
  await Promise.all([cancel(), cancel()]); await cancel();
  assert.equal(await stock("LOTE001"), 30); assert.equal(await stock("LOTE003"), 70);
  assert.equal(await stock("B"), 50); assert.equal(await stock("C"), 25);
  assert.equal((await db.doc(`pedidos/${result.orderId}`).collection("movimientos_inventario").get()).size, 8);
  assert.deepEqual(await confirm(input), result);
});
test("cancelar aprobado exige solicitud y aceptación del vendedor, una sola restitución", async () => {
  const result = await confirm(); const ref = db.doc(`pedidos/${result.orderId}`);
  await ref.update({estado: "aprobado"});
  await assert.rejects(cancelOrder(db, "client-a", {orderId: ref.id, action: "cancel", reason: "Cambio"}), {code: "failed-precondition"});
  await cancelOrder(db, "client-a", {orderId: ref.id, action: "requestCancellation", reason: "Cambio"});
  await assert.rejects(cancelOrder(db, "client-b", {orderId: ref.id, action: "cancel", reason: "Ajeno"}), {code: "permission-denied"});
  await cancelOrder(db, "seller", {orderId: ref.id, action: "acceptCancellation", reason: "Autorizado"});
  await cancelOrder(db, "seller", {orderId: ref.id, action: "acceptCancellation", reason: "Reintento"});
  assert.equal(await stock("LOTE001"), 5);
});
test("cuenta con deuda: rechaza nuevas compras, conserva recuperación idempotente", async () => {
  const result = await confirm();
  await db.doc("usuarios/client-a").update({tiene_deuda_vencida: true});
  assert.deepEqual(await confirm(), result);
  await assert.rejects(confirm(request("debt")), {code: "failed-precondition"});
});
test("caso 16: 20 líneas válidas; 21 líneas y 101 lotes por producto se rechazan", async () => {
  const items = [];
  for (let i = 0; i < 20; i++) {
    const id = `P${i}`;
    await db.doc(`productos/${id}`).set({nombre: id, precio: 1, estado: true, requiere_vencimiento: false});
    await db.doc(`lotes_productos/${id}`).set({producto_id: id, cantidad_disponible: 1});
    items.push({productId: id, quantity: 1, expectedPriceCents: 100});
  }
  await assert.rejects(confirm(request("over-lines", 1, {items: [...items, {productId: "extra", quantity: 1, expectedPriceCents: 100}]})), {code: "invalid-argument"});
  await confirm(request("max-lines", 1, {items}));
  const batch = db.batch();
  for (let i = 0; i < 99; i++) batch.set(db.doc(`lotes_productos/EXTRA${i}`), {producto_id: "PROD001", cantidad_disponible: 1});
  await batch.commit();
  await assert.rejects(confirm(request("over-lots")), {code: "resource-exhausted"});
  assert.equal(await stock("LOTE001"), 5);
});
test("límite: 100 lotes utilizados se confirman y 101 abortan todo el pedido", async () => {
  const batch = db.batch();
  for (const p of ["X", "Y", "Z"]) {
    batch.set(db.doc(`productos/${p}`), {nombre: p, precio: 1, estado: true, requiere_vencimiento: false});
    for (let i = 0; i < (p === "Z" ? 1 : 50); i++) batch.set(db.doc(`lotes_productos/${p}${i}`), {producto_id: p, cantidad_disponible: 1});
  }
  await batch.commit();
  const items = ["X", "Y"].map((productId) => ({productId, quantity: 50, expectedPriceCents: 100}));
  await assert.rejects(confirm(request("101-lots", 1, {items: [...items, {productId: "Z", quantity: 1, expectedPriceCents: 100}]})), {code: "resource-exhausted"});
  assert.equal(await stock("X0"), 1);
  const result = await confirm(request("100-lots", 1, {items}));
  assert.equal((await db.doc(`pedidos/${result.orderId}`).collection("movimientos_inventario").get()).size, 100);
  assert.equal(await stock("X0"), 0);
});

test("rules: esquema múltiple, detalle y movimientos no se pueden falsificar desde ningún cliente", async () => {
  const result = await confirm(await threeProducts());
  for (const uid of ["client-a", "seller", "admin"]) {
    const client = env.authenticatedContext(uid).firestore();
    await assertFails(setDoc(doc(client, "pedidos/falso"), {schema_version: "transactional_multi_v1", usuario_id: uid, id_cliente: "FARM001", estado: "pendiente", total: 1}));
    await assertFails(updateDoc(doc(client, `pedidos/${result.orderId}`), {total: 1}));
    await assertFails(updateDoc(doc(client, `pedidos/${result.orderId}/detalle_pedido/DET001`), {cantidad: 999}));
    await assertFails(setDoc(doc(client, `pedidos/${result.orderId}/movimientos_inventario/falso`), {cantidad: 999}));
  }
  const own = env.authenticatedContext("client-a").firestore();
  await assertSucceeds(getDoc(doc(own, "lotes_productos/LOTE003")));
  await assertSucceeds(getDocs(collection(own, `pedidos/${result.orderId}/detalle_pedido`)));
  const foreign = env.authenticatedContext("client-b").firestore();
  await assertFails(getDocs(collection(foreign, `pedidos/${result.orderId}/movimientos_inventario`)));
});

test("entrega fallida conserva la reserva y no permite cancelar para devolver stock", async () => {
  const result = await confirm(), ref = db.doc(`pedidos/${result.orderId}`);
  await ref.update({estado: "aprobado"});
  await db.doc("empleado/EMP001").set({usuario_id: "driver", estado: true, cargo: "Repartidor"});
  const {deliveryId} = await assignOrder(db, "seller", {orderId: ref.id, employeeId: "EMP001"});
  await transitionDelivery(db, "driver", {deliveryId, state: "en_ruta"});
  await transitionDelivery(db, "driver", {deliveryId, state: "fallida", reason: "Cliente ausente"});
  assert.equal(await stock("LOTE001"), 3);
  await assert.rejects(cancelOrder(db, "client-a", {orderId: ref.id, action: "cancel", reason: "No"}), {code: "failed-precondition"});
});
test("cancelar después del vencimiento restituye físicamente, pero el lote no vuelve a ser vendible", async () => {
  const result = await confirm();
  await db.doc("lotes_productos/LOTE001").update({fecha_vencimiento: date("2000-01-01T04:00:00Z")});
  await cancelOrder(db, "client-a", {orderId: result.orderId, action: "cancel", reason: "Cambio"});
  assert.equal(await stock("LOTE001"), 5);
  const lot = await db.doc("lotes_productos/LOTE001").get();
  assert.equal(require("../src/inventory").eligibleLots([{id: lot.id, data: lot.data()}], true, new Date()).length, 0);
});
test("logística múltiple: una entrega sin precios, no descuenta al aprobar, asignar o entregar", async () => {
  const result = await confirm(await threeProducts()), ref = db.doc(`pedidos/${result.orderId}`);
  await ref.update({estado: "aprobado"});
  await db.doc("empleado/EMP001").set({usuario_id: "driver", estado: true, cargo: "Repartidor", nombre: "Conductor"});
  const assignment = await assignOrder(db, "seller", {orderId: ref.id, employeeId: "EMP001"});
  assert.deepEqual(await assignOrder(db, "seller", {orderId: ref.id, employeeId: "EMP001"}), assignment);
  const delivery = await db.doc(`entregas/${assignment.deliveryId}`).get();
  assert.equal(delivery.get("productos").length, 3);
  assert.equal(delivery.get("productos")[0].precio_unitario, undefined);
  await transitionDelivery(db, "driver", {deliveryId: delivery.id, state: "en_ruta"});
  await assert.rejects(cancelOrder(db, "client-a", {orderId: ref.id, action: "cancel", reason: "En ruta"}), {code: "failed-precondition"});
  await transitionDelivery(db, "driver", {deliveryId: delivery.id, state: "entregado"});
  await transitionDelivery(db, "driver", {deliveryId: delivery.id, state: "entregado"});
  assert.equal(await stock("LOTE003"), 55);
  assert.equal((await ref.get()).get("estado"), "entregado");
  assert.equal((await delivery.ref.collection("detalle_entrega").get()).docs.every((d) => d.get("cantidad_entregada") === d.get("cantidad_programada")), true);
});
test("FIFO determinista en producto sin vencimiento obligatorio", async () => {
  await db.doc("productos/PROD001").update({requiere_vencimiento: false});
  await db.doc("lotes_productos/LOTE001").update({fecha_vencimiento: null, fecha_ingreso: date("2026-02-01T00:00:00Z")});
  await db.doc("lotes_productos/LOTE003").update({fecha_vencimiento: null, fecha_ingreso: date("2026-01-01T00:00:00Z")});
  await confirm();
  assert.equal(await stock("LOTE003"), 8);
  assert.equal(await stock("LOTE001"), 5);
});
test("dos farmacias simultáneas obtienen números únicos y stock correcto", async () => {
  const [a, b] = await Promise.all([confirm(request("a", 4)), confirm(request("b", 4, {addressId: "DIR002"}), "client-b")]);
  assert.notEqual(a.orderId, b.orderId);
  assert.notEqual(a.number, b.number);
  assert.equal(await stock("LOTE001") + await stock("LOTE003"), 7);
});
test("concurrencia con stock insuficiente: solo una compra se confirma", async () => {
  const results = await Promise.allSettled([confirm(request("a", 10)), confirm(request("b", 10, {addressId: "DIR002"}), "client-b")]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(await orderCount(), 2);
  assert.equal(await stock("LOTE001") + await stock("LOTE003"), 5);
});
test("fallo de transacción no produce cambios parciales", async () => {
  await assert.rejects(confirm(request(), "client-a", {beforeCommit: () => {throw new Error("fallo inyectado");}}));
  assert.equal(await orderCount(), 1);
  assert.equal(await stock("LOTE001"), 5);
  assert.equal((await db.doc("configuracion/contadores_pedidos").get()).get("ultimo_numero"), 1);
});
test("doble confirmación y reintento mismo ID son idempotentes", async () => {
  const [a, b] = await Promise.all([confirm(), confirm()]);
  assert.deepEqual(a, b);
  assert.deepEqual(await confirm(), a);
  assert.equal(await orderCount(), 2);
  assert.equal(await stock("LOTE001"), 3);
  assert.deepEqual(await operationResult(db, "client-a", "operation-1"), a);
  assert.equal(await operationResult(db, "client-b", "operation-1"), null);
  await assert.rejects(confirm(request("operation-1", 3)), {code: "already-exists"});
});
test("no admite usuario inactivo, rol empleado, farmacia inactiva o relación ambigua", async () => {
  await assert.rejects(confirm(request(), "seller"), {code: "permission-denied"});
  await assert.rejects(confirm(request(), null), {code: "unauthenticated"});
  await db.doc("usuarios/client-a").update({estado: false});
  await assert.rejects(confirm(), {code: "permission-denied"});
  await db.doc("usuarios/client-a").update({estado: true});
  await db.doc("farmacia_cliente/FARM001").update({estado: false});
  await assert.rejects(confirm(), {code: "permission-denied"});
  await db.doc("farmacia_cliente/FARM001").update({estado: true});
  await db.doc("farmacia_cliente/DUP").set({usuario_id: "client-a", estado: true});
  await assert.rejects(confirm(), {code: "permission-denied"});
});
test("dirección ajena/inactiva y farmacia enviada arbitrariamente", async () => {
  await assert.rejects(confirm(request("foreign", 1, {addressId: "DIR002", pharmacyId: "FARM002"})), {code: "permission-denied"});
  const result = await confirm(request("ignored", 1, {pharmacyId: "FARM002", total: 1}));
  assert.equal((await db.doc(`pedidos/${result.orderId}`).get()).get("id_cliente"), "FARM001");
  await db.doc("direcciones/DIR001").update({estado: false});
  await assert.rejects(confirm(), {code: "permission-denied"});
});
test("contador no se crea automáticamente, FARM y PED001 se conservan", async () => {
  await db.doc("configuracion/contadores_pedidos").delete();
  await assert.rejects(confirm(), {code: "failed-precondition"});
  assert.equal((await db.doc("configuracion/contadores_farmacia").get()).get("ultimo_numero"), 2);
  assert.equal((await db.doc("pedidos/PED001").get()).get("total"), 150);
});

test("bloqueo del callable fuera de emuladores aunque el usuario esté autenticado", () => {
  const childEnv = {...process.env};
  delete childEnv.FUNCTIONS_EMULATOR;
  delete childEnv.FIRESTORE_EMULATOR_HOST;
  delete childEnv.FIREBASE_AUTH_EMULATOR_HOST;
  execFileSync(process.execPath, ["-e", `
    const assert = require('node:assert/strict');
    const functions = require('./src/index');
    Promise.all(Object.values(functions).map(fn => assert.rejects(async () => fn.run({auth:{uid:'client-a'},data:{}}), {code:'failed-precondition'})))
      .catch(() => {process.exitCode=1});
  `], {env: childEnv, stdio: "pipe"});
});

test("rules: inventario, precio, pedidos, operación y contador no admiten escritura del cliente", async () => {
  const client = env.authenticatedContext("client-a").firestore();
  for (const path of ["lotes_productos/LOTE001", "productos/PROD001", "pedidos/PED001", "usuarios/client-a/operaciones_pedido/fake", "configuracion/contadores_pedidos"]) {
    await assertFails(setDoc(doc(client, path), {cantidad_disponible: 999, total: 1}));
  }
  const unauth = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(unauth, "pedidos/PED001")));
});
test("rules: pedidos propios y subcolecciones visibles, ajenos no", async () => {
  const a = env.authenticatedContext("client-a").firestore();
  const b = env.authenticatedContext("client-b").firestore();
  await assertSucceeds(getDoc(doc(a, "pedidos/PED001")));
  await assertSucceeds(getDocs(collection(a, "pedidos/PED001/detalle_pedido")));
  await assertSucceeds(getDocs(query(collection(a, "pedidos"), where("id_cliente", "==", "FARM001"))));
  await assertFails(getDoc(doc(b, "pedidos/PED001")));
  await assertFails(getDocs(collection(b, "pedidos/PED001/detalle_pedido")));
  await assertFails(getDocs(collection(b, "pedidos/PED001/historial_estado")));
  await assertFails(getDocs(collection(a, "pedidos")));
});
test("rules: personal activo autorizado para lectura, sin acciones remotas", async () => {
  for (const uid of ["seller", "admin"]) {
    const client = env.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(client, "pedidos/PED001")));
    await assertFails(updateDoc(doc(client, "pedidos/PED001"), {estado: "aprobado"}));
  }
  const driver = env.authenticatedContext("driver").firestore();
  await assertFails(getDoc(doc(driver, "pedidos/PED001")));
  await db.doc("pedidos/PED001").update({repartidor_uid: "driver"});
  await assertSucceeds(getDoc(doc(driver, "pedidos/PED001")));
});
test("rules: direcciones exclusivamente propias y válidas", async () => {
  const client = env.authenticatedContext("client-a").firestore();
  const address = {id_cliente: "FARM001", nombre: "Nueva", direccion: "Av 123", referencia: "", latitud: null, longitud: null, estado: true};
  await assertFails(setDoc(doc(client, "direcciones/NEW"), address));
  await db.doc("direcciones/NEW").set(address);
  await assertFails(setDoc(doc(client, "direcciones/FOREIGN"), {...address, id_cliente: "FARM002"}));
  await assertFails(updateDoc(doc(client, "direcciones/NEW"), {id_cliente: "FARM002"}));
  await assertFails(getDoc(doc(client, "direcciones/DIR002")));
});
test("rules: registro FARM y NIT en la misma transacción sin regresiones", async () => {
  const client = env.authenticatedContext("new-client", {email: "new@example.com"}).firestore();
  const register = (nit) => runTransaction(client, async (tx) => {
    const counter = doc(client, "configuracion/contadores_farmacia");
    const old = await tx.get(counter);
    const number = old.get("ultimo_numero") + 1;
    const farmId = `FARM${String(number).padStart(3, "0")}`;
    tx.set(doc(client, "usuarios/new-client"), {correo: "new@example.com", nombre: "Nueva", rol: "cliente", estado: true, fecha_registro: serverTimestamp()});
    tx.set(doc(client, `farmacia_cliente/${farmId}`), {usuario_id: "new-client", nombre_farmacia: "Nueva", nit, responsable: "Nueva", telefono: "7", direccion_fiscal: "Av", estado: true, fecha_registro: serverTimestamp()});
    tx.set(doc(client, `nits_farmacia/${nit}`), {farmacia_id: farmId, usuario_id: "new-client"});
    tx.update(counter, {ultimo_numero: number, ultimo_id: farmId, ultimo_uid: "new-client"});
  });
  await assertSucceeds(register("123456789"));
  await assertFails(register("123456789"));
  await assertSucceeds(getDoc(doc(client, "productos/PROD001")));
  await assertSucceeds(getDoc(doc(client, "nits_farmacia/123456789")));
  await assertFails(updateDoc(doc(client, "nits_farmacia/123456789"), {farmacia_id: "FARM002"}));
});

test("callable autenticado en emuladores confirma y recupera resultado", async () => {
  const web = require("firebase/app");
  const auth = require("firebase/auth");
  const functions = require("firebase/functions");
  try { await getAuth(app).createUser({uid: "client-a", email: "cliente@example.com", password: "pharmalab123"}); }
  catch (e) { if (e.code !== "auth/uid-already-exists") throw e; }
  const clientApp = web.initializeApp({projectId, apiKey: "demo-key"}, "callable-test");
  try {
    const clientAuth = auth.getAuth(clientApp);
    auth.connectAuthEmulator(clientAuth, "http://127.0.0.1:9099", {disableWarnings: true});
    const fns = functions.getFunctions(clientApp);
    functions.connectFunctionsEmulator(fns, "127.0.0.1", 5001);
    await assert.rejects(functions.httpsCallable(fns, "confirmOrder")(request()), {code: "functions/unauthenticated"});
    await auth.signInWithEmailAndPassword(clientAuth, "cliente@example.com", "pharmalab123");
    const result = (await functions.httpsCallable(fns, "confirmOrder")(request())).data;
    const recovered = (await functions.httpsCallable(fns, "orderOperationResult")({operationId: "operation-1"})).data;
    assert.deepEqual(recovered, result);
    assert.equal(await stock("LOTE001"), 3);
  } finally { await web.deleteApp(clientApp); }
});
