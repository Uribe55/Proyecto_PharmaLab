"use strict";
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const fail = (code, message, details) => { throw new HttpsError(code, message, details); };
const LIMITS = Object.freeze({lines: 20, lotsPerProduct: 100, usedLots: 100, quantity: 10000});
const dayBolivia = (date) => new Date(date.getTime() - 14400000).toISOString().slice(0, 10);
const money = (value) => {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0 || value > 1000000 ||
      Math.abs(value * 100 - Math.round(value * 100)) > 0.00001) fail("failed-precondition", "Precio inválido en el catálogo.");
  return Math.round(value * 100);
};
function presentation(product, presentationId) {
  // unidad_por_envase describe el contenido; no convierte el stock existente.
  if (!presentationId) {
    if (product.inventario_unidad === "base") fail("failed-precondition", "Selecciona una presentación autorizada.");
    return {factor: 1, cents: money(product.precio), name: product.presentacion || "",
      unit: product.unidadMedida || product.unidad_medida || "", mode: "comercial"};
  }
  if (product.inventario_unidad !== "base" || !Array.isArray(product.presentaciones_venta)) fail("failed-precondition", "Presentaciones no configuradas.");
  const matches = product.presentaciones_venta.filter((p) => p.id === presentationId), p = matches[0];
  if (matches.length !== 1 || p.estado !== true || !Number.isSafeInteger(p.unidades_base) ||
      p.unidades_base < 1 || p.unidades_base > 10000 || typeof p.nombre !== "string") fail("failed-precondition", "Presentación no disponible o ambigua.");
  return {factor: p.unidades_base, cents: money(p.precio), name: p.nombre, unit: p.unidad_medida || p.nombre, mode: "base"};
}
function eligibleLots(lots, requiresExpiry, now) {
  return lots.filter((lot) => {
    const p = lot.data, expiry = p.fecha_vencimiento;
    return p.estado !== false && p.bloqueado !== true && p.comercializable !== false &&
      Number.isSafeInteger(p.cantidad_disponible) && p.cantidad_disponible > 0 &&
      (!requiresExpiry || expiry instanceof Timestamp) &&
      (expiry == null || (expiry instanceof Timestamp && dayBolivia(expiry.toDate()) >= dayBolivia(now)));
  }).sort((a, b) => {
    const rank = (lot) => {
      const value = requiresExpiry ? lot.data.fecha_vencimiento : lot.data.fecha_ingreso ?? lot.data.fecha_creacion;
      return value instanceof Timestamp ? value.toMillis() : Number.MAX_SAFE_INTEGER;
    };
    return rank(a) - rank(b) || a.id.localeCompare(b.id);
  });
}
function allocate(lots, quantity, remaining) {
  let needed = quantity;
  const result = [];
  for (const lot of lots) {
    const available = remaining.has(lot.id) ? remaining.get(lot.id) : lot.data.cantidad_disponible;
    const used = Math.min(needed, available);
    if (used > 0) {
      result.push({id_lote: lot.id, cantidad: used});
      remaining.set(lot.id, available - used);
      needed -= used;
    }
    if (!needed) break;
  }
  return needed ? null : result;
}
module.exports = {LIMITS, fail, dayBolivia, money, presentation, eligibleLots, allocate};
