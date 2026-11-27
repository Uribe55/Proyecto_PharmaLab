"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {eligibleLots, allocate, presentation} = require("../src/inventory");
const lot = (id, data) => ({id, data: {cantidad_disponible: 10, ...data}});
test("FIFO: fechas válidas primero, luego ID determinista sin fecha", () => {
  const stamp = Timestamp.fromDate(new Date("2027-01-01T04:00:00Z"));
  const input = [lot("Z", {}), lot("B", {}), lot("A", {fecha_ingreso: stamp})];
  assert.deepEqual(eligibleLots(input, false, new Date()).map((l) => l.id), ["A", "B", "Z"]);
});
test("FEFO/FIFO descartan fecha inválida, vencimiento, bloqueo y lote inactivo", () => {
  const input = [lot("bad", {fecha_vencimiento: "2030"}), lot("expired", {fecha_vencimiento: Timestamp.fromMillis(0)}),
    lot("inactive", {estado: false}), lot("blocked", {bloqueado: true}), lot("no-sale", {comercializable: false})];
  assert.deepEqual(eligibleLots(input, false, new Date()), []);
});
test("contenido por caja no multiplica el stock comercial antiguo", () => {
  assert.equal(presentation({precio: 150, unidad_por_envase: 20}, null).factor, 1);
});
test("asignaciones comparten el mismo saldo entre presentaciones", () => {
  const input = [lot("A", {cantidad_disponible: 30}), lot("B", {cantidad_disponible: 70})], remaining = new Map();
  assert.deepEqual(allocate(input, 30, remaining), [{id_lote: "A", cantidad: 30}]);
  assert.deepEqual(allocate(input, 40, remaining), [{id_lote: "B", cantidad: 40}]);
  assert.equal(remaining.get("B"), 30);
});
