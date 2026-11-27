"use strict";

const {performance} = require("node:perf_hooks");
const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {LIMITS, presentation, eligibleLots, allocate} = require("./inventory");
const {Metrics, boundedMap, instrumentTransaction} = require("./performance");
const SCHEMA = "transactional_multi_v1";

const fail = (code, message, details) => {
  throw new HttpsError(code, message, details);
};
const id = (value) => typeof value === "string" && /^[\w-]{1,128}$/.test(value);
const hash = (value) => createHash("sha256").update(value).digest("hex");
const text = (value) => typeof value === "string" ? value : "";

function validate(data) {
  if (!data || !id(data.operationId) || !id(data.addressId) ||
      !Array.isArray(data.items) || !data.items.length || data.items.length > 20 ||
      typeof data.notes !== "string" || data.notes.length > 500) {
    fail("invalid-argument", "Carrito, dirección u operación inválidos (máximo 20 productos).");
  }
  const seen = new Set();
  const items = data.items.map((item) => {
    const key = `${item?.productId}:${item?.presentationId || ""}`;
    if (!item || !id(item.productId) || seen.has(key) ||
        (item.presentationId != null && !id(item.presentationId)) ||
        !Number.isSafeInteger(item.quantity) || item.quantity <= 0 || item.quantity > 10000 ||
        !Number.isSafeInteger(item.expectedPriceCents) || item.expectedPriceCents <= 0) {
      fail("invalid-argument", "Producto, cantidad o precio de revisión inválido.");
    }
    seen.add(key);
    return {productId: item.productId, quantity: item.quantity,
      expectedPriceCents: item.expectedPriceCents,
      ...(item.presentationId ? {presentationId: item.presentationId} : {})};
  }).sort((a, b) => a.productId.localeCompare(b.productId) || (a.presentationId || "").localeCompare(b.presentationId || ""));
  return {operationId: data.operationId, addressId: data.addressId,
    notes: data.notes.trim(), items};
}

async function clientContext(tx, db, uid, operation, metrics = new Metrics()) {
  if (!uid) fail("unauthenticated", "Inicia sesión.");
  const docs = await metrics.measure("userOperationMs", () => tx.getAll(db.doc(`usuarios/${uid}`), ...(operation ? [operation] : [])));
  const user = docs[0];
  if (!user.exists || user.get("estado") !== true || user.get("rol") !== "cliente") {
    fail("permission-denied", "Se requiere un cliente activo.");
  }
  const farms = await metrics.measure("pharmacyMs", () => tx.get(db.collection("farmacia_cliente").where("usuario_id", "==", uid).limit(2)));
  if (farms.size !== 1 || farms.docs[0].get("estado") !== true) {
    fail("permission-denied", "La farmacia debe ser única, activa y pertenecer a la sesión.");
  }
  return {user: user.data(), farm: farms.docs[0], prior: docs[1]};
}

/** La única unidad de trabajo de confirmación. Todos los reads preceden los writes. */
async function confirmOrder(db, uid, input, {now = () => new Date(), beforeCommit, includeOrderSnapshot = false, metrics = new Metrics()} = {}) {
  if (!id(uid)) fail("unauthenticated", "Inicia sesión.");
  const data = validate(input);
  const fingerprint = hash(JSON.stringify(data));
  const operation = db.doc(`usuarios/${uid}/operaciones_pedido/${data.operationId}`);
  // El ID técnico no depende del contador y nunca colisiona con PED001.
  const orderRef = db.doc(`pedidos/ORD_${hash(`${uid}:${data.operationId}`)}`);
  let preparedAt;
  const transactionStart = performance.now();
  try { return await db.runTransaction(async (tx) => {
    tx = instrumentTransaction(tx, metrics);
    metrics.orderSnapshot = undefined;
    metrics.values.transactionAttempts = (metrics.values.transactionAttempts || 0) + 1;
    const {user, farm, prior} = await clientContext(tx, db, uid, operation, metrics);
    if (prior.exists) {
      if (prior.get("huella") !== fingerprint || !prior.get("resultado")) fail("already-exists", "La operación ya tiene otro contenido o contrato.");
      return prior.get("resultado");
    }
    if (user.tiene_deuda_vencida === true || farm.get("tiene_deuda_vencida") === true) {
      fail("failed-precondition", "Tu cuenta tiene deuda vencida. Contacta al vendedor.");
    }
    const productIds = [...new Set(data.items.map((item) => item.productId))];
    const [address, counter, existing, ...productDocs] = await metrics.measure("documentsMs", () => tx.getAll(
      db.doc(`direcciones/${data.addressId}`), db.doc("configuracion/contadores_pedidos"), orderRef,
      ...productIds.map((productId) => db.doc(`productos/${productId}`))));
    if (!address.exists || address.get("id_cliente") !== farm.id || address.get("estado") !== true) {
      fail("permission-denied", "Selecciona una dirección activa de tu farmacia.");
    }
    const last = counter.get("ultimo_numero");
    const commercialCode = (n) => `PED${String(n).padStart(3, "0")}`;
    if (!counter.exists || !Number.isSafeInteger(last) || last < 1 || last >= 999999999 ||
        counter.get("ultimo_id") !== commercialCode(last) || !id(counter.get("ultimo_documento_id"))) {
      fail("failed-precondition", "El contador de pedidos requiere preparación autorizada.");
    }
    if (existing.exists) fail("already-exists", "Identificador de pedido ocupado.");
    const time = now();
    const lines = [];
    const debits = new Map();
    const products = new Map(productDocs.map((doc) => [doc.id, doc]));
    for (const product of productDocs) if (!product.exists || product.get("estado") !== true) fail("failed-precondition", "Producto inactivo.");
    const categoryIds = [...new Set(productDocs.map((doc) => doc.get("categoria_id")).filter(id))];
    const [categoryDocs, batches] = await Promise.all([
      categoryIds.length ? metrics.measure("categoriesMs", () => tx.getAll(...categoryIds.map((value) => db.doc(`categorias/${value}`)))) : [],
      metrics.measure("lotsMs", () => boundedMap(productIds, 4, (productId) => tx.get(db.collection("lotes_productos").where("producto_id", "==", productId).limit(101)))),
    ]);
    const categoryNames = new Map(categoryDocs.map((doc) => [doc.id, text(doc.get("nombre"))]));
    const batchesByProduct = new Map(productIds.map((productId, index) => [productId, batches[index]]));
    const remainingByLot = new Map(), eligibleByProduct = new Map();
    metrics.values.products = productIds.length;
    metrics.values.lotsRead = batches.reduce((sum, batch) => sum + batch.size, 0);
    const prices = {};
    let totalCents = 0;
    for (const item of data.items) {
      const product = products.get(item.productId);
      products.set(item.productId, product);
      if (!product.exists || product.get("estado") !== true) fail("failed-precondition", "Producto inactivo.");
      const p = product.data();

      if (typeof p.requiere_vencimiento !== "boolean") fail("failed-precondition", "Falta definir la política de vencimiento del producto.");
      const choice = metrics.sync("presentationMs", () => presentation(p, item.presentationId));
      const cents = choice.cents;
      if (cents !== item.expectedPriceCents) prices[item.presentationId ? `${item.productId}:${item.presentationId}` : item.productId] = cents;
      const batches = batchesByProduct.get(item.productId);
      batchesByProduct.set(item.productId, batches);
      if (batches.size > 100) fail("resource-exhausted", "Demasiados lotes; requiere consolidación del inventario.");
      const eligible = eligibleByProduct.get(item.productId) ?? metrics.sync("fefoMs", () => eligibleLots(batches.docs.map((b) => ({id: b.id, ref: b.ref, data: b.data()})), p.requiere_vencimiento, time));
      eligibleByProduct.set(item.productId, eligible);
      const available = eligible.reduce((sum, b) => sum + (remainingByLot.has(b.id) ? remainingByLot.get(b.id) : b.data.cantidad_disponible), 0);
      const allocations = metrics.sync("allocationMs", () => allocate(eligible, item.quantity * choice.factor, remainingByLot));
      if (!allocations) fail("failed-precondition", `El stock de ${text(p.nombre) || item.productId} ha cambiado. Solicitaste ${item.quantity} ${choice.unit}, pero actualmente hay ${Math.floor(available / choice.factor)} disponibles.`,
        {productId: item.productId, requested: item.quantity, available: Math.floor(available / choice.factor)});
      for (const allocation of allocations) {
        const batch = eligible.find((b) => b.id === allocation.id_lote);
        debits.set(batch.id, batch);
      }
      totalCents += cents * item.quantity;
      if (!Number.isSafeInteger(totalCents) || totalCents > 1000000000) fail("invalid-argument", "Importe fuera del límite.");
      lines.push({id_producto: item.productId, cantidad: item.quantity,
        ...(item.presentationId ? {id_presentacion: item.presentationId} : {}),
        factor_inventario: choice.factor, cantidad_inventario: item.quantity * choice.factor, unidad_inventario: choice.mode,
        precio_unitario: cents / 100, subtotal: cents * item.quantity / 100,
        nombre: text(p.nombre), marca: text(p.marca), presentacion: choice.name,
        unidad_medida: choice.unit, categoria_id: text(p.categoria_id),
        ...(categoryNames.get(p.categoria_id) ? {categoria: categoryNames.get(p.categoria_id)} : {}),
        unidad_por_envase: p.unidad_por_envase || 0, asignaciones_lotes: allocations});
    }
    if (Object.keys(prices).length) fail("failed-precondition", "El precio cambió. Revisa el nuevo importe.", {prices});
    if (debits.size > LIMITS.usedLots || Buffer.byteLength(JSON.stringify(lines)) > 500000) fail("resource-exhausted", "Máximo 100 lotes utilizados y 500 KB de detalle. No se dividió el carrito.");
    const sequence = counter.get("ultimo_numero") + 1;
    if (!Number.isSafeInteger(sequence)) fail("resource-exhausted", "Contador agotado.");
    const number = commercialCode(sequence);
    const result = {orderId: orderRef.id, number, operationId: data.operationId};
    const stamp = Timestamp.fromDate(time);
    const delivery = {nombre: text(address.get("nombre")), direccion: text(address.get("direccion")),
      referencia: text(address.get("referencia")), latitud: address.get("latitud") ?? null,
      longitud: address.get("longitud") ?? null};
    if (!delivery.direccion.trim()) fail("failed-precondition", "La dirección no está completa.");
    const writesStart = performance.now();
    const orderData = {estado: "pendiente", fecha_pedido: stamp, id_cliente: farm.id,
      usuario_id: uid, id_direccion: address.id, total: totalCents / 100,
      numero_comercial: number, id_operacion: data.operationId, observaciones: data.notes,
      nombre_farmacia: text(farm.get("nombre_farmacia")), responsable: text(farm.get("responsable") || user.nombre),
      telefono: text(farm.get("telefono")), entrega: delivery, schema_version: SCHEMA, lineas: lines, stock_restituido: false};
    tx.create(orderRef, orderData);
    for (let i = 0; i < lines.length; i++) tx.create(orderRef.collection("detalle_pedido").doc(`DET${String(i + 1).padStart(3, "0")}`), lines[i]);
    tx.create(orderRef.collection("historial_estado").doc("confirmacion"), {
      estado_anterior: "pendiente", estado: "pendiente", fecha: stamp,
      operacion: "confirm", usuario_id: uid, rol: "cliente", nota: "Pedido confirmado; inventario descontado.",
    });
    for (const lot of debits.values()) {
      tx.update(lot.ref, {cantidad_disponible: remainingByLot.get(lot.id)});
      tx.create(orderRef.collection("movimientos_inventario").doc(`SALIDA_${lot.id}`), {
        id_lote: lot.id, id_producto: lot.data.producto_id,
        cantidad: remainingByLot.get(lot.id) - lot.data.cantidad_disponible, fecha: stamp, tipo: "confirmacion", usuario_id: uid,
      });
    }
    tx.update(counter.ref, {ultimo_numero: sequence, ultimo_id: number, ultimo_documento_id: orderRef.id});
    tx.create(operation, {huella: fingerprint, resultado: result, fecha: stamp, id_cliente: farm.id});
    metrics.values.lotsUsed = debits.size;
    metrics.values.documentWrites = 4 + lines.length + 2 * debits.size;
    metrics.values.prepareWritesMs = performance.now() - writesStart;
    preparedAt = performance.now();
    // Fallo de prueba después de preparar TODAS las escrituras: ninguna se aplica parcialmente.
    if (beforeCommit) await beforeCommit();
    if (includeOrderSnapshot) metrics.orderSnapshot = {...orderData, fecha_pedido: time.toISOString()};
    return result;
  }); } finally {
    metrics.values.transactionMs = performance.now() - transactionStart;
    if (preparedAt != null) metrics.values.commitAndRetryTailMs = performance.now() - preparedAt;
  }
}

async function operationResult(db, uid, operationId) {
  if (!id(operationId)) fail("invalid-argument", "Operación inválida.");
  return db.runTransaction(async (tx) => {
    await clientContext(tx, db, uid);
    const operation = await tx.get(db.doc(`usuarios/${uid}/operaciones_pedido/${operationId}`));
    return operation.exists ? operation.get("resultado") : null;
  });
}

module.exports = {confirmOrder, operationResult, SCHEMA};
