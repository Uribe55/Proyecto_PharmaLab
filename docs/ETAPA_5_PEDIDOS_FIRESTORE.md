# Etapa 5 — Pedidos e inventario transaccional

Fecha: 24 de noviembre de 2026. Implementación local en `pedidos-firestore-transaccionales`, basada en `main` (`47e0e90`). No se hicieron commits, merges, push, despliegues ni cambios de facturación o de datos de producción.

## Alcance y revisión

Se revisaron los modelos, política de dominio, repositorio y fuente local, servicio dividido en `part`, carrito, catálogo, checkout, historial, seguimiento, sincronización, reglas y pruebas anteriores. Se consultaron `docs/ETAPA_4_PEDIDOS.md` y los documentos de integración de catálogo/cantidades en HEAD. No se encontró un informe PDF/DOCX adjunto en el repositorio; se usaron los requerimientos del texto entregado.

La rama estaba limpia y sin diferencias respecto de `main` al comenzar. Durante la sesión aparecieron eliminados `INTEGRACION_CATALOGO.md` e `INTEGRACION_CANTIDADES.md`; esa eliminación externa no forma parte de esta implementación y no se revirtió. Se retiraron los cambios de formato en archivos ajenos a la etapa.

**Producción permanece bloqueada.** El backend exige simultáneamente Functions, Auth y Firestore Emulator. No basta modificar el botón Flutter, pasar un `dart-define` o desplegar accidentalmente el código para habilitar compras reales. `firebase.json`, `.firebaserc`, `firebase_options.dart` y el proyecto Firebase normal no se cambian.

## Arquitectura y archivos

Flujo remoto: `CheckoutScreen` → `CheckoutViewModel` → contrato `RemoteOrderRepository` → `FirestoreOrderDataSource` → callable autenticado → transacción Admin SDK. La fuente también realiza lecturas sujetas a reglas de pedidos, detalles, historial y direcciones. No hay escrituras directas de inventario ni pedidos desde Flutter.

Flujo local: `CartViewModel.confirmDemoOrder` → `PharmaService` → `OrderRepository` → `LocalOrderDataSource`. `OrderPolicy`, cancelaciones, solicitudes, incidencias, asignación separada del despacho, reprogramación y cola de demostración se mantienen. No se implementaron de nuevo las transiciones del dominio en el backend: esta etapa remota implementa únicamente la confirmación inicial. Las acciones remotas posteriores siguen bloqueadas por `OrderViewModel` y las reglas.

Archivos nuevos:

- `functions/package.json`, `functions/package-lock.json`: dependencias reproducibles del backend y tests.
- `functions/src/orders.js`: unidad de trabajo, precios en centavos, validaciones, asignación de lotes, idempotencia y consulta de resultado.
- `functions/src/index.js`: callables `confirmOrder` y `orderOperationResult`, autenticación y bloqueo de producción.
- `functions/test/orders.test.js`: pruebas con Firestore/Auth/Functions Emulator y reglas.
- `functions/seed-emulator.js`: fixtures exclusivamente para `demo-pharmalab`, sin borrar ni sobrescribir documentos existentes.
- `firebase.emulator.json`: configuración local independiente; puertos 8080, 9099 y 5001.
- `firestore.indexes.json`: índice propuesto de pedidos por farmacia y fecha.
- `lib/main_emulator.dart`, `lib/services/firebase_environment.dart`: arranque aislado; app Firebase nombrada para evitar usar el proyecto nativo normal en Android.
- `lib/data/repositories/remote_order_repository.dart`: contrato remoto y errores de negocio.
- `lib/data/datasources/firestore_order_data_source.dart`: adaptador callable y lecturas.
- `lib/data/datasources/pending_checkout_store.dart`: registro SQLite por UID, transacción local y `synchronous=FULL` antes del envío.
- `lib/data/mappers/firestore_order_mapper.dart`: compatibilidad con subcolecciones y pedidos anteriores como `PED001`.
- `lib/models/delivery_address.dart`: dirección seleccionable.
- `lib/viewmodels/checkout_view_model.dart`, `lib/viewmodels/order_history_view_model.dart`.
- `test/checkout_view_model_test.dart` y este documento.

Archivos modificados y finalidad:

- `firestore.rules`: propuesta de permisos; registro/NIT/contador FARM conservados.
- `lib/models/order.dart`: ID técnico, número comercial, operación, dirección, importe histórico, unidad comercial y origen de caché opcionales, sin romper constructores locales.
- `lib/screens/cliente_farmacia/{cart_screen,checkout_screen,order_history_screen,order_tracking_screen}.dart`: selección/alta de dirección, progreso, errores, revisión de precios, recuperación de operación, historial y seguimiento remotos.
- `lib/services/pharma/orders.dart`: impide presentar pedidos demo como pedidos de una sesión Firebase.
- `lib/services/{pharma_service,firebase_environment,dashboard_repository}.dart`, `lib/services/pharma/{service_state,users}.dart`, `lib/data/datasources/firestore_catalog_data_source.dart`: selección centralizada de instancias Firebase; las instancias secundarias Auth también respetan el emulador. No se modifica la lógica de registro de farmacias.
- `lib/main.dart`: identifica visualmente el entorno emulado.
- `android/app/src/debug/AndroidManifest.xml`: permite HTTP local solo en debug.
- `pubspec.yaml`, `pubspec.lock`: `cloud_functions` y `sqflite`.
- `test/cart_view_model_test.dart`: conserva el test de bloqueo productivo y adapta su texto a la interfaz actual.
- `.gitignore`: excluye dependencias Node, estado temporal y logs locales.

## Modelo Firestore y propuesta de datos

Se mantienen todas las colecciones existentes. No hay migración automática ni modificación de documentos anteriores.

| Ruta | Contenido |
|---|---|
| `pedidos/{id}` | Conserva `estado`, `fecha_pedido`, `id_cliente`, `id_direccion`, `total` |
| `pedidos/{id}/detalle_pedido/{productoId}` | Conserva `id_producto`, `cantidad`, `precio_unitario`, `subtotal` |
| `pedidos/{id}/historial_estado/confirmacion` | Estado inicial, fecha, operación y actor |
| `usuarios/{uid}/operaciones_pedido/{operationId}` | Huella del contenido y resultado confirmado; solo backend escribe |
| `configuracion/contadores_pedidos` | `ultimo_numero`, contador comercial transaccional separado de FARM |
| `direcciones/{id}` | Campos existentes: `id_cliente`, `nombre`, `direccion`, `referencia`, `latitud`, `longitud`, `estado` |

Campos adicionales del pedido: `numero_comercial`, `id_operacion`, `usuario_id`, `observaciones`, `nombre_farmacia`, `responsable`, `telefono`, `entrega` (copia inmutable de la dirección) y `version_esquema`. Cada detalle guarda nombre, marca, presentación, `unidad_medida`, `unidad_por_envase` y `asignaciones_lotes: [{id_lote,cantidad}]`. Las subcolecciones existentes no se sustituyen por arrays. La asignación es una lista pequeña dentro de cada detalle para conservar qué lotes se descontaron; las futuras cancelaciones deberán restituir esas cantidades mediante otro comando confiable, todavía no habilitado.

Los tres identificadores tienen fines diferentes:

1. Documento: `ORD_` + SHA-256 de `UID:operationId`; no colisiona con IDs antiguos como `PED001`.
2. Número visible: `PL-año-000001`, usando `configuracion/contadores_pedidos` en la misma transacción.
3. Operación: ID aleatorio generado una vez y almacenado con el contenido original en SQLite antes del primer envío; se reutiliza ante reintentos y reaperturas.

El contador de pedidos **no se crea automáticamente**. Su ausencia o formato inválido bloquea la compra. El seed lo prepara solo en el proyecto ficticio de emulación. Para producción se necesita autorización explícita y una auditoría previa de números comerciales existentes para escoger su valor inicial. `configuracion/contadores_farmacia` nunca es modificado por la confirmación.

## Transacción, inventario y seguridad

El callable toma el UID del token, no del payload. Dentro de la transacción lee `usuarios/{uid}` activo con rol cliente y consulta la única farmacia vinculada al UID, que también debe estar activa. No acepta un `id_cliente` arbitrario. Verifica que la dirección seleccionada esté activa y pertenezca a esa farmacia.

Se admiten 1–20 productos distintos, cantidades enteras positivas de hasta 10.000 y notas de hasta 1.000 caracteres. Se leen los productos y sus precios actuales, no se usan precios ni totales calculados por el cliente como autoridad. Los cálculos monetarios se hacen en centavos enteros y se guardan precios históricos en Bs. Si difieren del precio que el usuario revisó, la transacción no escribe nada y devuelve los nuevos precios. La interfaz los muestra y exige una nueva pulsación explícita.

El stock se descuenta exclusivamente de `lotes_productos.cantidad_disponible`, en unidades comerciales. Dos cajas de 20 tabletas a Bs 150 producen un detalle de 2 cajas, Bs 300, y un descuento de 2, nunca de 40.

Cada producto debe tener `requiere_vencimiento` booleano configurado. Si es verdadero, se excluyen lotes sin vencimiento y se aplica FEFO. Si es falso se utiliza FIFO por `fecha_ingreso`, fechas ausentes primero, y desempate por ID de lote. Se excluyen cantidades no enteras/no positivas, fechas inválidas y lotes vencidos, incluso en productos de vencimiento opcional si el lote sí tiene fecha. El vencimiento se interpreta por día comercial de Bolivia (UTC−4); un lote es válido hasta finalizar ese día. Las importaciones deben conservar esa semántica de timestamps. El reloj autoritativo es el servidor; la disponibilidad mostrada por el catálogo sigue siendo orientativa.

Se pueden consumir varios lotes. Todas las lecturas preceden a las escrituras. Se crean cabecera, detalles, evento inicial y registro idempotente, se actualiza el contador y se descuentan los lotes en un único commit. Un conflicto vuelve a ejecutar la transacción con stock actualizado; un error no aplica cambios parciales. Se limita a 100 lotes consultados por producto y 300 lotes modificados por operación; si se exceden los límites se rechaza y se requiere consolidar inventario. No se presupone escalabilidad ilimitada: contador global y productos populares son puntos de contención que deben medirse antes de producción.

Una operación repetida devuelve su resultado anterior. El mismo ID con contenido diferente se rechaza. El frontend bloquea pulsaciones simultáneas y nunca vacía el carrito antes de confirmar el resultado con lectura de servidor. Si se modificó el carrito durante el envío, conserva ese carrito nuevo. Ante timeout conserva el ID; al reabrir consulta primero el resultado y permite reenviar exactamente la misma operación. Desde el carrito se accede a recuperación incluso si el carrito está vacío. La pantalla muestra el contenido original pendiente. Un resultado de caché no se interpreta como compra confirmada.

Si una operación quedó incierta y posteriormente recibe un rechazo, no se descarta automáticamente el ID: hacerlo podría duplicar una compra anterior. Debe consultarse o resolverse en soporte antes de iniciar otra operación. Reinstalar/borrar datos locales o cambiar de dispositivo no conserva SQLite; se debe revisar el historial del servidor antes de repetir una compra. La operación pertenece al UID y no puede consultarse desde otra cuenta.

Propuesta de reglas, probada únicamente en emulador:

- Cliente activo: lectura de pedidos de su farmacia activa, detalles e historial; las consultas requieren filtro `id_cliente`.
- Vendedor/administrador activos: lectura de pedidos; repartidor activo: solo pedidos con `repartidor_uid` igual al UID. Esto prepara la interfaz de autorización, sin implementar asignación remota.
- Ningún cliente o empleado escribe pedidos, sus detalles/historial, operaciones ni contador de pedidos.
- Direcciones: lectura/alta/edición propias, sin cambiar propietario, con límites y coordenadas válidas; sin borrado desde la app.
- Productos y lotes: se conserva lectura del catálogo; toda escritura móvil se deniega.
- Registro de farmacia, reserva de NIT y contador FARM conservan sus reglas anteriores.

Admin SDK omite las reglas; por eso las verificaciones de autorización y negocio están en el servidor. Ninguna regla abierta ni transacción móvil sustituye esta validación. No se publicaron las reglas propuestas.

## Pruebas y verificación

Comandos ejecutados: `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test` y la suite Emulator indicada abajo. Se formatearon después solo los archivos de esta etapa para mantener el diff acotado.

| Verificación | Resultado |
|---|---|
| Dependencias Flutter | Resueltas; sin actualizar deliberadamente otras dependencias |
| Análisis Flutter | Sin observaciones |
| Suite Flutter | 88 aprobadas: 77 existentes + 11 de checkout/mapeo |
| Emulator inicial | 20 pruebas aprobadas, incluidas concurrencia, reglas y callable autenticado |
| Emulator final | 21 pruebas aprobadas, incluida la denegación del callable fuera de emuladores |
| APK debug `main_emulator.dart` | Compilado correctamente: `build/app/outputs/flutter-apk/app-debug.apk` |

Cobertura de backend: pedido válido, carrito vacío/cantidades inválidas, producto inactivo, precio modificado, insuficiencia de stock, lotes vencidos, varios lotes FEFO, FIFO determinista, dos clientes simultáneos, insuficiencia por concurrencia, rollback tras preparar escrituras, doble envío y reintento con el mismo ID, farmacia/usuario/rol no autorizados, dirección ajena/inactiva, contador ausente, IDs únicos y compatibilidad con `PED001`. Las reglas prueban denegación de inventario/precios/pedidos/contador/operaciones, aislamiento entre farmacias, permisos del personal, direcciones y registro FARM/NIT atómico con rechazo de duplicados.

Las pruebas Dart cubren doble pulsación, carrito vaciado solo tras éxito, precio cambiado y segunda revisión, timeout/reapertura/consulta sin reenviar, consulta sin resultado sin compra nueva, reintento con payload original, fallo del almacenamiento, carrito editado durante el envío, cambio de cuenta, bloqueo productivo, rechazo de resultados cacheados y mapeo histórico. Las pruebas existentes conservan cancelaciones, reprogramaciones, roles, registro y demostración.

El emulador se ejecutó con Java 21 y Node 26 disponibles en este equipo; `functions/package.json` declara Node 22. La CLI usa Node 26 y avisa la diferencia. Se debe repetir la verificación en Node 22 antes de considerar un despliegue. Los emuladores verifican lógica y reglas, no latencia, cuotas, índices desplegados ni comportamiento de Android. No se declara una prueba manual Android ni de recuperación SQLite en un dispositivo físico.

## Cómo probar sin tocar producción

Desde la raíz, con Node/npm, Java 21, Firebase CLI y Flutter disponibles:

```powershell
npm.cmd --prefix functions ci
flutter pub get
firebase.cmd emulators:exec --config firebase.emulator.json --project demo-pharmalab --only auth,firestore,functions "npm.cmd --prefix functions test"
```

La suite borra exclusivamente la base del emulador ficticio antes de cada caso. Nunca ejecutar esas pruebas contra una exportación con información que se quiera conservar. El test verifica explícitamente los hosts locales antes de borrar.

Para probar la app, mantener los emuladores abiertos en una terminal:

```powershell
firebase.cmd emulators:start --config firebase.emulator.json --project demo-pharmalab --only auth,firestore,functions
```

En otra terminal, cargar fixtures locales:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
node functions/seed-emulator.js
```

En Android Emulator:

```powershell
flutter run -d <id-android> -t lib/main_emulator.dart --dart-define=EMULATOR_HOST=10.0.2.2
```

Para dispositivo Android por USB, ejecutar `adb reverse tcp:8080 tcp:8080`, `adb reverse tcp:9099 tcp:9099`, `adb reverse tcp:5001 tcp:5001` y usar `--dart-define=EMULATOR_HOST=127.0.0.1`. No hace falta exponer los puertos del emulador a la red. El permiso HTTP agregado solo afecta builds debug.

Credenciales exclusivamente de prueba: `cliente-demo-a@example.com` y `cliente-demo-b@example.com`, contraseña `pharmalab123`.

1. Entrar con la cuenta A, verificar indicador de entorno local. Añadir 8 cajas de Paracetamol y seleccionar su dirección. Confirmar: Bs 1.200, 5 cajas del primer lote y 3 del segundo.
2. Revisar número real devuelto, detalle e historial. La cuenta B no debe ver el pedido de A ni seleccionar su dirección.
3. Hacer compras simultáneas que excedan el stock: una debe ser rechazada y no debe quedar inventario negativo.
4. Cambiar el precio solo en el emulador antes de confirmar; exigir revisión del nuevo importe y nueva pulsación.
5. Interrumpir la red durante el envío, cerrar/reabrir la pantalla o la app, entrar con el mismo UID y usar Carrito → Consultar confirmación pendiente. Consultar antes de reintentar; comprobar que el ID y el pedido no se duplican. Este recorrido manual sigue pendiente de ejecución en dispositivo.
6. Probar alta de otra dirección; no se modifica la dirección fiscal del registro de farmacia. El pedido conserva su copia aunque la dirección se edite después.
7. Para comparar demostración, usar `flutter run -t lib/main_demo.dart`. Las cancelaciones y demás operaciones locales continúan disponibles. Para arranque normal usar `lib/main.dart`: confirmación productiva deshabilitada.

## Qué falta para producción

Demostración: conserva el ciclo completo local y la cola sin conexión en memoria. Emulador: confirmación, transacción de inventario, idempotencia, dirección propia, historial y seguimiento remoto; cancelaciones/aprobación/despacho/entrega remotos permanecen deshabilitados. Producción: autenticación, registro y catálogo existentes siguen funcionando; la lectura de pedidos/direcciones requiere publicar previamente la propuesta revisada de reglas e índices. La app no hace fallback a pedidos demo ante errores de permisos.

Para habilitar compras se necesita una decisión y autorización explícitas sobre backend/plan/costos; repetir pruebas en Node 22 y Android, revisar IAM/App Check/abuso y observabilidad, auditar esquema/fechas/direcciones/farmacias y números comerciales, preparar el contador de pedidos con autorización, desplegar/revisar índices y reglas y realizar pruebas de aceptación en un entorno separado. Solo después se debe cambiar deliberadamente el bloqueo del servidor y cliente. No se activó facturación ni se desplegó ningún servicio de pago.

Antes de habilitar cancelaciones reales se necesita un comando autenticado que aplique `OrderPolicy`, valide estado/despacho y restituya exactamente las asignaciones originales una sola vez con su historial en una transacción. Este trabajo queda fuera de la etapa actual; no hay un botón que simule una cancelación remota exitosa.

Referencias oficiales consultadas: [transacciones Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions), [callables autenticados](https://firebase.google.com/docs/functions/callable), [emulación de Functions](https://firebase.google.com/docs/functions/local-emulator) y [conexión de Firestore Emulator](https://firebase.google.com/docs/emulator-suite/connect_firestore).
