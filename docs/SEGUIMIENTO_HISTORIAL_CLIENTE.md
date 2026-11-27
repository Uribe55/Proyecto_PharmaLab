# Seguimiento e historial del Cliente Farmacia

27/11/2026. Alcance: RF-15 (sin push) y RF-16. Proyecto: `proyecto-pharmalab`; API existente: `https://pharmlab-api.onrender.com`.

## Estado inicial y componentes reutilizados

`ClientShell` ya contiene la pestaña **Mis pedidos**, que abre `OrderHistoryScreen`. Se reutilizan esa pantalla, `OrderTrackingScreen`, `OrderHistoryViewModel`, `RemoteOrderRepository`, `FirestoreOrderDataSource`, `FirestoreOrderReader`, `FirestoreOrderMapper`, `PharmacyOrder`, `OrderLine`, `OrderHistoryEvent`, los encabezados del cliente, `StatusChip`, filtros y tarjetas existentes. No se crearon pantallas, servicios ni modelos paralelos.

La lista anterior cargaba hasta 50 pedidos y después consultaba el padre, detalle e historial de cada uno. El seguimiento volvía a efectuar lecturas completas ante eventos de sus listeners. Su línea de tiempo marcaba etapas anteriores como realizadas por su posición respecto al estado actual, sin evidencia individual de esas etapas.

Se revisaron también las reglas Render y los contratos de `functions/src/orders.js` y `order_actions.js`. No fue necesario modificarlos. La confirmación, inventario, FEFO, idempotencia, cancelaciones y operaciones del vendedor/repartidor se conservan.

## Mis pedidos e historial general

La relación utilizada es **sesión UID → farmacia asociada en PharmaService → pedidos.id_cliente = FARM###**. El ID de usuario no se emplea como ID de farmacia. Se captura UID y farmacia al abrir el stream y se comprueba que sigan correspondiendo a la sesión al recibir datos. El ViewModel reinicia el feed si cambia cualquiera de ellos, incluso cuando la farmacia se termina de cargar después del usuario. Una generación de suscripción descarta callbacks de sesiones o ventanas anteriores.

Se mantiene una sección unificada con filtros horizontales: Todos, Activos, Historial, Pendientes, Aprobados, En ruta, Entregados, Fallidos, Cancelados y Reprogramados. No son estados nuevos de Firestore. Activos incluye pendiente, aprobado, en ruta, fallida y reprogramado. Historial reúne entregados y cancelados. En el contrato existente **fallida no es definitiva**: queda pendiente de coordinación; por eso no se traslada automáticamente a compras finalizadas. Si en el futuro se define un cierre definitivo de fallidos, deberá incorporarse mediante su contrato explícito, no por suposición visual.

Los pedidos se ordenan por `fecha_pedido` descendente. La ventana comienza en 50 y **Cargar más pedidos** la amplía de 50 en 50, cancelando la suscripción anterior. Esto permite consultar pedidos anteriores sin crear otro historial. Es una ventana acumulativa, no paginación por cursor: conserva tiempo real sobre lo ya cargado, pero ampliar la ventana puede volver a transmitir documentos. Los filtros operan sobre los pedidos cargados; cuando quedan posibles páginas, un filtro vacío explica que se pueden cargar pedidos anteriores.

Cada tarjeta muestra número comercial, fecha/hora real disponible, estado, descripción, cantidad de productos distintos e importe histórico. Se muestran **Seguir pedido** o **Ver detalle** según sea activo o finalizado. Los detalles de varias presentaciones de un mismo producto no se confunden con lotes. Los pedidos históricos sin líneas resumidas en el padre muestran «Productos: ver detalle» hasta abrir el detalle, evitando una consulta por tarjeta y un conteo falso de cero.

Hay estados de carga, lista vacía, error, reintento y aviso de información posiblemente desactualizada. Los filtros admiten desplazamiento horizontal. Se verificó también la lista a 390 × 844.

## Detalle, seguimiento y origen de los datos

`FirestoreOrderReader.watchClient()` combina estas fuentes autorizadas:

| Fuente | Información |
| --- | --- |
| `pedidos/{id}` | Número comercial, estado, total, farmacia, dirección congelada, fechas y relación con entrega |
| `pedidos/{id}/detalle_pedido` | Todas las líneas: DET001, DET002 y las restantes; productos, presentaciones, cantidades y precios históricos |
| `pedidos/{id}/historial_estado` | Transiciones, fechas y notas realmente registradas |
| `entregas/{id_entrega}` | Estado logístico, fecha de asignación/creación, programación e incidencia disponibles |

Hay un listener por fuente y solo para el pedido abierto. La entrega se escucha por ID y se comprueba su `id_pedido`; al cambiar la relación se cancela el listener anterior. Se cancelan todos al cerrar la pantalla. No se listan entregas del cliente por consulta amplia, no se leen empleados privados y no se consulta Render para seguir estados.

Cada fuente usa eventos de metadatos. La vista indica caché, escrituras pendientes o espera del primer snapshot de entrega; al confirmarse desde servidor se retira el aviso aunque los documentos no hayan cambiado. Si un stream falla después de haber recibido información, se conserva la última vista con una advertencia. La autorización de sesión/farmacia también se comprueba al mostrar el detalle.

La lista usa únicamente el documento principal: aprovecha `lineas` para `transactional_multi_v1` y `linea` para `spark_single_v2`. No abre detalles, historiales, catálogos ni entregas por cada tarjeta. Al abrir un pedido sí escucha la subcolección completa de detalles. Si no hay detalles disponibles, puede usar el snapshot histórico del padre, sin sumar ambas fuentes ni duplicar productos por asignaciones de lotes.

El detalle conserva cantidades comerciales, presentaciones y precios unitarios guardados. Los subtotales almacenados tienen prioridad; si no existen, se usa cantidad × precio unitario histórico. El total general procede del pedido. No se consulta el catálogo para recalcular precios o disponibilidad.

## Línea de tiempo y eventos incompletos

Las etapas son confirmación, aprobación, asignación, inicio de recorrido y entrega. Cada etapa se marca únicamente con evidencia: fecha de creación, fecha específica, evento real de ese estado, estado actual explícito o relación `id_entrega` para asignación. No se infiere que todas las anteriores se realizaron solo porque el pedido esté avanzado.

La fecha de asignación puede proceder de `entrega.fecha_creacion`: se muestra como información logística, **no se inserta un evento de historial inventado**. La aprobación usa `fecha_aprobacion`; el despacho `fecha_despacho`; la entrega la fecha logística real y los eventos existentes. Las incidencias/cancelaciones se distinguen del recorrido exitoso y no marcan entrega realizada.

Debajo se presenta el historial cronológico disponible: estado anterior → nuevo, fecha/hora y nota o descripción. Se contemplan los formatos de eventos `fecha`/`fecha_cambio`, `estado`/`estado_nuevo` y `nota`/`observaciones`. Los eventos reconocibles sin fecha se muestran como «Fecha no registrada» y al final; `atKnown` impide presentar el valor interno de ordenación como una fecha real. Los eventos con estados ajenos al contrato no se interpretan como transiciones válidas. No se modifica ningún antecedente en Firestore.

Las fechas se muestran en hora local del dispositivo. La vista y el resumen compartido no presentan 1970 como una fecha histórica cuando falta la creación.

## Entrega y límites de información histórica

Se muestran dirección y referencia congeladas, estado logístico, programación, despacho, entrega efectiva e incidencia cuando existen. El nombre del repartidor solo se muestra si está en un snapshot autorizado del pedido/entrega (`repartidor_nombre`). El backend actual puede no almacenarlo: en ese caso se indica **Repartidor asignado**, sin consultar `empleado` ni exponer su ID como nombre.

Los pedidos antiguos que no guardaron nombre, presentación o dirección histórica no pueden recuperar esos datos del pasado. Se conservan identificadores/fallbacks e indicaciones de información no disponible, sin presentar nombres o direcciones actuales como históricos. Los registros consultables por la lista deben conservar `fecha_pedido`, ya que Firestore excluye los documentos sin ese campo en una consulta ordenada por él; no se realizó reparación de datos antiguos.

Se muestra el estado reprogramado y sus eventos si existen; no se implementa reprogramación remota ni se inventa una nueva fecha. No hay GPS, mapas, ETA, chat, notificaciones push ni cambios de facturación.

## Seguridad, reglas e índices

Se reutilizan `readsOrder()`, `ownsFarm()`, `ownsDelivery()` y `canReadDelivery()` de **firestore.render.rules**. Las consultas de lista se limitan por `id_cliente`; detalles e historial se autorizan mediante el padre. La entrega se lee individualmente, operación ya permitida para el propietario. No se ampliaron permisos sobre entregas ni empleados.

No se modificaron `firestore.render.rules`, `firestore.rules`, `firestore.indexes.json`, credenciales, transacciones ni backend. No hace falta publicar reglas nuevas ni volver a desplegar Render.

Se mantiene el índice compuesto que ya usaba la consulta anterior y que está definido en `firestore.indexes.json`:

| Colección | Campo 1 | Campo 2 |
| --- | --- | --- |
| `pedidos` (COLLECTION) | `id_cliente` ASCENDING | `fecha_pedido` DESCENDING |

No se agregó otro índice. Si ese índice todavía no está publicado en un entorno, deberá crearse manualmente con esos campos en Firebase Console; el emulador no demuestra su existencia en producción. Esta intervención no accedió a la consola ni publicó índices.

## Archivos

Modificados:

- `lib/screens/cliente_farmacia/order_history_screen.dart`
- `lib/screens/cliente_farmacia/order_tracking_screen.dart`
- `lib/viewmodels/order_history_view_model.dart`
- `lib/data/datasources/firestore_order_data_source.dart` (solo consulta de lista/detalle)
- `lib/data/datasources/firestore_order_reader.dart` (nuevo método de lectura para cliente; se conserva el lector compartido de otros roles)
- `lib/data/mappers/firestore_order_mapper.dart`
- `lib/models/order.dart` y `lib/models/order_lifecycle.dart` (campos opcionales de lectura y evidencia temporal)
- `lib/utils/formatters.dart` (fecha desconocida en resumen)

Creados: `test/client_order_history_test.dart`, `functions/test/client_tracking.rules.cjs` y este documento. El archivo Node nuevo contiene pruebas; no modifica la API de Render.

## Verificaciones

- `flutter test`: **202 pruebas aprobadas**, incluidas seis nuevas de filtros, orden, precios/fechas históricas, múltiples productos y lotes, historial, estados reactivos, asignación, caché, cancelación y cierre de listeners.
- `flutter analyze`: sin incidencias.
- Seguridad: **105 pruebas aprobadas**, incluidas dos nuevas de aislamiento/permisos y las 103 regresiones de Spark, logística y empleados. El proceso terminó correctamente (código 0).

Las pruebas nuevas de seguridad comprueban UID distinto de FARM, ambos esquemas, acceso a las dos líneas y a la entrega propia, rechazo de otra farmacia y de empleados privados, rechazo de escrituras de estado/precio/historial/entrega/stock. Los cambios de estado en vivo y caché→servidor se verifican en las pruebas Flutter. Solo usan Firestore Emulator, con guardas para localhost; no se usan datos reales. Se descartaron dos pruebas adicionales de streams del SDK JavaScript porque retenían conexiones al finalizar; sus aserciones pasaron, pero no se cuentan como verificaciones completas.

Las pruebas de widgets usan un repositorio inyectado para controlar las actualizaciones. Las de seguridad usan el SDK JavaScript y reglas reales en el emulador; no sustituyen una prueba de la nueva APK en Android operacional. No se repitieron pruebas del servidor comercial porque sus archivos no se modificaron. La regresión Flutter conserva los flujos de los cuatro roles.

## Ejecución y actualización

Desde la raíz:

```powershell
flutter analyze
flutter test
flutter run --dart-define=PHARMALAB_API_URL=https://pharmlab-api.onrender.com
flutter build apk --release --dart-define=PHARMALAB_API_URL=https://pharmlab-api.onrender.com
```

Instalar la APK como actualización conservando los datos locales. No usar flags de emulador en esa ejecución.

Para repetir la seguridad, desde `functions` (Node 22 y Java instalados):

```powershell
firebase.cmd emulators:exec --project demo-pharmalab-security --config ../firebase.logistics-test.json --only firestore "node --test --test-concurrency=1 test/client_tracking.rules.cjs test/spark_checkout.rules.cjs test/logistics.rules.cjs test/employees.rules.cjs"
```

No se hicieron commits, push, despliegues, migraciones ni modificaciones operacionales. Queda pendiente la comprobación manual de esta APK en el teléfono real con el índice ya publicado y pedidos autorizados de prueba; el flujo del servidor existente sigue siendo el mismo.


