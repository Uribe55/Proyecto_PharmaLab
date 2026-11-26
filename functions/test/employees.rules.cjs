"use strict";

// Reglas de empleados EMP### y del contador configuracion/contadores_empleados.
// Requiere el emulador de Firestore:
//   firebase emulators:exec --only firestore --project demo-pharmalab-employees \
//     "node --test --test-concurrency=1 functions/test/employees.rules.cjs"
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  updateDoc,
  setDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

assert.match(
  process.env.FIRESTORE_EMULATOR_HOST || '',
  /^127\.0\.0\.1:(8080|8085)$/,
);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const projectId = 'demo-pharmalab-employees';
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host,
      port: Number(port),
      rules,
    },
  });
});

after(async () => env?.cleanup());

const now = Timestamp.fromDate(new Date());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = writeBatch(db);
    const seed = {
      'usuarios/admin': {
        nombre: 'Admin',
        correo: 'admin@pharma.com',
        telefono: '700',
        rol: 'administrador',
        estado: true,
      },
      'usuarios/seller': {
        nombre: 'Vendedor Uno',
        correo: 'seller@pharma.com',
        telefono: '701',
        rol: 'vendedor',
        estado: true,
        empleado_id: 'EMP001',
      },
      'usuarios/driver': {
        nombre: 'Repartidor Dos',
        correo: 'driver@pharma.com',
        telefono: '702',
        rol: 'repartidor',
        estado: true,
        empleado_id: 'EMP002',
      },
      'usuarios/driver3': {
        nombre: 'Repartidor Tres',
        correo: 'driver3@pharma.com',
        telefono: '703',
        rol: 'repartidor',
        estado: true,
        empleado_id: 'EMP003',
      },
      'usuarios/client': {
        nombre: 'Cliente',
        correo: 'client@pharma.com',
        telefono: '704',
        direccion: 'Calle 1',
        rol: 'cliente',
        estado: true,
        tiene_deuda_vencida: false,
      },
      'empleado/EMP001': {
        nombre: 'Vendedor',
        apellido: 'Uno',
        cargo: 'Vendedor',
        telefono: '701',
        estado: true,
        fecha_ingreso: now,
        usuario_id: 'seller',
      },
      'empleado/EMP002': {
        nombre: 'Repartidor',
        apellido: 'Dos',
        cargo: 'Repartidor',
        telefono: '702',
        estado: true,
        fecha_ingreso: now,
        usuario_id: 'driver',
      },
      'empleado/EMP003': {
        nombre: 'Repartidor',
        apellido: 'Tres',
        cargo: 'Repartidor',
        telefono: '703',
        estado: true,
        fecha_ingreso: now,
        usuario_id: 'driver3',
      },
      'configuracion/contadores_empleados': {
        ultimo_numero: 3,
        ultimo_id: 'EMP003',
      },
    };
    for (const [pathName, data] of Object.entries(seed)) {
      batch.set(doc(db, pathName), data);
    }
    await batch.commit();
  });
});

function db(uid) {
  return env.authenticatedContext(uid).firestore();
}

function employeeDocument(overrides = {}) {
  return {
    nombre: 'Nuevo',
    apellido: 'Empleado',
    cargo: 'Vendedor',
    telefono: '705',
    estado: true,
    fecha_ingreso: serverTimestamp(),
    usuario_id: 'newemployee',
    ...overrides,
  };
}

function userDocument(overrides = {}) {
  return {
    nombre: 'Nuevo Empleado',
    correo: 'nuevo@pharma.com',
    telefono: '705',
    rol: 'vendedor',
    estado: true,
    fecha_registro: serverTimestamp(),
    empleado_id: 'EMP004',
    ...overrides,
  };
}

function createEmployee(uid = 'admin', options = {}) {
  const firestore = db(uid);
  const batch = writeBatch(firestore);
  const employeeId = options.employeeId || 'EMP004';
  const nextNumber = options.nextNumber ?? 4;
  if (!options.noEmployee) {
    batch.set(
      doc(firestore, 'empleado/' + employeeId),
      employeeDocument(options.employee),
    );
  }
  if (!options.noUser) {
    batch.set(
      doc(firestore, 'usuarios/newemployee'),
      userDocument({ empleado_id: employeeId, ...options.user }),
    );
  }
  if (!options.noCounter) {
    batch.update(doc(firestore, 'configuracion/contadores_empleados'), {
      ultimo_numero: nextNumber,
      ultimo_id: employeeId,
    });
  }
  return batch.commit();
}

function editEmployee(uid = 'admin', options = {}) {
  const firestore = db(uid);
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, 'empleado/EMP002'), {
    nombre: 'Repartidor',
    apellido: 'Dos',
    cargo: 'Repartidor',
    telefono: '999',
    estado: false,
    ...options.employee,
  });
  batch.update(doc(firestore, 'usuarios/driver'), {
    nombre: 'Repartidor Dos',
    telefono: '999',
    rol: 'repartidor',
    estado: false,
    empleado_id: 'EMP002',
    ...options.user,
  });
  return batch.commit();
}

async function remove(pathName) {
  await env.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), pathName));
  });
}

test('el administrador registra EMP004 con perfil, vínculo y contador', async () => {
  await assertSucceeds(createEmployee());
  const admin = db('admin');
  const employee = await getDoc(doc(admin, 'empleado/EMP004'));
  const user = await getDoc(doc(admin, 'usuarios/newemployee'));
  const counter = await getDoc(doc(admin, 'configuracion/contadores_empleados'));
  assert.equal(employee.data().usuario_id, 'newemployee');
  assert.equal(employee.data().cargo, 'Vendedor');
  assert.equal(user.data().empleado_id, 'EMP004');
  assert.equal(user.data().rol, 'vendedor');
  assert.equal(counter.data().ultimo_numero, 4);
  assert.equal(counter.data().ultimo_id, 'EMP004');
});

test('vendedor, repartidor y cliente no registran empleados', async () => {
  for (const role of ['seller', 'driver', 'client']) {
    await assertFails(createEmployee(role));
  }
});

test('sin contador manual no se registra ningún empleado', async () => {
  await remove('configuracion/contadores_empleados');
  await assertFails(createEmployee());
});

test('un contador desincronizado se rechaza', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'configuracion/contadores_empleados'),
      { ultimo_numero: 3, ultimo_id: 'EMP009' },
    );
  });
  await assertFails(createEmployee());
});

test('no se puede saltar el consecutivo EMP###', async () => {
  await assertFails(createEmployee('admin', { nextNumber: 5 }));
  await assertFails(
    createEmployee('admin', { employeeId: 'EMP005', nextNumber: 5 }),
  );
});

test('no se crea el empleado sin incrementar el contador', async () => {
  await assertFails(createEmployee('admin', { noCounter: true }));
});

test('no se crea el empleado sin su perfil usuarios/{uid}', async () => {
  await assertFails(createEmployee('admin', { noUser: true }));
});

test('el perfil no puede quedar como administrador', async () => {
  await assertFails(
    createEmployee('admin', { user: { rol: 'administrador' } }),
  );
});

test('el empleado y el perfil deben apuntarse mutuamente', async () => {
  await assertFails(
    createEmployee('admin', { user: { empleado_id: 'EMP999' } }),
  );
  await assertFails(
    createEmployee('admin', { employee: { usuario_id: 'otro' } }),
  );
});

test('el administrador edita y desactiva replicando usuarios', async () => {
  await assertSucceeds(editEmployee());
  const admin = db('admin');
  const employee = await getDoc(doc(admin, 'empleado/EMP002'));
  const user = await getDoc(doc(admin, 'usuarios/driver'));
  assert.equal(employee.data().estado, false);
  assert.equal(employee.data().telefono, '999');
  assert.equal(user.data().estado, false);
  assert.equal(user.data().rol, 'repartidor');
  assert.equal(user.data().empleado_id, 'EMP002');
});

test('solo el administrador edita empleados', async () => {
  for (const role of ['seller', 'driver', 'client']) {
    await assertFails(editEmployee(role));
  }
});

test('el cliente no puede cambiar tiene_deuda_vencida', async () => {
  const client = db('client');
  await assertFails(
    updateDoc(doc(client, 'usuarios/client'), { tiene_deuda_vencida: true }),
  );
  await assertSucceeds(
    updateDoc(doc(client, 'usuarios/client'), { nombre: 'Cliente Nuevo' }),
  );
});

test('el administrador no crea ni reasigna administradores', async () => {
  const admin = db('admin');
  await assertFails(
    updateDoc(doc(admin, 'usuarios/seller'), { rol: 'administrador' }),
  );
  await assertFails(
    setDoc(doc(admin, 'usuarios/nuevoadmin'), {
      nombre: 'Admin Nuevo',
      correo: 'nuevoadmin@pharma.com',
      telefono: '706',
      rol: 'administrador',
      estado: true,
      fecha_registro: serverTimestamp(),
      empleado_id: 'EMP004',
    }),
  );
});

test('el contador solo se incrementa, nunca se crea desde la app', async () => {
  const admin = db('admin');
  await assertFails(
    updateDoc(doc(admin, 'configuracion/contadores_empleados'), {
      ultimo_numero: 9,
      ultimo_id: 'EMP009',
    }),
  );
  await remove('configuracion/contadores_empleados');
  await assertFails(
    setDoc(doc(admin, 'configuracion/contadores_empleados'), {
      ultimo_numero: 3,
      ultimo_id: 'EMP003',
    }),
  );
});

test('solo el administrador lee el contador', async () => {
  await assertSucceeds(
    getDoc(doc(db('admin'), 'configuracion/contadores_empleados')),
  );
  await assertFails(
    getDoc(doc(db('seller'), 'configuracion/contadores_empleados')),
  );
  await assertFails(
    getDoc(doc(db('client'), 'configuracion/contadores_empleados')),
  );
});

// Administrative state cannot bypass the matching employee.
test('perfil no desactiva ni cambia rol separadamente del empleado', async () => {
  const admin = db('admin');
  await assertFails(updateDoc(doc(admin, 'usuarios/driver'), { estado: false }));
  await assertFails(updateDoc(doc(admin, 'usuarios/driver'), { rol: 'vendedor' }));
  await assertFails(updateDoc(doc(admin, 'usuarios/driver'), { empleado_id: 'EMP001' }));
});

test('EMP004 no se sobrescribe ni se elimina', async () => {
  await assertSucceeds(createEmployee());
  await assertFails(createEmployee());
  await assertFails(deleteDoc(doc(db('admin'), 'empleado/EMP004')));
});

test('dos altas simultáneas reintentan y asignan EMP004 y EMP005', async () => {
  const { runTransaction } = require('firebase/firestore');
  const firestore = db('admin');
  async function registerOnce(uid) {
    return runTransaction(firestore, async tx => {
      const ref = doc(firestore, 'configuracion/contadores_empleados');
      const snapshot = await tx.get(ref);
      const n = snapshot.data().ultimo_numero + 1;
      const id = 'EMP' + String(n).padStart(3, '0');
      await tx.get(doc(firestore, 'empleado/' + id));
      await tx.get(doc(firestore, 'usuarios/' + uid));
      tx.set(doc(firestore, 'empleado/' + id), employeeDocument({ usuario_id: uid }));
      tx.set(doc(firestore, 'usuarios/' + uid), userDocument({ empleado_id: id, correo: uid + '@pharma.com' }));
      tx.update(ref, { ultimo_numero: n, ultimo_id: id });
      return id;
    });
  }
  async function register(uid) {
    for (let attempt = 0; attempt < 4; attempt++) {
      const ref = doc(firestore, 'configuracion/contadores_empleados');
      const before = (await getDoc(ref)).data().ultimo_numero;
      try { return await registerOnce(uid); }
      catch (error) {
        const after = (await getDoc(ref)).data().ultimo_numero;
        if (error.code !== 'permission-denied' || after <= before || attempt === 3) throw error;
      }
    }
  }
  const ids = await Promise.all([register('concurrent1'), register('concurrent2')]);
  assert.deepEqual(ids.sort(), ['EMP004', 'EMP005']);
});

test('admin inactivo no registra y empleado inactivo no opera', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(), 'usuarios/admin'), { estado: false });
  });
  await assertFails(createEmployee());
});

test('no se reutiliza un UID ya vinculado', async () => {
  await assertFails(createEmployee('admin', { employee: { usuario_id: 'seller' }, noUser: true }));
});
