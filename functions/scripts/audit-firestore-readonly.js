"use strict";

// Auditoría acotada. No incluye métodos de escritura ni imprime datos personales.
const {initializeApp, applicationDefault, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const projectId = "proyecto-pharmalab";
const collections = ["usuarios", "farmacia_cliente", "empleado", "categorias", "productos",
  "lotes_productos", "direcciones", "pedidos", "entregas", "nits_farmacia", "configuracion"];
if (!process.argv.includes("--production-read-only") || process.env.FIRESTORE_EMULATOR_HOST ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error("Requiere --production-read-only y un proceso sin variables de emulador.");
}

(async () => {
  const app = initializeApp({projectId, credential: applicationDefault()});
  const db = getFirestore(app);
  db.settings({timeoutSeconds: 15});
  const report = {projectId, access: "IAM/ADC; no equivale a un login móvil ni verifica rules del cliente",
    readOnly: true, sampleLimit: 3, collections: [], relationships: []};
  try {
    for (const name of collections) {
      try {
        const snapshot = await db.collection(name).limit(3).get();
        const fields = [...new Set(snapshot.docs.flatMap((doc) => Object.keys(doc.data())))].sort();
        report.collections.push({name, sampled: snapshot.size, fields});
        if (name === "farmacia_cliente") {
          for (const farm of snapshot.docs) {
            const uid = farm.get("usuario_id");
            const user = typeof uid === "string" ? await db.doc(`usuarios/${uid}`).get() : null;
            report.relationships.push({farmIdFormat: /^FARM\d+$/.test(farm.id),
              hasUserLink: typeof uid === "string", linkedUserExists: user?.exists ?? false});
          }
        }
        if (name === "pedidos" && snapshot.size) {
          const first = snapshot.docs[0];
          for (const child of ["detalle_pedido", "historial_estado"]) {
            const children = await first.ref.collection(child).limit(3).get();
            report.collections.push({name: `pedidos/{muestra}/${child}`, sampled: children.size,
              fields: [...new Set(children.docs.flatMap((doc) => Object.keys(doc.data())))].sort()});
          }
        }
      } catch (error) {
        report.collections.push({name, errorCode: error.code ?? "unknown", message: "No se pudo leer esta colección con la sesión disponible."});
      }
    }
    console.log(JSON.stringify(report, null, 2));
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
})().catch((error) => {console.error(`Auditoría no completada (${error.code ?? "unknown"}).`); process.exitCode = 1;});
