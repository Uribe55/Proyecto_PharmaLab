# Optimización y Firestore real — 24/11/2026

Rama de trabajo: `pedidos-firestore-transaccionales`. No se hicieron commits, merges, push ni despliegues. Se conservaron los cambios locales previos de configuración del emulador, inicialización Firebase y autenticación secundaria. No se modificó el informe académico.

## Inventario y limpieza

El inventario inicial, anterior a la limpieza, contó **17.331 archivos, 6.370 carpetas y 2.365.217.841 bytes**. Incluye archivos ocultos y `.git`, sin recorrer enlaces de directorios. Es tamaño lógico, no espacio físico asignado del disco. Había **212 archivos versionados**; no se encontraron dependencias, compilaciones ni logs versionados accidentalmente.

| Medición | Antes | Después |
|---|---:|---:|
| Archivos, incluyendo `.git` | 17.331 | 785 |
| Carpetas | 6.370 | 360 |
| Tamaño lógico aproximado | 2.255,65 MiB | 11,76 MiB |

Reducción neta aproximada: **16.546 archivos, 6.010 carpetas y 2.244 MiB (2,19 GiB)**. La medición final incluye los informes nuevos; sus bytes corresponden al instante de medición y pueden variar ligeramente al actualizar el propio informe. De los 785 archivos restantes, 509 pertenecen a `.git`; no son código añadido por Firebase.

| Ruta inicial | Archivos | Bytes | Función | Regenerable | Acción |
|---|---:|---:|---|---|---|
| `functions/node_modules` | 14.236 | 188.604.146 | Dependencias instaladas del backend y pruebas | Sí, `npm ci` | Retirado después de detener emuladores y completar las pruebas |
| `build` | 2.121 | 1.485.797.485 | APK, compilaciones y salidas de pruebas | Sí, Flutter | Retirado; las pruebas posteriores regeneran una parte |
| `.dart_tool` | 204 | 678.196.682 | Configuración de paquetes y cachés | Sí | Retirados `flutter_build` y `hooks_runner`; conservada configuración de paquetes para el IDE |
| `android/.gradle` | 17 | 9.960.855 | Caché local Android | Sí | Conservada: había un daemon Gradle activo |
| `.firebase` | 6 | 8.917 | Exportaciones de datos locales | **Datos únicos** | Conservada y ampliada con un respaldo antes de detener el emulador |
| `.git` | 509 | 893.341 | Historial y metadatos Git | No tratar como caché | Conservado |
| `node_modules`, `.gradle`, `coverage` en raíz | 0 | 0 | No existían | — | Sin acción |
| Código, pruebas, assets, configuración y locks | — | — | Proyecto reproducible | No | Conservados |

Los logs de ejecución y compilación son salidas regenerables. El detalle de rutas retiradas, conteos y bytes está en `AUDITORIA_LIMPIEZA.json`. Las cifras pueden superar el inventario inicial porque las verificaciones generaron salidas nuevas entre ambas mediciones. `AUDITORIA_INVENTARIO_DESPUES.json` contiene la medición final; comparar sus campos `Files`, `Directories` y `Bytes` con `AUDITORIA_INVENTARIO_ANTES.json`.

Antes de borrar se comprobó que las rutas resueltas permanecieran dentro del proyecto, que no fueran enlaces y que no contuvieran archivos versionados. No se usó `git clean`, `git reset`, ni se borraron cachés globales de Flutter, npm o Gradle. Las dependencias Node se reinstalaron primero para verificar el backend y se retiraron al terminar. Se mantuvieron `functions/src`, scripts, pruebas, `package.json` y `package-lock.json`.

Los respaldos `.firebase/phone-backup` y `.firebase/audit-backup` permanecen en esta computadora, ignorados por Git. No se importaron en las pruebas que vacían su base local. Copiarlos fuera del proyecto si se necesita un respaldo adicional antes de trasladar la carpeta.

## Configuración y cambios de aplicación

- Los tres puntos de entrada comparten `PharmaLabApp`. Se conserva la inicialización mínima de `FirebaseEnvironment`, sin crear otra arquitectura.
- `main.dart` mantiene las opciones existentes de **`proyecto-pharmalab`**; no invoca la inicialización del emulador.
- `main_emulator.dart` utiliza una app Firebase nombrada, proyecto `demo-pharmalab` y endpoints locales explícitos de Auth, Firestore y Functions. Se conserva el ajuste de Android para no remapear el host de `adb reverse`.
- Se conservan separados `firebase.json` y `firebase.emulator.json`: el segundo contiene Functions y puertos locales. La UI local usa `127.0.0.1:4000`. No se creó `.firebaserc` ni otra base de datos.
- `scripts/Start-PharmaLab.ps1` centraliza los comandos de ejecución. El modo de pruebas no importa respaldos y siempre especifica el proyecto demo.
- `.gitignore` añade dependencias Node en cualquier nivel, cachés Android y patrones de credenciales, entorno y llaves privadas. Se conservan las exclusiones previas de Flutter, logs y `.firebase`. No fue necesario retirar archivos del índice.
- El servicio no inicializa productos, pedidos ni cuentas de demostración cuando Firebase está activo. Si falta un perfil remoto, muestra un perfil no disponible en lugar de una farmacia de ejemplo.
- El dashboard remoto no sustituye consultas vacías o denegadas por pedidos de demostración. Los errores de permisos se muestran como errores y no como indicadores válidos de cero pedidos.
- La carga de usuarios informa errores y filtra cuentas según el entorno. Los contadores locales no reutilizan pedidos semilla en Firebase.
- El historial admite los nombres existentes `fecha_cambio` e `id_usuario`, además del formato del emulador. Un historial sin rol conserva ese dato ausente y muestra «Rol no registrado». No se migraron documentos.

## Consulta de la base existente

Se ejecutó `functions/scripts/audit-firestore-readonly.js --production-read-only` con credenciales locales ya existentes, mediante IAM/ADC. El script solo consulta muestras de hasta tres documentos por colección y registra nombres de campos y comprobaciones de relación; no imprime credenciales ni datos personales. Resultado: `AUDITORIA_FIRESTORE_REAL.json`.

Se pudieron leer documentos de **usuarios, farmacia_cliente, empleado, categorias, productos, lotes_productos, direcciones, pedidos, entregas, nits_farmacia y configuracion**. También se consultaron `detalle_pedido` e `historial_estado` de un pedido existente. Los conteos del informe son tamaños de muestra, no totales del negocio. Las tres farmacias muestreadas conservaron formato `FARM###`, vínculo `usuario_id` y usuario existente.

Se conservaron el catálogo existente, precios, campos opcionales, stock de `lotes_productos.cantidad_disponible`, relaciones y validación de NIT. No se sembraron datos, renombraron colecciones, crearon pedidos reales ni modificaron cantidades o documentos en producción.

**Esta consulta IAM no comprueba las reglas del cliente móvil.** Se intentó `flutter run -d 103953738A008993 -t lib/main.dart --no-resident`, pero ADB no detectó el teléfono. El usuario aceptó iniciar sesión personalmente cuando vuelva a conectarlo. Quedan pendientes el inicio real en el teléfono, login con una cuenta existente y comprobación visual de farmacia, catálogo, categorías y lotes con sus permisos. No se afirma que esas pruebas móviles hayan pasado.

## Pedidos y seguridad

La confirmación remota sigue bloqueada fuera del emulador, tanto en Flutter como en el backend. Se conservaron Cloud Functions y reglas; no se reemplazaron por escrituras directas desde el cliente.

Las pruebas locales verifican usuario/rol/estado, vínculo de farmacia, dirección propia, precio autorizado, cantidades válidas, disponibilidad por lotes, FEFO/FIFO, concurrencia sin sobreventa, transacción atómica, idempotencia y recuperación de la misma operación. También prueban el bloqueo de escrituras del cliente a inventario, precios, pedidos, contador y operaciones, y la lectura autorizada de pedidos y subcolecciones.

El ciclo de vida remoto de vendedor/repartidor no está habilitado por esta tarea. Las políticas de aprobación, entrega, cancelación, incidencias, reprogramación y sincronización offline se conservan en demostración y pruebas locales. El código existente no debe interpretarse como un despliegue productivo de todas esas operaciones.

Para habilitar compras reales hace falta autorización y una etapa específica: definir/desplegar backend, revisar permisos IAM y reglas para cada rol, verificar compatibilidad de índices, decidir el contador de pedidos sin colisionar con identificadores históricos y validar la integración móvil en un entorno controlado. El contador de pedidos no se crea automáticamente. Las reglas locales probadas no demuestran que las reglas actualmente desplegadas sean idénticas. No se desplegaron Functions, reglas ni índices ni se modificaron facturación o cuotas.

## Verificación

- `flutter pub get`: correcto, sin cambiar restricciones ni versiones bloqueadas.
- `flutter analyze`: sin incidencias.
- `flutter test`: **90 pruebas aprobadas**, incluyendo flujos demo, carrito, importes, roles, cancelaciones, incidencias y compatibilidad de historial existente. Se repitió la verificación Flutter después de retirar las compilaciones iniciales.
- `npm.cmd --prefix functions ci`: instalación reproducible correcta, 293 paquetes instalados.
- `node --check`: correcto en `functions/src/index.js`, `functions/src/orders.js`, `functions/seed-emulator.js` y el script de auditoría. El backend es JavaScript y no tiene un paso de compilación TypeScript.
- `firebase.cmd emulators:exec --config firebase.emulator.json --project demo-pharmalab --only auth,firestore,functions "npm.cmd --prefix functions test"`: **21 pruebas aprobadas**, cero fallos, incluida comunicación callable autenticada con Functions.
- `git diff --check`: correcto.
- La instalación notificó **14 avisos de dependencias: 5 altos y 9 moderados**. Se conserva el detalle en `AUDITORIA_DEPENDENCIAS.json`. No se ejecutó `npm audit fix --force` ni se alteraron versiones mayores. Deben resolverse antes de una habilitación productiva.
- El backend declara Node **22**; esta computadora ejecuta **26.9.0**. Las pruebas pasaron aquí con advertencia de motor. Para reproducir el runtime declarado debe usarse Node 22.

## Ejecutar y reconstruir

Desde la raíz del proyecto, con Flutter, Firebase CLI, Java y Node disponibles:

```powershell
flutter pub get
flutter run -t lib/main.dart                 # Firebase real: login personal, compras bloqueadas
flutter run -t lib/main_demo.dart            # Demostración sin Firebase
```

Conectar el teléfono por USB, aceptar la depuración y consultar `flutter devices`; añadir `-d ID` si hay varios dispositivos. Cambiar de modo con un nuevo `flutter run`, no mediante hot reload.

Para recuperar las dependencias del backend y abrir los emuladores conservando los datos del teléfono:

```powershell
npm.cmd --prefix functions ci
firebase.cmd emulators:start --config firebase.emulator.json --project demo-pharmalab --only auth,firestore,functions --import=.firebase/audit-backup --export-on-exit=.firebase/audit-backup
```

Alternativa equivalente:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Start-PharmaLab.ps1 -Mode Emulator -ImportPath .firebase/audit-backup
```

Con el servidor abierto, acceder a `http://127.0.0.1:4000/firestore/default/data`. Para el teléfono conectado por USB, en otra terminal:

```powershell
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:5001 tcp:5001
flutter run -t lib/main_emulator.dart --dart-define=EMULATOR_HOST=127.0.0.1
```

En Android Emulator, ejecutar `flutter run -t lib/main_emulator.dart`; el host predeterminado es `10.0.2.2`. Para un emulador vacío, `node functions/seed-emulator.js` requiere las variables de emulador correspondientes; nunca ejecutar semillas contra el proyecto real.

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
node functions/seed-emulator.js
Remove-Item Env:FIRESTORE_EMULATOR_HOST
Remove-Item Env:FIREBASE_AUTH_EMULATOR_HOST
```

La semilla solo crea documentos demo ausentes. Las cuentas del respaldo son `cliente-demo-a@example.com` y `cliente-demo-b@example.com`, con contraseña local de pruebas `pharmalab123`.

Para repetir pruebas del backend, cerrar primero cualquier emulador interactivo y ejecutar:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Start-PharmaLab.ps1 -Mode EmulatorTests
```

El script reinstala dependencias si faltan y utiliza una base demo vacía. Las pruebas limpian esa base: nunca añadir `--import` de los respaldos personales al comando de pruebas.

`flutter build apk --debug` regenera las compilaciones Android cuando se necesiten. `scripts/Measure-Project.ps1 -OutputPath docs/AUDITORIA_INVENTARIO_DESPUES.json` permite repetir la medición. Ejecutar Flutter o instalar Node volverá a crear archivos generados: es esperado; permanecen ignorados por Git.

Al entregar esta limpieza los emuladores quedan detenidos y las dependencias Node retiradas. El código y los respaldos permanecen disponibles para reconstruirlos con los comandos anteriores.
