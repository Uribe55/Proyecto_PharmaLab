"use strict";
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
// Nunca se ejecuta sobre el proyecto real. No borra datos, solo crea fixtures demo.
if (process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8080" ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== "127.0.0.1:9099") throw new Error("Requiere emuladores locales.");
initializeApp({projectId: "demo-pharmalab"});
(async () => {
  const db = getFirestore();
  for (const [uid, number] of [["cliente-demo-a", 1], ["cliente-demo-b", 2]]) {
    const email = `${uid}@example.com`;
    try {
      const existing = await getAuth().getUser(uid);
      if (existing.email !== email) throw new Error("El UID de prueba pertenece a otro correo.");
    } catch (e) {
      if (e.code !== "auth/user-not-found") throw e;
      await getAuth().createUser({uid, email, password: "pharmalab123"});
    }
    const farm = `FARM00${number}`;
    const entries = {
      [`usuarios/${uid}`]: {nombre: `Farmacia ${number}`, correo: email, rol: "cliente", estado: true},
      [`farmacia_cliente/${farm}`]: {usuario_id: uid, nombre_farmacia: `Farmacia ${number}`, responsable: `Cliente ${number}`, telefono: "70000000", nit: `1234567${number}`, direccion_fiscal: "Av. Demo", estado: true},
      [`direcciones/DIR00${number}`]: {id_cliente: farm, nombre: "Principal", direccion: `Av. Demo ${number}`, referencia: "", latitud: null, longitud: null, estado: true},
      [`nits_farmacia/1234567${number}`]: {farmacia_id: farm, usuario_id: uid},
    };
    for (const [path, data] of Object.entries(entries)) {
      if (!(await db.doc(path).get()).exists) await db.doc(path).create(data);
    }
  }
  const entries = {
    "productos/PROD001": {nombre: "Paracetamol 500 mg", precio: 150, estado: true, requiere_vencimiento: true, categoria_id: "CAT001", destacado: true, unidadMedida: "Caja", unidad_por_envase: 20, presentacion: "Caja de 2 blísteres de 10 tabletas", marca: "Demo"},
    "categorias/CAT001": {nombre: "Genéricos"},
    "lotes_productos/LOTE001": {producto_id: "PROD001", numero_lote: "DEMO-1", cantidad_disponible: 5, fecha_ingreso: Timestamp.now(), fecha_vencimiento: Timestamp.fromDate(new Date("2035-01-01T04:00:00Z"))},
    "lotes_productos/LOTE003": {producto_id: "PROD001", numero_lote: "DEMO-3", cantidad_disponible: 10, fecha_ingreso: Timestamp.now(), fecha_vencimiento: Timestamp.fromDate(new Date("2036-01-01T04:00:00Z"))},
    "configuracion/contadores_pedidos": {ultimo_numero: 0},
    "configuracion/contadores_farmacia": {ultimo_numero: 2, ultimo_id: "FARM002", ultimo_uid: "cliente-demo-b"},
  };
  for (const [path, data] of Object.entries(entries)) {
    if (!(await db.doc(path).get()).exists) await db.doc(path).create(data);
  }
  console.log("Fixtures demo listos: cliente-demo-a@example.com y cliente-demo-b@example.com / pharmalab123");
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
