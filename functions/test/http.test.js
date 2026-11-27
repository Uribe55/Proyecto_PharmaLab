"use strict";
const {test, before, beforeEach, after} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, setDoc, updateDoc, getDoc, writeBatch, serverTimestamp} = require("firebase/firestore");
const {createServer} = require("../src/http_app");
const {configuration} = require("../src/server");
assert.match(process.env.FIRESTORE_EMULATOR_HOST || "", /^127\.0\.0\.1:8080$/);
assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST || "", /^127\.0\.0\.1:9099$/);
const projectId = "demo-pharmalab", app = initializeApp({projectId}, "http-test");
const db = getFirestore(app), identities = {};
let server, base, env;
async function call(path, role = "cliente", body, extra = {}) {
  const response = await fetch(base + path, {method: body === undefined ? "GET" : "POST",
    headers: {Authorization: `Bearer ${identities[role]?.token || role}`, "Content-Type": "application/json", ...extra},
    ...(body === undefined ? {} : {body: JSON.stringify(body)})});
  return {status: response.status, timing: response.headers.get('server-timing'), body: await response.json()};
}
const order = (operationId = "operation-http", quantity = 7) => ({operationId, addressId: "DIR001", notes: "",
  items: [{productId: "P1", quantity, expectedPriceCents: 1000}, {productId: "P2", quantity: 1, expectedPriceCents: 2000}]});
before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {host: "127.0.0.1", port: 8080,
    rules: fs.readFileSync("../firestore.render.rules", "utf8")}});
  for (const role of ["cliente", "vendedor", "repartidor", "administrador", "otro", "otro_repartidor"]) {
    const response = await fetch("http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key", {
      method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({returnSecureToken: true})});
    const data = await response.json();
    assert.ok(data.idToken);
    identities[role] = {uid: data.localId, token: data.idToken};
  }
  server = createServer({db, auth: getAuth(app), limit: 600});
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
beforeEach(async () => {
  await env.clearFirestore();
  const batch = db.batch();
  for (const [role, identity] of Object.entries(identities)) batch.set(db.doc(`usuarios/${identity.uid}`), {rol: role === "otro" ? "cliente" : role === "otro_repartidor" ? "repartidor" : role, estado: true});
  for (const role of ["vendedor", "repartidor", "otro_repartidor"]) batch.set(db.doc(`empleado/${role}`), {usuario_id: identities[role].uid, cargo: role === "vendedor" ? "Vendedor" : "Repartidor", estado: true});
  for (const [path, data] of Object.entries({
    "farmacia_cliente/FARM001": {usuario_id: identities.cliente.uid, estado: true, nombre_farmacia: "Prueba", responsable: "Cliente", telefono: "123"},
    "direcciones/DIR001": {id_cliente: "FARM001", direccion: "Calle", referencia: "", estado: true},
    "configuracion/contadores_pedidos": {ultimo_numero: 1, ultimo_id: "PED001", ultimo_documento_id: "PED001"},
    "productos/P1": {nombre: "Uno", precio: 10, estado: true, requiere_vencimiento: true, presentacion: "Caja", unidadMedida: "caja"},
    "productos/P2": {nombre: "Dos", precio: 20, estado: true, requiere_vencimiento: true, presentacion: "Caja", unidadMedida: "caja"},
    "lotes_productos/L1": {producto_id: "P1", cantidad_disponible: 5, fecha_vencimiento: Timestamp.fromDate(new Date("2035-01-01"))},
    "lotes_productos/L2": {producto_id: "P1", cantidad_disponible: 5, fecha_vencimiento: Timestamp.fromDate(new Date("2036-01-01"))},
    "lotes_productos/L3": {producto_id: "P2", cantidad_disponible: 20, fecha_vencimiento: Timestamp.fromDate(new Date("2035-01-01"))},
    "lotes_productos/EXPIRED": {producto_id: "P1", cantidad_disponible: 50, fecha_vencimiento: Timestamp.fromDate(new Date("2000-01-01"))},
  })) batch.set(db.doc(path), data);
  await batch.commit();
});
after(async () => { if (server) await new Promise((resolve) => server.close(resolve)); await env?.cleanup(); await deleteApp(app); });

test("configuración cerrada: pruebas nunca usan credenciales/base operacional", () => {
  assert.throws(() => configuration({PHARMALAB_ENV: "test", FIREBASE_PROJECT_ID: "proyecto-pharmalab"}));
  assert.throws(() => configuration({PHARMALAB_ENV: "production", NODE_ENV: "production", FIREBASE_PROJECT_ID: "proyecto-pharmalab", GOOGLE_APPLICATION_CREDENTIALS: "secret", FIRESTORE_EMULATOR_HOST: "localhost:8080"}));
  assert.throws(() => configuration({}));
  assert.equal(configuration({PHARMALAB_ENV: "test", FIREBASE_PROJECT_ID: projectId, FIRESTORE_EMULATOR_HOST: "localhost:8080", FIREBASE_AUTH_EMULATOR_HOST: "localhost:9099"}).production, false);
});
test("health no consulta Firebase; errores no exponen detalles internos", async () => {
  const health = createServer({db: {}, auth: {}});
  await new Promise((resolve) => health.listen(0, "127.0.0.1", resolve));
  try { assert.deepEqual(await (await fetch(`http://127.0.0.1:${health.address().port}/health`)).json(), {status: "ok"}); }
  finally { await new Promise((resolve) => health.close(resolve)); }
  assert.equal((await call("/api/orders", "invalid", order())).status, 401);
  assert.equal((await call("/api/orders", "vendedor", order())).status, 403);
  await db.doc(`usuarios/${identities.cliente.uid}`).update({estado: false});
  assert.equal((await call("/api/orders", "cliente", order())).status, 403);
});
test("HTTP real: dos productos, FEFO, lotes múltiples, idempotencia y recuperación", async () => {
  const response = await call("/api/orders", "cliente", order()); assert.equal(response.status, 200);
  assert.equal(response.body.order.lineas.length, 2);
  assert.equal(response.body.order.estado, 'pendiente');
  assert.ok(typeof response.body.order.fecha_pedido === 'string');
  assert.match(response.timing, /processing;dur=[0-9.]+/);
  const result = response.body.data;
  assert.equal((await db.doc("lotes_productos/L1").get()).get("cantidad_disponible"), 0);
  assert.equal((await db.doc("lotes_productos/L2").get()).get("cantidad_disponible"), 3);
  assert.equal((await db.doc("lotes_productos/EXPIRED").get()).get("cantidad_disponible"), 50);
  assert.deepEqual((await call("/api/orders", "cliente", order())).body.data, result);
  assert.deepEqual((await call("/api/operations/operation-http")).body.data, result);
  assert.equal((await call("/api/orders", "cliente", order("operation-http", 8))).status, 409);
  assert.equal((await call("/api/operations/operation-http", "otro")).status, 403);
});
test("precio manipulado y compras concurrentes no sobrevendidas", async () => {
  const manipulated = order(); manipulated.items[0].expectedPriceCents = 1;
  assert.equal((await call("/api/orders", "cliente", manipulated)).status, 412);
  const responses = await Promise.all([call("/api/orders", "cliente", order("race-a")), call("/api/orders", "cliente", order("race-b"))]);
  assert.deepEqual(responses.map((v) => v.status).sort(), [200, 412]);
});
test("cancelación restaura exactamente cada lote una vez y verifica propietario", async () => {
  const id = (await call("/api/orders", "cliente", order())).body.data.orderId;
  const path = `/api/orders/${id}/cancel`, body = {action: "cancel", reason: "Prueba"};
  assert.equal((await call(path, "otro", body)).status, 403);
  assert.equal((await call(path, "cliente", body)).status, 200);
  assert.equal((await call(path, "cliente", body)).status, 200);
  for (const lot of ["L1", "L2"]) assert.equal((await db.doc(`lotes_productos/${lot}`).get()).get("cantidad_disponible"), 5);
});
test("cuatro roles: aprobación, asignación y entrega; empleado bloqueado rechazado", async () => {
  const id = (await call("/api/orders", "cliente", order())).body.data.orderId;
  assert.equal((await call(`/api/orders/${id}/approve`, "cliente", {})).status, 403);
  assert.equal((await call(`/api/orders/${id}/approve`, "administrador", {})).status, 200);
  await db.doc("empleado/vendedor").update({estado: false});
  assert.equal((await call(`/api/orders/${id}/assign`, "vendedor", {employeeId: "repartidor"})).status, 403);
  await db.doc("empleado/vendedor").update({estado: true});
  const assigned = await call(`/api/orders/${id}/assign`, "vendedor", {employeeId: "repartidor"}); assert.equal(assigned.status, 200);
  const driverDb = env.authenticatedContext(identities.repartidor.uid).firestore();
  await assertSucceeds(getDoc(doc(driverDb, `entregas/${assigned.body.data.deliveryId}`)));
  await assertFails(getDoc(doc(driverDb, `pedidos/${id}`))); // El repartidor no recibe precios.
  const path = `/api/deliveries/${assigned.body.data.deliveryId}/transition`;
  assert.equal((await call(path, "cliente", {state: "en_ruta"})).status, 403);
  assert.equal((await call(path, "otro_repartidor", {state: "en_ruta"})).status, 403);
  assert.equal((await call(path, "repartidor", {state: "entregado"})).status, 412);
  assert.equal((await call(path, "repartidor", {state: "en_ruta"})).status, 200);
  assert.equal((await call(path, "repartidor", {state: "en_ruta"})).status, 200);
  const enRoute = await db.doc(`pedidos/${id}`).get();
  assert.equal(enRoute.get('estado'), 'en_ruta');
  assert.ok(enRoute.get('fecha_despacho'));
  assert.equal((await db.doc('lotes_productos/L2').get()).get('cantidad_disponible'), 3);
  assert.equal((await call(path, "repartidor", {state: "entregado"})).status, 200);
});
test("reglas Render bloquean bypass de clientes y conservan lectura de roles", async () => {
  const result = await call("/api/orders", "cliente", order()), id = result.body.data.orderId;
  for (const role of ["cliente", "vendedor", "administrador"]) {
    const client = env.authenticatedContext(identities[role].uid).firestore();
    await assertSucceeds(getDoc(doc(client, `pedidos/${id}`)));
    await assertFails(setDoc(doc(client, "pedidos/falso"), {schema_version: "transactional_multi_v1"}));
    await assertFails(updateDoc(doc(client, `pedidos/${id}`), {total: 1}));
    const batch = writeBatch(client);
    batch.update(doc(client, `pedidos/${id}`), {estado: "aprobado", aprobado_por: identities[role].uid, fecha_aprobacion: serverTimestamp()});
    batch.set(doc(client, `pedidos/${id}/historial_estado/APROBACION`), {estado_anterior: "pendiente", estado_nuevo: "aprobado", id_usuario: identities[role].uid, fecha_cambio: serverTimestamp()});
    await assertFails(batch.commit());
  }
  const client = env.authenticatedContext(identities.cliente.uid).firestore();
  await assertFails(updateDoc(doc(client, "lotes_productos/L1"), {cantidad_disponible: 100}));
});
test("límite de cuerpo, CORS y límite por usuario", async () => {
  assert.equal((await call("/api/orders", "cliente", {...order(), notes: "x".repeat(70000)})).status, 400);
  assert.equal((await call("/api/orders", "cliente", order(), {Origin: "https://malicioso.invalid"})).status, 403);
  const limited = createServer({db, auth: getAuth(app), limit: 1});
  await new Promise((resolve) => limited.listen(0, "127.0.0.1", resolve));
  try {
    const url = `http://127.0.0.1:${limited.address().port}/api/operations/missing`;
    const headers = {Authorization: `Bearer ${identities.cliente.token}`};
    assert.equal((await fetch(url, {headers})).status, 200);
    assert.equal((await fetch(url, {headers})).status, 429);
  } finally { await new Promise((resolve) => limited.close(resolve)); }
});

test("respuesta perdida después del commit se recupera sin duplicar el pedido", async () => {
  let socket, interrupted = false;
  const transportDb = {doc: db.doc.bind(db), collection: db.collection.bind(db), runTransaction: async (fn) => {
    const result = await db.runTransaction(fn);
    if (!interrupted) { interrupted = true; socket.destroy(); }
    return result;
  }};
  const interruptedServer = createServer({db: transportDb, auth: getAuth(app)});
  interruptedServer.on("request", (request) => { socket = request.socket; });
  await new Promise((resolve) => interruptedServer.listen(0, "127.0.0.1", resolve));
  try {
    const url = `http://127.0.0.1:${interruptedServer.address().port}/api/orders`;
    await assert.rejects(fetch(url, {method: "POST", headers: {Authorization: `Bearer ${identities.cliente.token}`, "Content-Type": "application/json"}, body: JSON.stringify(order("lost-response"))}));
    const recovered = await call("/api/operations/lost-response");
    assert.ok(recovered.body.data.orderId);
    assert.deepEqual((await call("/api/orders", "cliente", order("lost-response"))).body.data, recovered.body.data);
    assert.equal((await db.collection("pedidos").get()).size, 1);
    assert.equal((await db.doc("lotes_productos/L2").get()).get("cantidad_disponible"), 3);
  } finally { await new Promise((resolve) => interruptedServer.close(resolve)); }
});

test("npm start ejecuta el servidor real con configuración demo segura", async () => {
  const {execFile} = require("node:child_process");
  const output = await new Promise((resolve, reject) => execFile(process.execPath,
    [process.env.npm_execpath, "start", "--", "--smoke-test"], {
      env: {...process.env, PHARMALAB_ENV: "test", NODE_ENV: "test", FIREBASE_PROJECT_ID: projectId, PORT: "3017", GOOGLE_APPLICATION_CREDENTIALS: ""},
      timeout: 20000,
    }, (error, stdout) => error ? reject(error) : resolve(stdout)));
  assert.match(output, /npm start smoke: \/health OK/);
});
