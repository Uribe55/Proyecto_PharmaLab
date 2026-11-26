"use strict";
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {confirmOrder, operationResult} = require("./orders");
initializeApp();

function emulatorOnly(request) {
  // Bloqueo deliberado: ni un dart-define ni desplegar por accidente habilitan producción.
  if (process.env.FUNCTIONS_EMULATOR !== "true" || !process.env.FIRESTORE_EMULATOR_HOST ||
      !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new HttpsError("failed-precondition", "Compras de producción deshabilitadas en etapa 5.");
  }
  if (!request.auth) throw new HttpsError("unauthenticated", "Inicia sesión.");
  return request.auth.uid;
}
exports.confirmOrder = onCall({region: "us-central1", maxInstances: 5}, (request) =>
  confirmOrder(getFirestore(), emulatorOnly(request), request.data));
exports.orderOperationResult = onCall({region: "us-central1", maxInstances: 5}, (request) =>
  operationResult(getFirestore(), emulatorOnly(request), request.data.operationId));
