"use strict";
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {confirmOrder, operationResult} = require("./orders");
const {cancelOrder, assignOrder, transitionDelivery} = require("./order_actions");
initializeApp();

function emulatorOnly(request) {
  // Bloqueo deliberado: ni un dart-define ni desplegar por accidente habilitan producción.
  if (process.env.FUNCTIONS_EMULATOR !== "true" || !process.env.FIRESTORE_EMULATOR_HOST ||
      !process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.GCLOUD_PROJECT !== "demo-pharmalab" ||
      !/^(127\.0\.0\.1|localhost):8080$/.test(process.env.FIRESTORE_EMULATOR_HOST) ||
      !/^(127\.0\.0\.1|localhost):9099$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
    throw new HttpsError("failed-precondition", "Backend múltiple disponible solo en emuladores del proyecto demo-pharmalab.");
  }
  if (!request.auth) throw new HttpsError("unauthenticated", "Inicia sesión.");
  return request.auth.uid;
}
exports.confirmOrder = onCall({region: "us-central1", maxInstances: 5}, (request) =>
  confirmOrder(getFirestore(), emulatorOnly(request), request.data));
exports.orderOperationResult = onCall({region: "us-central1", maxInstances: 5}, (request) =>
  operationResult(getFirestore(), emulatorOnly(request), request.data.operationId));
exports.cancelOrder = onCall({region: "us-central1", maxInstances: 5}, (request) =>
  cancelOrder(getFirestore(), emulatorOnly(request), request.data));
exports.assignMultiOrder = onCall({region: "us-central1", maxInstances: 5}, (request) =>
  assignOrder(getFirestore(), emulatorOnly(request), request.data));
exports.transitionMultiDelivery = onCall({region: "us-central1", maxInstances: 5}, (request) =>
  transitionDelivery(getFirestore(), emulatorOnly(request), request.data));
