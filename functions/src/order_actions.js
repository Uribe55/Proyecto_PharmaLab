"use strict";
const {Timestamp} = require("firebase-admin/firestore");
const {fail, LIMITS} = require("./inventory");
const {SCHEMA} = require("./orders");
const validId = (v) => typeof v === "string" && /^[\w-]{1,128}$/.test(v);
const staff = (u) => ["vendedor", "administrador"].includes(u.rol);
async function actor(tx, db, uid) {
  if (!validId(uid)) fail("unauthenticated", "Inicia sesión.");
  const doc = await tx.get(db.doc(`usuarios/${uid}`));
  if (!doc.exists || doc.get("estado") !== true) fail("permission-denied", "Cuenta inactiva.");
  let employeeId;
  if (["vendedor", "repartidor"].includes(doc.get("rol"))) {
    const employees = await tx.get(db.collection("empleado").where("usuario_id", "==", uid).limit(2));
    const expected = doc.get("rol") === "vendedor" ? "Vendedor" : "Repartidor";
    if (employees.size !== 1 || employees.docs[0].get("estado") !== true || employees.docs[0].get("cargo") !== expected) {
      fail("permission-denied", "Empleado activo no identificado de forma única.");
    }
    employeeId = employees.docs[0].id;
  }
  return {...doc.data(), _employeeId: employeeId};
}
function event(tx, ref, name, before, after, uid, stamp, note = "") {
  tx.create(ref.collection("historial_estado").doc(name), {
    estado_anterior: before, estado_nuevo: after, id_usuario: uid, fecha_cambio: stamp, observaciones: note,
  });
}

async function cancelOrder(db, uid, input, {now = () => new Date(), beforeCommit} = {}) {
  const {orderId, action, reason = ""} = input || {};
  if (!validId(orderId) || !["cancel", "requestCancellation", "acceptCancellation", "rejectCancellation"].includes(action) ||
      typeof reason !== "string" || !reason.trim() || reason.length > 500) fail("invalid-argument", "Indica pedido, acción y motivo (hasta 500 caracteres).");
  return db.runTransaction(async (tx) => {
    const user = await actor(tx, db, uid), ref = db.doc(`pedidos/${orderId}`), snap = await tx.get(ref), o = snap.data();
    if (!o || o.schema_version !== SCHEMA) fail("failed-precondition", "Cancelación disponible solo para el contrato múltiple.");
    const own = user.rol === "cliente" && o.usuario_id === uid;
    if (own) {
      const farm = await tx.get(db.doc(`farmacia_cliente/${o.id_cliente}`));
      if (!farm.exists || farm.get("estado") !== true || farm.get("usuario_id") !== uid) fail("permission-denied", "Farmacia no autorizada.");
    }
    if (!(own && ["cancel", "requestCancellation"].includes(action)) && !(staff(user) && ["acceptCancellation", "rejectCancellation"].includes(action))) {
      fail("permission-denied", "Acción no autorizada.");
    }
    if (o.estado === "cancelado" && o.stock_restituido === true && ["cancel", "acceptCancellation"].includes(action)) return {orderId, state: "cancelado"};
    if (!["pendiente", "aprobado"].includes(o.estado) || o.fecha_logistica || o.fecha_despacho) fail("failed-precondition", "El pedido ya salió del almacén o está cerrado; no se restituye inventario.");
    const delivery = o.id_entrega ? await tx.get(db.doc(`entregas/${o.id_entrega}`)) : null;
    if (delivery?.exists && delivery.get("estado") !== "asignada") fail("failed-precondition", "La entrega ya comenzó.");
    const stamp = Timestamp.fromDate(now());
    if (action === "requestCancellation") {
      if (o.estado !== "aprobado") fail("failed-precondition", "Solo pedidos aprobados requieren solicitud.");
      if (o.solicitud_cancelacion?.estado === "pendiente") return {orderId, state: o.estado};
      tx.update(ref, {solicitud_cancelacion: {estado: "pendiente", motivo: reason.trim(), usuario_id: uid, fecha: stamp}});
      return {orderId, state: o.estado};
    }
    if (action === "rejectCancellation") {
      if (o.solicitud_cancelacion?.estado !== "pendiente") fail("failed-precondition", "No hay solicitud pendiente.");
      tx.update(ref, {solicitud_cancelacion: {...o.solicitud_cancelacion, estado: "rechazada", resuelto_por: uid, fecha_resolucion: stamp, resolucion: reason.trim()}});
      return {orderId, state: o.estado};
    }
    if ((action === "cancel" && o.estado !== "pendiente") ||
        (action === "acceptCancellation" && (o.estado !== "aprobado" || o.solicitud_cancelacion?.estado !== "pendiente"))) fail("failed-precondition", "Estado incompatible con la cancelación.");
    if (o.stock_restituido !== false || !Array.isArray(o.lineas)) fail("failed-precondition", "Revisa la trazabilidad antes de restituir.");
    const totals = new Map();
    for (const line of o.lineas) {
      let sum = 0;
      for (const allocation of line.asignaciones_lotes || []) {
        if (!validId(allocation.id_lote) || !Number.isSafeInteger(allocation.cantidad) || allocation.cantidad <= 0) fail("failed-precondition", "Asignación histórica inválida.");
        sum += allocation.cantidad;
        const prior = totals.get(allocation.id_lote);
        if (prior && prior.productId !== line.id_producto) fail("failed-precondition", "Lote compartido por productos distintos.");
        totals.set(allocation.id_lote, {productId: line.id_producto, quantity: (prior?.quantity || 0) + allocation.cantidad});
      }
      if (sum !== line.cantidad_inventario) fail("failed-precondition", "Asignaciones históricas incompletas.");
    }
    if (totals.size > LIMITS.usedLots || !totals.size) fail("failed-precondition", "Trazabilidad fuera de límites.");
    const lots = [];
    for (const [lotId, allocation] of totals) {
      const lot = await tx.get(db.doc(`lotes_productos/${lotId}`));
      const quantity = lot.get("cantidad_disponible");
      if (!lot.exists || lot.get("producto_id") !== allocation.productId || !Number.isSafeInteger(quantity) || quantity < 0 || !Number.isSafeInteger(quantity + allocation.quantity)) fail("failed-precondition", "Lote histórico no disponible; no se restituye a otro lote.");
      lots.push({lot, allocation, quantity});
    }
    for (const {lot, allocation, quantity} of lots) {
      tx.update(lot.ref, {cantidad_disponible: quantity + allocation.quantity});
      tx.create(ref.collection("movimientos_inventario").doc(`RESTITUCION_${lot.id}`), {id_lote: lot.id,
        id_producto: allocation.productId, cantidad: allocation.quantity, fecha: stamp, tipo: "cancelacion", usuario_id: uid});
    }
    tx.update(ref, {estado: "cancelado", stock_restituido: true, fecha_cancelacion: stamp, cancelado_por: uid,
      motivo_cancelacion: reason.trim(), ...(action === "acceptCancellation" ? {solicitud_cancelacion: {...o.solicitud_cancelacion, estado: "aceptada", resuelto_por: uid, fecha_resolucion: stamp}} : {})});
    if (delivery?.exists) tx.update(delivery.ref, {estado: "cancelada", fecha_estado: stamp});
    event(tx, ref, "CANCELACION", o.estado, "cancelado", uid, stamp, reason.trim());
    if (beforeCommit) await beforeCommit();
    return {orderId, state: "cancelado"};
  });
}

async function assignOrder(db, uid, input) {
  if (!validId(input?.orderId) || !validId(input?.employeeId)) fail("invalid-argument", "Pedido o empleado inválido.");
  return db.runTransaction(async (tx) => {
    const user = await actor(tx, db, uid);
    if (!staff(user)) fail("permission-denied", "Se requiere personal autorizado.");
    const ref = db.doc(`pedidos/${input.orderId}`), snap = await tx.get(ref), o = snap.data();
    if (!o || o.schema_version !== SCHEMA || o.estado !== "aprobado" || o.solicitud_cancelacion?.estado === "pendiente") fail("failed-precondition", "Pedido no disponible para asignación.");
    if (o.id_entrega) {
      const prior = await tx.get(db.doc(`entregas/${o.id_entrega}`));
      if (prior.get("id_repartidor") === input.employeeId) return {deliveryId: prior.id};
      fail("already-exists", "El pedido ya tiene una entrega asignada.");
    }
    const employee = await tx.get(db.doc(`empleado/${input.employeeId}`));
    const profile = employee.exists && validId(employee.get("usuario_id")) ? await tx.get(db.doc(`usuarios/${employee.get("usuario_id")}`)) : null;
    if (employee.get("estado") !== true || employee.get("cargo") !== "Repartidor" || profile?.get("estado") !== true || profile.get("rol") !== "repartidor") fail("failed-precondition", "Repartidor no disponible.");
    const delivery = db.doc(`entregas/MULTI_${snap.id}`), stamp = Timestamp.now();
    const products = o.lineas.map((line) => ({id_producto: line.id_producto, nombre: line.nombre,
      presentacion: line.presentacion, cantidad: line.cantidad, unidad_medida: line.unidad_medida}));
    tx.create(delivery, {schema_version: "transactional_logistics_v1", estado: "asignada", fecha_creacion: stamp,
      fecha_programada: null, id_pedido: snap.id, id_repartidor: employee.id, repartidor_uid: profile.id,
      asignado_por: uid, numero_comercial: `ENT-${o.numero_comercial}`, pedido_numero: o.numero_comercial,
      farmacia: o.nombre_farmacia, contacto: o.responsable, telefono: o.telefono,
      direccion: o.entrega.direccion, referencia: o.entrega.referencia, productos: products});
    for (let i = 0; i < products.length; i++) tx.create(delivery.collection("detalle_entrega").doc(`DENT${String(i + 1).padStart(3, "0")}`), {
      ...products[i], cantidad_programada: products[i].cantidad, cantidad_entregada: 0});
    tx.update(ref, {id_entrega: delivery.id});
    return {deliveryId: delivery.id};
  });
}

async function transitionDelivery(db, uid, input) {
  const {deliveryId, state, reason = "", note = ""} = input || {};
  if (!validId(deliveryId) || !["en_ruta", "entregado", "fallida"].includes(state) || typeof reason !== "string" || typeof note !== "string" ||
      reason.length > 100 || note.length > 180 || (state === "fallida" && !reason.trim())) fail("invalid-argument", "Transición o motivo inválido.");
  return db.runTransaction(async (tx) => {
    const user = await actor(tx, db, uid), ref = db.doc(`entregas/${deliveryId}`), snap = await tx.get(ref), d = snap.data();
    if (!d || d.schema_version !== "transactional_logistics_v1" || user.rol !== "repartidor" || d.repartidor_uid !== uid || d.id_repartidor !== user._employeeId) fail("permission-denied", "Entrega no autorizada.");
    const order = db.doc(`pedidos/${d.id_pedido}`), orderSnap = await tx.get(order), o = orderSnap.data();
    if (!o || o.schema_version !== SCHEMA || o.id_entrega !== deliveryId || o.stock_restituido === true) fail("failed-precondition", "Pedido incompatible.");
    if (d.estado === state && o.estado === state) return {deliveryId, state};
    const before = state === "en_ruta" ? "asignada" : "en_ruta";
    if (d.estado !== before || o.estado !== (before === "asignada" ? "aprobado" : "en_ruta") || o.solicitud_cancelacion?.estado === "pendiente") fail("failed-precondition", "La entrega cambió; actualiza la vista.");
    const details = state === "entregado" ? await tx.get(ref.collection("detalle_entrega")) : null;
    const stamp = Timestamp.now();
    tx.update(ref, {estado: state, fecha_estado: stamp, motivo: reason.trim(), observacion: note.trim()});
    tx.update(order, {estado: state, fecha_logistica: stamp, ...(state === "en_ruta" ? {fecha_despacho: stamp} : {})});
    event(tx, order, `LOG_${state}`, o.estado, state, uid, stamp, `${reason.trim()} ${note.trim()}`.trim());
    for (const detail of details?.docs || []) tx.update(detail.ref, {cantidad_entregada: detail.get("cantidad_programada")});
    return {deliveryId, state};
  });
}
async function approveOrder(db, uid, input) {
  if (!validId(input?.orderId)) fail("invalid-argument", "Pedido inválido.");
  return db.runTransaction(async (tx) => {
    const user = await actor(tx, db, uid);
    if (!staff(user)) fail("permission-denied", "Se requiere personal autorizado.");
    const ref = db.doc(`pedidos/${input.orderId}`), snap = await tx.get(ref), order = snap.data();
    if (!order || order.schema_version !== SCHEMA) fail("failed-precondition", "Contrato de pedido incompatible.");
    if (order.estado === "aprobado") return {orderId: ref.id, state: "aprobado"};
    if (order.estado !== "pendiente" || order.stock_restituido !== false) fail("failed-precondition", "Pedido no disponible para aprobación.");
    const stamp = Timestamp.now();
    tx.update(ref, {estado: "aprobado", aprobado_por: uid, fecha_aprobacion: stamp});
    event(tx, ref, "APROBACION", "pendiente", "aprobado", uid, stamp);
    return {orderId: ref.id, state: "aprobado"};
  });
}
module.exports = {cancelOrder, assignOrder, transitionDelivery, approveOrder};
