# Pedidos múltiples transaccionales — 27/11/2026

> Actualización: la adaptación HTTP independiente para Render está implementada y documentada en [CONFIGURACION_RENDER.md](CONFIGURACION_RENDER.md). Los apartados siguientes describen la etapa anterior de emuladores. Los callables mantienen su bloqueo local; la nueva API es otra entrada a las mismas transacciones. No se ha realizado el despliegue operacional.

## Estado y decisión de infraestructura

La confirmación múltiple está implementada e integrada en **Firebase Emulator Suite**. Producción mantiene `spark_single_v2`: un producto y un lote por pedido. No se cambió el plan, no se desplegaron Functions ni reglas, no se accedió a datos reales y no se ejecutaron migraciones, commits o push.

El paso pendiente es decidir y autorizar un backend de producción. El contrato implementado usa Admin SDK detrás de callables autenticados. Cloud Functions requiere Blaze para desplegarse; usar sus emuladores no requiere activar ese plan. La aplicación y el backend rechazan expresamente invocar esta ruta contra producción. Ni un `dart-define` ni un despliegue accidental la habilitan: se exige proyecto `demo-pharmalab`, indicador de emulación y endpoints locales de Firestore y Authentication.

Fuentes oficiales consultadas:

- [Límites de reglas: 10 accesos por operación y 20 por transacción](https://firebase.google.com/docs/firestore/security/rules-conditions#access_call_limits).
- [Transacciones atómicas y reintentos](https://firebase.google.com/docs/firestore/manage-data/transactions).
- [Emulación de Functions y requisito Blaze para desplegar](https://firebase.google.com/docs/functions/get-started).

Se evaluó un contrato Spark acotado: es posible diseñar variantes pequeñas con validaciones desenrolladas, pero no se puede trasladar sin más el contrato actual de una línea. Este ya utiliza hasta 10 accesos en la validación del pedido. Añadir productos, pares antes/después de lotes, detalles, propietario, contador y registro idempotente presiona el límite global de 20 accesos. Además, las reglas no consultan todos los lotes del producto para comprobar una selección FEFO exhaustiva. Una preselección desde Flutter no es una fuente confiable frente a clientes manipulados. No se declara que toda variante acotada sea imposible; se eligió el backend para la operación solicitada, con consulta completa acotada, conversiones y restitución histórica verificadas en servidor, sin debilitar reglas.

## Auditoría y compatibilidad

Se revisaron la estructura de `lib/`, modelos, servicios, repositorios, fuentes Firestore, ViewModels, contadores, reglas, índices y pruebas. La limitación se encontró en `SparkCheckout.item`, `SparkCheckout.prepare`, `FirestoreSparkCheckout`, `CheckoutViewModel.scopeError` y las funciones `validSparkOrder/newSparkParent` de las reglas.

Existía `functions/src/orders.js`, bloqueado a emuladores. Ya distribuía cantidades entre lotes, pero usaba numeración `PL-*`, un contador incompleto, detalles identificados solo por producto, no excluía lotes inactivos/bloqueados ni validaba deuda, y no estaba conectado a la aplicación actual. Se consolidó ese código, en lugar de crear un segundo backend de confirmación.

| Operación | Componentes revisados/integrados |
| --- | --- |
| Añadir/modificar cantidades | `CartService`, `CartViewModel`, `ProductCard`, `ProductDetailScreen`, `QuantityStepper` |
| Disponibilidad por lotes | `CatalogRepository`, `ProductBatch`, `CatalogViewModel`, `inventory.js` |
| Total y revisión | `CartItem`, `CheckoutViewModel`, `CheckoutScreen` |
| Confirmación real Spark | `FirestoreOrderDataSource`, `FirestoreSparkCheckout`, `SparkCheckout` |
| Confirmación múltiple local | `EmulatorOrderGateway`, callable `confirmOrder`, `orders.js` |
| Numeración | `CommercialNumber`, `configuracion/contadores_pedidos`, transacción backend |
| Recuperación | SQLite `PendingCheckoutStore`, `operaciones_pedido`, huella SHA-256 |
| Lectura de pedidos | `FirestoreOrderReader`, `FirestoreOrderMapper`, repositorios de cliente/personal y dashboard |
| Aprobar | `FirestoreStaffOrderDataSource`, `SparkApproval`: solo estado + evento, sin descontar stock |
| Asignar y entregar | `FirestoreLogisticsDataSource`, `order_actions.js`, una entrega por pedido |
| Cancelar | `RemoteCancellationPanel`, callable `cancelOrder`, asignaciones históricas |
| Demostración local | `OrderRepository` conserva su flujo en memoria y sus unidades comerciales |

Se conservaron las colecciones principales y auxiliares, las subcolecciones y los campos históricos. No se añadió stock a `productos`. No se cambió el scroll administrativo ni se rediseñaron perfiles, autenticación o navegación. Los cambios de interfaces del trabajo anterior permanecen en el árbol de trabajo.

## Contrato de confirmación

Entrada: `operationId`, `addressId`, `notes` y `items` con `productId`, `quantity`, `expectedPriceCents` y, solo para presentaciones explícitas, `presentationId`. El cliente no puede elegir farmacia, lote, precio autorizado, total ni factor de inventario. Campos adicionales de esos tipos no se utilizan para calcular la compra.

El servidor valida usuario cliente activo, relación única con farmacia activa, deuda vencida de usuario/farmacia y dirección propia activa. Consulta productos y todos sus lotes dentro de la transacción. Verifica precios en centavos, asigna cantidades y calcula el total; después escribe pedido, detalles, evento, movimientos, lotes, contador y operación. **Todas las lecturas preceden las escrituras.** Si falla una línea, no se guarda ni descuenta nada.

El ID técnico es `ORD_` + SHA-256 de UID e ID de operación. La numeración comercial continúa como `PED###`, con el mismo contador y sus campos `ultimo_numero`, `ultimo_id`, `ultimo_documento_id`. Un contador ausente/inconsistente se rechaza; no se reinicia ni reemplaza automáticamente. La operación guarda huella del contenido y resultado. Reintentar contenido idéntico recupera el resultado incluso tras cancelación; otro contenido con el mismo ID se rechaza.

El ViewModel conserva el payload en SQLite antes de enviarlo, bloquea pulsaciones simultáneas, recupera el resultado del servidor y solo vacía el carrito correspondiente después del éxito. Un timeout conserva ID y contenido. Las compras offline no se encolan para confirmarse sin verificación: el callable/lectura de servidor debe responder.

## Lotes, fechas y unidades

`inventory.js` contiene la política independiente de widgets. Excluye stock no entero/no positivo, lotes inactivos, bloqueados o no comercializables, fechas inválidas, vencidos y ausencia de fecha cuando es obligatoria. FEFO ordena por vencimiento. Sin obligación de vencimiento aplica FIFO por `fecha_ingreso`, luego `fecha_creacion`; las fechas ausentes van después de las válidas y el desempate usa ID. La falta de fecha de ingreso impide reconstruir FIFO físico exacto: el ID solo aporta determinismo.

El vencimiento corresponde al **día comercial de Bolivia (UTC−4), inclusivo**: un lote sigue vigente durante su fecha de vencimiento y deja de serlo al día siguiente. Los Timestamp se interpretan como instantes. Catálogo y backend usan esa política; el catálogo recalcula periódicamente el vencimiento y el servidor vuelve a validarlo al confirmar. La ruta histórica Spark conserva su comprobación más restrictiva por instante; no se amplió silenciosamente ese contrato.

Los productos actuales descuentan unidades comerciales. `unidad_por_envase: 20` significa contenido de una caja; no multiplica su descuento. Para inventario base se admite una ampliación **optativa**, configurada por personal autorizado:

```json
{
  "inventario_unidad": "base",
  "presentaciones_venta": [
    {"id": "blister", "nombre": "Blíster", "unidades_base": 10, "precio": 15, "estado": true},
    {"id": "caja", "nombre": "Caja", "unidades_base": 20, "precio": 28, "estado": true}
  ]
}
```

Esos lotes deben estar contados en unidades base antes de habilitar la configuración. **No se convirtió ningún dato existente.** El catálogo muestra presentaciones autorizadas; el carrito usa clave producto/presentación y suma el consumo base compartido. Tres blísteres y dos cajas consumen 70 de las mismas 100 unidades. Una modificación de catálogo conserva las cantidades y bloquea la revisión si ya no caben. La ruta Spark rechaza productos con inventario base para impedir saltarse el backend.

## Esquema compatible

Nuevo pedido: `schema_version: transactional_multi_v1`, con los campos existentes de propietario, fecha, dirección, estado, total y número; añade `lineas` como snapshot completo y `stock_restituido`.

Cada detalle `DET001...` incluye campos existentes `id_producto`, `cantidad`, `precio_unitario`, `subtotal`, nombre, marca, presentación y unidad. Añade `id_presentacion` cuando corresponde, `factor_inventario`, `cantidad_inventario`, `unidad_inventario` y `asignaciones_lotes`. Conserva categoría histórica cuando está disponible. Los precios actuales del catálogo no recalculan el pedido registrado.

Los movimientos `pedidos/{id}/movimientos_inventario/SALIDA_{lote}` y `RESTITUCION_{lote}` registran producto, lote, cantidad firmada, usuario, tipo y fecha. `detalle_pedido` y `lineas` representan las mismas líneas; los lectores usan una fuente de líneas, no las suman. El dashboard cuenta una vez el pedido y calcula rankings con sus cantidades/precios históricos.

El ejemplo completo está en `PEDIDO_MULTIPLE_EJEMPLO.json`: tres productos, cuatro asignaciones de lotes y un solo total. Las fechas del JSON representan Timestamp; no es una exportación ni un registro creado en producción.

## Cancelación y logística

Un cliente puede cancelar su pedido pendiente; un aprobado requiere solicitud y aceptación del vendedor/administrador. Se permite rechazar la solicitud sin devolver stock. La cancelación autorizada lee el pedido, entrega y todos los lotes históricos, valida sus productos y sumas, restituye exactamente cada asignación y marca `stock_restituido` en la misma transacción. El evento y los IDs de movimientos impiden duplicados. Si falta un lote, aborta en vez de devolver a otro lote.

No se restituye un pedido en ruta, entregado o fallido, ni una entrega que ya comenzó. La entrega fallida mantiene la reserva. Un lote vencido después de la compra recupera existencias físicas al cancelar, pero el catálogo lo sigue excluyendo de la venta. No se añadió un sistema de devoluciones físicas ni una nueva reprogramación remota.

La aprobación existente permanece atómica y no cambia stock. La asignación múltiple crea una sola entrega `transactional_logistics_v1`, idempotente para el mismo repartidor, con todos los productos y cantidades, sin importes comerciales. Despacho, entrega exitosa y fallo solo actualizan estado, historial y cantidades entregadas; no descuentan inventario otra vez. Los pedidos/logística Spark e históricos siguen usando sus adaptadores existentes.

## Seguridad y límites

El Admin SDK no está sujeto a las reglas: la autorización y validación completas están en los callables, no en datos enviados por el cliente. Las reglas mantienen la creación directa limitada al esquema Spark y los campos protegidos. Se bloqueó el bypass Spark para deuda vencida, inventario base y lotes bloqueados, no comercializables o vencidos. Los movimientos son legibles solo por quienes pueden leer el pedido y no admiten escrituras de ningún cliente. No se añadió permiso de creación directa para el esquema múltiple.

| Límite | Aplicación y razón |
| --- | --- |
| 20 líneas comerciales | UI/ViewModel y servidor; acota snapshots, lecturas, latencia y tamaño del pedido |
| 10.000 presentaciones por línea | UI y servidor; acota cantidades y aritmética; factor autorizado de 1–10.000 |
| 100 lotes registrados por producto | Query transaccional de 101 para detectar exceso; rechaza la compra, no trunca FEFO |
| 100 lotes distintos usados | Servidor; como máximo 224 escrituras en confirmación: 100 lotes + 100 movimientos + 20 detalles + pedido/evento/contador/operación |
| 500 KB de líneas serializadas | Servidor; margen frente al límite de documento y a la duplicación controlada del snapshot |
| Bs 10.000.000 por pedido | Servidor; aritmética entera en centavos y límite operativo explícito |
| 500 caracteres de notas | Cliente/backend; conserva el contrato anterior |

Los límites de 20/100 son límites operativos conservadores, no se presentan como los límites nativos exactos de Firestore. En el peor caso se inspeccionan hasta 2.000 lotes más metadatos; una instalación con alto volumen necesita paginación/consolidación o un servicio con un índice de inventario autorizado. También siguen vigentes los límites de tiempo, tamaño de transacción y cuotas de Firebase. Los excesos no generan compras parciales ni división del carrito. La UI explica líneas/cantidades/lotes utilizados y el backend comunica los límites de configuración de inventario cuando los encuentra.

## Archivos de esta intervención

Creados:

- `functions/src/inventory.js`, `functions/src/order_actions.js`, `functions/test/inventory.test.js`.
- `lib/data/datasources/emulator_order_gateway.dart`, `lib/widgets/remote_cancellation_panel.dart`.
- `test/multi_order_test.dart` y estos informes/ejemplo.

Modificados:

- `functions/src/orders.js`, `functions/src/index.js`, `functions/seed-emulator.js`, `functions/test/orders.test.js`, `functions/test/spark_checkout.rules.cjs`.
- `firestore.rules`, `pubspec.yaml`, `pubspec.lock` (cliente oficial `cloud_functions`; sin actualizar las demás dependencias).
- `lib/data/datasources/firestore_order_data_source.dart`, `firestore_logistics_data_source.dart`, `firestore_spark_checkout.dart`; `lib/data/mappers/firestore_order_mapper.dart`; `lib/data/repositories/catalog_repository.dart`, `remote_order_repository.dart`.
- `lib/domain/spark_checkout.dart`; `lib/models/product.dart`, `product_batch.dart`, `order.dart`, `dashboard_models.dart`.
- `lib/services/cart_service.dart`, `dashboard_repository.dart`; `lib/viewmodels/cart_view_model.dart`, `catalog_view_model.dart`, `checkout_view_model.dart`.
- Pantallas cliente `cart_screen.dart`, `checkout_screen.dart`, `order_tracking_screen.dart`; vendedor `remote_seller_orders_screen.dart`; compartida `remote_logistics_screen.dart`; `lib/widgets/delivery_card.dart`.

`firestore.indexes.json` y las configuraciones Firebase permanecen iguales: las consultas nuevas usan filtros de un campo o lectura por ID y no requieren un índice compuesto adicional. No se cambiaron Gradle ni el wrapper.

## Pruebas y ejecución local

Los resultados finales y comandos ejecutados se registran en `PEDIDOS_MULTIPLES_VERIFICACION.json`. No se sustituyen pruebas de reglas por mocks. La suite backend usa Firestore/Auth/Functions reales de Emulator Suite y prueba rollback, doble confirmación, concurrencia, selección de lotes, presentaciones, cancelaciones, límites y callables autenticados. Las suites de reglas comprueban ataques y regresiones Spark/logística/empleados. Flutter comprueba además recuperación local, cantidades, catálogo, mapeo histórico y conteo administrativo.

La suite Flutter completa aprobó 192 pruebas. El último endurecimiento Spark se comprobó además con 28 pruebas dirigidas; el analizador y la compilación Android se ejecutaron nuevamente. La suite backend aprobó 41 pruebas. Los fallos intermedios de expectativas históricas y rango horario de una prueba se corrigieron; un conflicto de servicios auxiliares al iniciar emuladores obligó a repetir la ejecución secuencialmente. No se modificaron pruebas para permitir escrituras inseguras.

Para reproducir en PowerShell (dos terminales para pruebas independientes):

```powershell
flutter pub get
npm.cmd --prefix functions ci --ignore-scripts --no-audit --no-fund
firebase.cmd emulators:exec --project demo-pharmalab --config firebase.emulator.json --only auth,firestore,functions "npm.cmd --prefix functions test"
Push-Location functions
firebase.cmd emulators:exec --project demo-pharmalab-security --config ../firebase.logistics-test.json --only firestore "node --test --test-concurrency=1 test/spark_checkout.rules.cjs test/logistics.rules.cjs test/employees.rules.cjs"
Pop-Location
dart format lib test
flutter analyze
flutter test
```

Prueba manual de la aplicación contra emuladores, sin importar respaldos reales:

```powershell
firebase.cmd emulators:start --project demo-pharmalab --config firebase.emulator.json --only auth,firestore,functions
# En otra terminal:
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
node functions/seed-emulator.js
flutter run -t lib/main_emulator.dart --dart-define=EMULATOR_HOST=10.0.2.2
```

La semilla solo crea documentos demo ausentes; no restablece existencias de un entorno ya usado. Para teléfono físico, hacer `adb reverse tcp:8080 tcp:8080`, lo mismo para `9099` y `5001`, y usar `EMULATOR_HOST=127.0.0.1`. Los usuarios demo son `cliente-demo-a@example.com`, `cliente-demo-b@example.com`, `vendedor-demo@example.com`, `repartidor-demo@example.com`, `admin-demo@example.com`, contraseña exclusivamente demo `pharmalab123`.

## Pendientes y riesgos

- Autorizar la infraestructura de producción y revisar autenticación/App Check, IAM, cuotas, monitoreo y límites operativos antes de retirar el bloqueo deliberado. No hay comando de despliegue automático en esta entrega.
- Publicación manual de las reglas locales, solo después de revisión y autorización. No requiere migrar datos históricos; el endurecimiento de deuda puede impedir nuevas compras de cuentas con deuda que antes se aceptaban.
- Presentaciones base: revisión/conversión autorizada del inventario físico antes de configurarlas. No se ofrece una migración automática ni se infieren factores de textos de presentación.
- Verificación manual en teléfono de la conexión al nuevo callable y del flujo de los cuatro roles; las pruebas automatizadas no equivalen a una sesión visual en un dispositivo físico.
- La reprogramación remota después de un fallo y las devoluciones físicas no se ampliaron. Los cambios no deben confundirse con esas funciones ni con producción ya habilitada.
- Los archivos generados y `functions/node_modules` vuelven a ocupar espacio mientras se ejecutan pruebas; son regenerables y no forman parte de los cambios de código.
