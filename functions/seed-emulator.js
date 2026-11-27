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
  for (const [uid, role, employee] of [["vendedor-demo", "vendedor", "EMP001"], ["repartidor-demo", "repartidor", "EMP002"], ["admin-demo", "administrador", null]]) {
    const email = `${uid}@example.com`;
    try {
      const current = await getAuth().getUser(uid);
      if (current.email !== email) throw new Error("UID de demostración ocupado.");
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
      await getAuth().createUser({uid, email, password: "pharmalab123"});
    }
    const profile = db.doc(`usuarios/${uid}`);
    if (!(await profile.get()).exists) await profile.create({nombre: uid, correo: email, rol: role, estado: true,
      ...(employee ? {empleado_id: employee} : {})});
    if (employee) {
      const ref = db.doc(`empleado/${employee}`);
      if (!(await ref.get()).exists) await ref.create({usuario_id: uid, nombre: uid, apellido: "Demo",
        cargo: role === "repartidor" ? "Repartidor" : "Vendedor", estado: true, telefono: "70000000"});
    }
  }
  const entries = {
    "productos/PROD002": {nombre: "Guantes de nitrilo", precio: 85, estado: true, requiere_vencimiento: false,
      categoria_id: "CAT002", unidadMedida: "Caja", unidad_por_envase: 100, presentacion: "Caja de 100 guantes", marca: "Demo"},
    "productos/PROD003": {nombre: "Reactivo de glucosa", precio: 210, estado: true, requiere_vencimiento: true,
      categoria_id: "CAT003", unidadMedida: "Frasco", unidad_por_envase: 1, presentacion: "Frasco de reactivo", marca: "Demo"},
    "categorias/CAT002": {nombre: "Insumos clínicos"},
    "categorias/CAT003": {nombre: "Reactivos"},
    "lotes_productos/LOTE002": {producto_id: "PROD002", cantidad_disponible: 50, fecha_ingreso: Timestamp.now()},
    "lotes_productos/LOTE004": {producto_id: "PROD003", cantidad_disponible: 25, fecha_ingreso: Timestamp.now(),
      fecha_vencimiento: Timestamp.fromDate(new Date("2035-01-01T04:00:00Z"))},
    "productos/PROD001": {nombre: "Paracetamol 500 mg", precio: 150, estado: true, requiere_vencimiento: true, categoria_id: "CAT001", destacado: true, unidadMedida: "Caja", unidad_por_envase: 20, presentacion: "Caja de 2 blísteres de 10 tabletas", marca: "Demo"},
    "categorias/CAT001": {nombre: "Genéricos"},
    "lotes_productos/LOTE001": {producto_id: "PROD001", numero_lote: "DEMO-1", cantidad_disponible: 30, fecha_ingreso: Timestamp.now(), fecha_vencimiento: Timestamp.fromDate(new Date("2035-01-01T04:00:00Z"))},
    "lotes_productos/LOTE003": {producto_id: "PROD001", numero_lote: "DEMO-3", cantidad_disponible: 70, fecha_ingreso: Timestamp.now(), fecha_vencimiento: Timestamp.fromDate(new Date("2036-01-01T04:00:00Z"))},
    "configuracion/contadores_pedidos": {ultimo_numero: 1, ultimo_id: "PED001", ultimo_documento_id: "demo-reserva-inicial"},
    "configuracion/contadores_direcciones": {ultimo_numero: 2, ultimo_id: "DIR002", ultimo_documento_id: "DIR002"},
    "configuracion/contadores_farmacia": {ultimo_numero: 2, ultimo_id: "FARM002", ultimo_uid: "cliente-demo-b"},
  };
  for (const [path, data] of Object.entries(entries)) {
    if (!(await db.doc(path).get()).exists) await db.doc(path).create(data);
  }
  console.log("Fixtures demo listos: cliente-demo-a@example.com y cliente-demo-b@example.com / pharmalab123");
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
