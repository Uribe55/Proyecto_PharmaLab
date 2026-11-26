# Numeración comercial de pedidos y direcciones

## Estado y auditoría de producción

Trabajo local en `pedidos-firestore-transaccionales`. No se publicaron reglas, no se hicieron compras reales, migraciones, commits ni push. Se conservaron los cambios que ya estaban presentes, incluido `lib/main.dart`.

Lecturas del 25 de noviembre de 2026 en `proyecto-pharmalab`, base `(default)`. Se paginaron íntegramente `pedidos`, `direcciones` y `configuracion`. Existían **dos pedidos y dos direcciones**, incluyendo los inactivos, no solo los del cliente actual:

| Documento interno | Número comercial observado | Situación |
|---|---|---|
| `pedidos/PED001` | No tiene campo; el ID histórico sirve como PED001 | Aprobado, FARM001, DIR001, Bs 385. Conservar intacto. |
| `pedidos/TD1pMWCdXAcwdPnIkkfa` | `PED-TD1pMWCdXAcwdPnIkkfa` | Aprobado, FARM004, dirección aleatoria existente, Bs 150. Candidato a PED002. |
| `direcciones/DIR001` | No tiene campo; el ID histórico sirve como DIR001 | FARM001. Conservar intacta. |
| `direcciones/KKp8HDRwSfgBBiGAaVpr` | No tiene campo | FARM004. Candidata a DIR002. |

Ambos contadores tienen `ultimo_numero: integerValue "2"` y `ultimo_id: stringValue` PED002/DIR002. **El tipo es correcto; no convertirlo ni reiniciar los contadores.** El número 002 está reservado en los contadores, pero aún no está asignado en los documentos correspondientes.

Los detalles reales tienen `cantidad` entera y precios/subtotales numéricos double; el stock de LOTE001 es entero; sus fechas y las fechas de pedido/aprobación/historial son timestamp. Los estados de usuarios/direcciones/productos son booleanos y el estado del pedido es string, como exige su contrato. No se encontraron conversiones de tipos necesarias. Las coordenadas nulas de la dirección son válidas. La auditoría de tipos, sin valores personales, está en `NUMERACION_AUDITORIA_REAL.json`. No restablecer stock al valor observado durante una auditoría.

Las reglas publicadas al revisar eran `35eefdca-b914-4af6-a766-cab0dea2fba1`, SHA256 `E4527C1B23FF60E31C31F44E4EE2B65B658D708C1DC312F01B61E6DBD7DD3DF0`, y coincidían con el contrato local anterior v1. La copia de regresión es `functions/test/fixtures/firestore.before-numbering.rules`. Las nuevas reglas v2 solo están en el archivo local `firestore.rules`.

## Correcciones manuales en Firebase Console

Realizarlas en un periodo sin nuevas confirmaciones ni altas de direcciones. Antes de guardar, volver a revisar **todos** los pedidos y direcciones: si aparecieron otros documentos desde esta auditoría, detener este procedimiento y revisar las asignaciones. No reutilizar números ni bajar el contador.

1. En `pedidos/TD1pMWCdXAcwdPnIkkfa`, cambiar **solo** `numero_comercial` a string **`PED002`**.
2. En `direcciones/KKp8HDRwSfgBBiGAaVpr`, agregar **solo** `numero_comercial` de tipo string **`DIR002`**.
3. Dejar `configuracion/contadores_pedidos` así:

   | Campo | Tipo en Console | Valor |
   |---|---|---|
   | `ultimo_numero` | number / entero int64 | `2` |
   | `ultimo_id` | string | `PED002` |
   | `ultimo_documento_id` | string | `TD1pMWCdXAcwdPnIkkfa` |

4. Dejar `configuracion/contadores_direcciones` así:

   | Campo | Tipo en Console | Valor |
   |---|---|---|
   | `ultimo_numero` | number / entero int64 | `2` |
   | `ultimo_id` | string | `DIR002` |
   | `ultimo_documento_id` | string | `KKp8HDRwSfgBBiGAaVpr` |

5. Revisar que PED002 y DIR002 no estén asignados en otro documento. Guardar una copia de los campos antes y después para revisión.

`ultimo_id` significa **código comercial**, no ID de documento. El nuevo campo `ultimo_documento_id` permite a las reglas vincular el contador con el documento interno aleatorio. No usar el tipo Firestore Reference: ambos campos son strings.

No renombrar, copiar ni eliminar documentos. No cambiar `id_direccion` del pedido, `id_operacion`, `schema_version` v1, `linea`, importes, estado, aprobador, fechas, inventario ni operaciones de usuario. No renombrar LINEA1 en el pedido aprobado. No tocar CONFIRMACION/APROBACION, PED001, DIR001 ni `contadores_farmacia`. El mapa idempotente no incluye el número visible; asignar PED002 no invalida los reintentos históricos.

Estas correcciones son mantenimiento administrativo en Console con las compras pausadas. Las reglas de la aplicación **no** conceden permisos para renumerar pedidos o direcciones existentes. No se agregó una puerta de migración desde Flutter.

## Contrato implementado localmente

- IDs internos aleatorios de 20 caracteres para pedidos y direcciones; nunca se deriva una ruta a partir del número visible.
- Pedido nuevo: `schema_version: spark_single_v2`, `numero_comercial: PED003` y siguientes; se conserva `id_operacion` y `usuarios/{uid}/operaciones_pedido/{id}` por su función de idempotencia.
- Un producto, un lote y 1–1000 cajas, sin compras parciales ni división automática del carrito.
- **Seis escrituras atómicas:** pedido, DET001, CONFIRMACION, operación idempotente, descuento del lote y contador. Todas las lecturas preceden a las escrituras. Un reintento confirmado retorna sin consumir otro número ni descontar otra vez.
- Dirección nueva: documento aleatorio con `numero_comercial: DIR003` y siguientes, creado junto con el incremento del contador. No se reescriben referencias de pedidos históricos.
- La dirección conserva su ID ante reintentos del SDK; el repositorio conserva el intento ante errores durante esa sesión. El intento de alta de dirección no se persiste entre reinicios de la aplicación. Tras un cierre con resultado incierto, revisar la lista sincronizada antes de volver a registrar la misma dirección.
- La aprobación continúa usando únicamente el ID interno, la transición y APROBACION en una transacción; no cambia la numeración ni descuenta stock.
- El lector consulta toda la subcolección de detalles: acepta LINEA1, DET001 y otros detalles históricos sin renombrarlos. CONFIRMACION y APROBACION mantienen su estructura.
- Cliente, vendedor y dashboard usan el número comercial. PED001 y DIR001 conservan su fallback histórico. Si un pedido aleatorio aún no fue normalizado, se muestra «Pedido sin número comercial», nunca su ID técnico ni un número inventado.

Los contadores rechazan doubles, strings, valores nulos y códigos incoherentes; Dart no los convierte silenciosamente. Rango inicial admitido: 1 a 999999998, incrementando hasta 999999999. Los códigos tienen al menos tres dígitos; PED1000 no se trunca.

## Reglas e integridad

`firestore.rules` contiene el archivo completo actualizado. Cambios: validación de contadores PED/DIR; validSparkOrder v2 y DET001; newSparkParent v2; referencias cruzadas de operación/lote; dirección numerada con código inmutable. El registro de farmacias/NIT y su contador permanecen sin cambios.

Un contador solo puede avanzar exactamente +1 por un cliente activo, con número entero y código calculado en reglas. Debe apuntar al documento **nuevo** de la misma operación. El pedido/dirección exige a su vez ese avance y la referencia inversa del contador. No se permite consumir un número aislado, crear sin contador, saltar, reutilizar, asignarlo a dos documentos ni modificar códigos existentes desde el cliente.

La creación del pedido verifica precio autorizado, farmacia/dirección, cantidad, vigencia, stock antes/después y los tres documentos obligatorios (detalle, historial, operación). El rol activo se exige en las escrituras obligatorias del lote y de la operación; el padre verifica autenticación/propiedad. Esto permite conservar las validaciones sin exceder diez accesos en la evaluación del padre:

| Evaluación del padre | Accesos distintos |
|---|---:|
| farmacia, dirección, producto | 3 |
| lote antes/después | 2 |
| contador antes/después | 2 |
| detalle, CONFIRMACION, operación después | 3 |
| Total | **10** |

El conjunto usa 13 estados/rutas distintos contando usuario y padre antes/después; los accesos repetidos aprovechan la caché de reglas. No se agrega un `activeClient()` redundante al padre: las reglas de lote/operación comprueban ese rol de forma obligatoria. Las transacciones completas se probaron con reglas reales en el emulador aislado. Un carrito mayor requeriría otra auditoría del presupuesto, no extender este contrato sin comprobarlo.

Firebase establece diez accesos por operación y veinte por operación atómica, y permite `getAfter()` para exigir escrituras conjuntas: [documentación oficial](https://firebase.google.com/docs/firestore/security/rules-conditions). Las lecturas de la transacción preceden a las escrituras y el SDK reintenta conflictos: [transacciones](https://firebase.google.com/docs/firestore/manage-data/transactions).

En las pruebas, una carrera del contador también podía producir `permission-denied`. `numbered_transaction.dart` conserva la transacción estricta y admite hasta tres intentos externos: solo reintenta ese error si el contador leído directamente del servidor avanzó respecto al observado. Mantiene el mismo ID, relee todo y recalcula el número. Un rechazo sin avance se propaga. Los reintentos nunca relajan reglas ni escriben por separado. El contador global puede generar contención; si se agotan los intentos, la operación falla de forma segura y se consulta/reintenta el mismo pedido.

## Activación coordinada pendiente

No ejecutar la nueva app contra las reglas v1: esas reglas deniegan los contadores. Tampoco publicar v2 dejando clientes v1 confirmando: v2 rechaza nuevas compras v1/LINEA1 para impedir que omitan el contador. Las lecturas, reintentos de pedidos ya confirmados y aprobaciones históricas siguen permitidos.

Orden recomendado, durante la pausa de nuevas compras/altas:

1. Revisar y realizar los cambios manuales anteriores.
2. Revisar el diff local y las pruebas.
3. Publicar únicamente las reglas, cuando el propietario lo decida:

   ```powershell
   firebase.cmd deploy --only firestore:rules --project proyecto-pharmalab --config firebase.json
   ```

4. Actualizar los clientes que confirman compras o registran direcciones y ejecutar Firebase real:

   ```powershell
   flutter run -t lib/main.dart -d 103953738A008993
   ```

5. Reanudar. La primera nueva compra autorizada debe obtener PED003 y la siguiente nueva dirección DIR003, siempre que no haya nuevos registros desde la auditoría. La comprobación real de compra queda a cargo de una prueba autorizada por el propietario; no se realizó en este trabajo.

No necesita Blaze, Functions, Cloudflare ni emulador para funcionar. Conservar la versión anterior de reglas/código para revisión; si ya se emitieron números nuevos, no restaurar valores antiguos de contadores ni inventarios.

## Pruebas

Resultados finales: `flutter pub get` correcto, `flutter analyze` sin incidencias, **150 pruebas Flutter y 50 pruebas de reglas aprobadas**, sin fallos. Evidencia resumida en `NUMERACION_PRUEBAS.json`. El entorno de reglas usa exclusivamente `demo-pharmalab-spark-regression` y localhost, sin importar backups ni datos personales de producción. Cubre numeración consecutiva, dos clientes concurrentes, contadores manipulados/tipos, escrituras omitidas, una sola línea/lote, idempotencia/stock, snapshots/aprobación, históricos v1/LINEA1, PED001 y registro de farmacia/NIT.

Reproducción:

```powershell
flutter pub get
flutter analyze
flutter test
npm.cmd --prefix functions ci --ignore-scripts --no-audit --no-fund
firebase.cmd emulators:exec --config firebase.emulator.json --project demo-pharmalab-spark-regression --only firestore "npm.cmd --prefix functions run test:spark-rules"
```

La instalación temporal agregó 293 paquetes utilizables, pero `npm ci` terminó con código 1 por la política de npm que no permite scripts postinstall sin aprobar; no se aprobaron ni ejecutaron esos scripts. También avisó que el Node instalado (26) difiere del 22 declarado por el backend legado. Eso no impidió ejecutar y aprobar la suite de reglas. Para reproducir solo estas pruebas se indica `--ignore-scripts`, sin cambiar la política de scripts ni desplegar el backend. La suite antigua de Functions no forma parte del flujo Spark y no se ejecutó. El harness de reglas usa el SDK JavaScript con el mismo contrato transaccional; incluye escrituras REST tipadas compatibles con Flutter. No sustituye una compra real autorizada desde Android. Las dependencias pesadas y logs temporales se retiran al terminar; quedan las pruebas y fixtures pequeños para regresión.

## Archivos de esta implementación

- `firestore.rules`: contrato completo v2 y contadores.
- `lib/domain/commercial_number.dart`, `spark_checkout.dart`, `spark_address.dart`: numeración, pedido y alta de dirección.
- `lib/data/datasources/numbered_transaction.dart`, `firestore_spark_checkout.dart`, `firestore_order_data_source.dart`: transacciones, diagnóstico y reintentos.
- `lib/data/mappers/firestore_order_mapper.dart`, `lib/models/delivery_address.dart`, `lib/screens/cliente_farmacia/checkout_screen.dart`, `lib/services/dashboard_repository.dart`: presentación comercial conservando IDs internos.
- `test/commercial_number_test.dart`, `test/spark_checkout_test.dart`, `functions/test/spark_checkout.rules.cjs`, `functions/test/fixtures/firestore.before-numbering.rules`: pruebas y regresión del contrato anterior.
- Este documento y los informes JSON: auditoría y resultados. Los archivos del diagnóstico anterior se conservaron.
