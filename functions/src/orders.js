"use strict";

const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const fail = (code, message, details) => {
  throw new HttpsError(code, message, details);
};
const id = (value) => typeof value === "string" && /^[\w-]{1,128}$/.test(value);
const money = (value) => {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0 ||
      Math.abs(value * 100 - Math.round(value * 100)) > 0.00001) {
    fail("failed-precondition", "Precio inválido en el catálogo.");
  }
  return Math.round(value * 100);
};
const hash = (value) => createHash("sha256").update(value).digest("hex");
const text = (value) => typeof value === "string" ? value : "";

function validate(data) {
  if (!data || !id(data.operationId) || !id(data.addressId) ||
      !Array.isArray(data.items) || !data.items.length || data.items.length > 20 ||
      typeof data.notes !== "string" || data.notes.length > 1000) {
    fail("invalid-argument", "Carrito, dirección u operación inválidos (máximo 20 productos).");
  }
  const seen = new Set();
  const items = data.items.map((item) => {
    if (!item || !id(item.productId) || seen.has(item.productId) ||
        !Number.isSafeInteger(item.quantity) || item.quantity <= 0 || item.quantity > 10000 ||
        !Number.isSafeInteger(item.expectedPriceCents) || item.expectedPriceCents <= 0) {
      fail("invalid-argument", "Producto, cantidad o precio de revisión inválido.");
    }
    seen.add(item.productId);
    return {productId: item.productId, quantity: item.quantity,
      expectedPriceCents: item.expectedPriceCents};
  }).sort((a, b) => a.productId.localeCompare(b.productId));
  return {operationId: data.operationId, addressId: data.addressId,
    notes: data.notes.trim(), items};
}

// Día comercial boliviano, independiente del huso horario de la máquina.
function dayBolivia(date) {
  return new Date(date.getTime() - 4 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

async function clientContext(tx, db, uid) {
  if (!uid) fail("unauthenticated", "Inicia sesión.");
  const user = await tx.get(db.doc(`usuarios/${uid}`));
  if (!user.exists || user.get("estado") !== true || user.get("rol") !== "cliente") {
    fail("permission-denied", "Se requiere un cliente activo.");
  }
  const farms = await tx.get(db.collection("farmacia_cliente").where("usuario_id", "==", uid).limit(2));
  if (farms.size !== 1 || farms.docs[0].get("estado") !== true) {
    fail("permission-denied", "La farmacia debe ser única, activa y pertenecer a la sesión.");
  }
  return {user: user.data(), farm: farms.docs[0]};
}

/** La única unidad de trabajo de confirmación. Todos los reads preceden los writes. */
async function confirmOrder(db, uid, input, {now = () => new Date(), beforeCommit} = {}) {
  const data = validate(input);
  const fingerprint = hash(JSON.stringify(data));
  const operation = db.doc(`usuarios/${uid}/operaciones_pedido/${data.operationId}`);
  // El ID técnico no depende del contador y nunca colisiona con PED001.
  const orderRef = db.doc(`pedidos/ORD_${hash(`${uid}:${data.operationId}`)}`);
  return db.runTransaction(async (tx) => {
    const {user, farm} = await clientContext(tx, db, uid);
    const prior = await tx.get(operation);
    if (prior.exists) {
      if (prior.get("huella") !== fingerprint) fail("already-exists", "La operación ya tiene otro contenido.");
      return prior.get("resultado");
    }
    const address = await tx.get(db.doc(`direcciones/${data.addressId}`));
    if (!address.exists || address.get("id_cliente") !== farm.id || address.get("estado") !== true) {
      fail("permission-denied", "Selecciona una dirección activa de tu farmacia.");
    }
    const counter = await tx.get(db.doc("configuracion/contadores_pedidos"));
    if (!counter.exists || !Number.isSafeInteger(counter.get("ultimo_numero")) || counter.get("ultimo_numero") < 0) {
      fail("failed-precondition", "El contador de pedidos requiere preparación autorizada.");
    }
    if ((await tx.get(orderRef)).exists) fail("already-exists", "Identificador de pedido ocupado.");
    const time = now();
    const lines = [];
    const debits = [];
    const prices = {};
    let totalCents = 0;
    for (const item of data.items) {
      const product = await tx.get(db.doc(`productos/${item.productId}`));
      if (!product.exists || product.get("estado") !== true) fail("failed-precondition", "Producto inactivo.");
      const p = product.data();
      if (typeof p.requiere_vencimiento !== "boolean") fail("failed-precondition", "Falta definir la política de vencimiento del producto.");
      const cents = money(p.precio);
      if (cents !== item.expectedPriceCents) prices[item.productId] = cents;
      const batches = await tx.get(db.collection("lotes_productos").where("producto_id", "==", item.productId).limit(101));
      if (batches.size > 100) fail("resource-exhausted", "Demasiados lotes; requiere consolidación del inventario.");
      // FEFO si exige vencimiento; en otro caso FIFO de ingreso, ID como desempate.
      const eligible = batches.docs.filter((b) => {
        const expiry = b.get("fecha_vencimiento");
        if (p.requiere_vencimiento === true && !(expiry instanceof Timestamp)) return false;
        if (expiry != null && !(expiry instanceof Timestamp)) return false;
        if (expiry && dayBolivia(expiry.toDate()) < dayBolivia(time)) return false;
        return Number.isSafeInteger(b.get("cantidad_disponible")) && b.get("cantidad_disponible") > 0;
      }).sort((a, b) => {
        const field = p.requiere_vencimiento === true ? "fecha_vencimiento" : "fecha_ingreso";
        const millis = (doc) => doc.get(field) instanceof Timestamp ? doc.get(field).toMillis() : 0;
        return millis(a) - millis(b) || a.id.localeCompare(b.id);
      });
      let remaining = item.quantity;
      const allocations = [];
      for (const batch of eligible) {
        const quantity = Math.min(remaining, batch.get("cantidad_disponible"));
        if (!quantity) break;
        debits.push({ref: batch.ref, available: batch.get("cantidad_disponible") - quantity});
        allocations.push({id_lote: batch.id, cantidad: quantity});
        remaining -= quantity;
      }
      if (remaining) fail("failed-precondition", "Stock insuficiente.", {productId: item.productId});
      totalCents += cents * item.quantity;
      if (!Number.isSafeInteger(totalCents) || totalCents > 1000000000) fail("invalid-argument", "Importe fuera del límite.");
      lines.push({id_producto: item.productId, cantidad: item.quantity,
        precio_unitario: cents / 100, subtotal: cents * item.quantity / 100,
        nombre: text(p.nombre), marca: text(p.marca), presentacion: text(p.presentacion),
        unidad_medida: text(p.unidadMedida || p.unidad_medida),
        unidad_por_envase: p.unidad_por_envase || 0, asignaciones_lotes: allocations});
    }
    if (Object.keys(prices).length) fail("failed-precondition", "El precio cambió. Revisa el nuevo importe.", {prices});
    if (debits.length > 300) fail("resource-exhausted", "El pedido utiliza demasiados lotes.");
    const sequence = counter.get("ultimo_numero") + 1;
    if (!Number.isSafeInteger(sequence)) fail("resource-exhausted", "Contador agotado.");
    const number = `PL-${dayBolivia(time).slice(0, 4)}-${String(sequence).padStart(6, "0")}`;
    const result = {orderId: orderRef.id, number, operationId: data.operationId};
    const stamp = Timestamp.fromDate(time);
    const delivery = {nombre: text(address.get("nombre")), direccion: text(address.get("direccion")),
      referencia: text(address.get("referencia")), latitud: address.get("latitud") ?? null,
      longitud: address.get("longitud") ?? null};
    if (!delivery.direccion.trim()) fail("failed-precondition", "La dirección no está completa.");
    tx.create(orderRef, {estado: "pendiente", fecha_pedido: stamp, id_cliente: farm.id,
      usuario_id: uid, id_direccion: address.id, total: totalCents / 100,
      numero_comercial: number, id_operacion: data.operationId, observaciones: data.notes,
      nombre_farmacia: text(farm.get("nombre_farmacia")), responsable: text(farm.get("responsable") || user.nombre),
      telefono: text(farm.get("telefono")), entrega: delivery, version_esquema: 1});
    for (const line of lines) tx.create(orderRef.collection("detalle_pedido").doc(line.id_producto), line);
    tx.create(orderRef.collection("historial_estado").doc("confirmacion"), {
      estado_anterior: "pendiente", estado: "pendiente", fecha: stamp,
      operacion: "confirm", usuario_id: uid, rol: "cliente", nota: "Pedido confirmado; inventario descontado.",
    });
    for (const debit of debits) tx.update(debit.ref, {cantidad_disponible: debit.available});
    tx.update(counter.ref, {ultimo_numero: sequence});
    tx.create(operation, {huella: fingerprint, resultado: result, fecha: stamp, id_cliente: farm.id});
    // Fallo de prueba después de preparar TODAS las escrituras: ninguna se aplica parcialmente.
    if (beforeCommit) await beforeCommit();
    return result;
  });
}

async function operationResult(db, uid, operationId) {
  if (!id(operationId)) fail("invalid-argument", "Operación inválida.");
  return db.runTransaction(async (tx) => {
    await clientContext(tx, db, uid);
    const operation = await tx.get(db.doc(`usuarios/${uid}/operaciones_pedido/${operationId}`));
    return operation.exists ? operation.get("resultado") : null;
  });
}

module.exports = {confirmOrder, operationResult};
