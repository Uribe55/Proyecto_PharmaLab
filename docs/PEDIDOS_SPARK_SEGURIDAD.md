# Pedidos con Firebase Spark — 25/11/2026

## Resultado y alcance real

**Todavía no se pueden confirmar pedidos reales.** Crear pedidos y descontar lotes sigue bloqueado en las reglas publicadas y en la aplicación. No se enviaron escrituras comerciales de prueba. No se activó facturación, no se crearon bases de datos, no se ejecutaron emuladores ni Cloud Functions y no se hicieron commits, merges o push.

Se implementó la recepción del vendedor mediante `snapshots()`, contador de pendientes, filtros, detalles e historial con actualización en vivo y aviso visual de nuevos pedidos mientras la app está abierta. Usa exclusivamente Firestore en `main.dart`; no usa pedidos locales ni promete notificaciones push con la app cerrada. La integración con el SDK está implementada, pero no se probó una sesión real de vendedor en el teléfono ni una nueva compra real.

La transición de aprobación está preparada con una transacción de dos escrituras, pero su interruptor `SparkApproval.enabled` permanece en `false`. Los dobles de transacción no prueban el motor de Firestore Rules. Sin un entorno aislado autorizado para probar los rechazos de seguridad, no se habilita la operación.

## Revisión y sincronización de reglas

La rama inicial fue `pedidos-firestore-transaccionales` y `git status --short` estaba limpio. Se revisaron autenticación, catálogo comercial, carrito, checkout, repositorios, vendedor, seguimiento, Functions heredadas y pruebas existentes.

Se descargó la release real `projects/proyecto-pharmalab/releases/cloud.firestore` usando **GET** de Firebase Rules API con una sesión local existente. El ruleset publicado por el usuario es `33f8ba18-0155-4332-bbee-bad53090d818`, actualizado el 25/11/2026. `firestore.rules` contiene su fuente completa sincronizada; no es una propuesta desplegada por esta tarea. El identificador y SHA-256 están en `SPARK_REGLAS_PUBLICADAS.json`.

Se conservó íntegra la sección publicada de registro transaccional: perfil cliente, `FARM###`, contador de farmacias y reserva única de NIT. No se alteró el contador ni se ampliaron permisos. Las demás escrituras existentes permitidas son direcciones propias con campos restringidos y aprobación de personal activo con evento determinista. No se añadieron permisos de escritura.

La versión publicada **ya permite** aprobar como vendedor/administrador activo si pedido e historial cumplen sus condiciones. El bloqueo de la app no revoca ese permiso del servidor. No se afirma haber cerrado ese acceso remotamente: modificarlo requiere un cambio de reglas y autorización de despliegue. Las cuentas cliente no reciben ese permiso.

## Auditoría de la confirmación

Una transacción Flutter proporciona atomicidad y reintentos por concurrencia. Un cliente modificado puede omitirla o enviar otra operación. Las invariantes comerciales deben estar en las reglas o en un backend confiable.

| Invariante | Situación del contrato actual |
|---|---|
| 1. Identidad/rol activo | `activeRole`, `activeClient`, documentos `usuarios` inmutables para clientes existentes |
| 2. Propiedad y estado de farmacia | `ownsFarm`, vínculo `usuario_id` y `estado` |
| 3. Dirección propia | Reglas de direcciones por `id_cliente`; falta enlazar la creación de pedido, que sigue denegada |
| 4. Precio autorizado | Se puede comparar con un producto conocido; no existe validación global para todas las líneas del carrito |
| 5. Cantidad entera positiva | Posible para posiciones conocidas; no existe contrato publicado de creación que la imponga |
| 6. Stock válido | Posible para un lote conocido y su estado anterior/posterior; escrituras actuales denegadas |
| 7. Vencimientos | Es posible comparar un lote explícito con `request.time`; no consultar arbitrariamente todos los lotes elegibles |
| 8. Detalles exactos | No hay consultas de subcolecciones ni iteración general para enumerar detalles arbitrarios |
| 9. Cantidad comprada = descontada | Falta una asociación bidireccional, finita y comprobable entre cada detalle y cada lote |
| 10. Atomicidad completa | `getAfter()` puede exigir documentos con rutas conocidas; no descubre todos los documentos de una compra arbitraria |
| 11. Stock no negativo | Se puede comprobar por lote; por sí solo no vincula el descuento con una venta válida |
| 12. Duplicados | Un ID aleatorio evita colisiones, pero hace falta un registro idempotente inmutable vinculado atómicamente al pedido y lotes |
| 13. Cambios arbitrarios de lotes | Denegados actualmente; no se abre un permiso genérico de actualizar cantidades |
| 14. Importes y pedidos ajenos | Cliente no puede crear/editar pedidos ni detalles; lecturas limitadas a farmacia propia |
| 15. Presupuesto de acceso | Máximo 10 accesos por operación y 20 por transacción/batch, además del límite individual; no se puede escalar un contrato ilimitado |

El carrito actual admite varias líneas y el reparto de una línea entre varios lotes. Las reglas no tienen consultas arbitrarias, bucles generales ni un agregado de subcolección para comprobar «todos los detalles» y «todos los descuentos». Validar solo total positivo, propietario y stock no negativo permitiría compras con precios, detalles o descuentos manipulados. No se habilitó ese diseño.

Esto **no significa que Spark prohíba las transacciones comerciales**. Un esquema con un número fijo de líneas/lotes puede protegerse con comprobaciones explícitas y `getAfter()`. Se evaluó una única línea y un único lote: requeriría detalle y evento deterministas, producto/precio vigente, farmacia/dirección propias, lote elegible, delta exacto, vínculo de vuelta desde el lote al pedido, ausencia previa de la operación, campos inmutables y un presupuesto de lecturas demostrado. No basta añadir solo una resta en Dart. Sin pruebas del motor de reglas para ese contrato nuevo, tampoco se habilita la versión reducida.

No se descartan productos del carrito ni se divide una compra en pedidos parciales. No se genera numeración secuencial desde el máximo ID, no se toca el contador de farmacias y no se crea un contador comercial nuevo. Una futura implementación puede usar auto-ID interno y el mismo ID persistido para reintentos, conservando `PED001`.

## Aprobación preparada y límites

`SparkApproval.prepare` lee perfil, pedido y evento `APROBACION` antes de escribir. Exige vendedor/administrador activo, estado `pendiente` y evento ausente. Prepara únicamente:

1. Cambio de `estado`, `aprobado_por` y `fecha_aprobacion` del pedido.
2. Creación de `historial_estado/APROBACION` con estado anterior/nuevo, actor y timestamp del servidor.

No modifica precios, detalles, cantidades, dirección, farmacia ni stock. Ambas escrituras pertenecen al mismo `runTransaction`. El ID de evento es fijo y la lectura del pedido produce conflicto si dos aprobadores compiten; el reintento debe rechazar el estado ya aprobado. Un error no se muestra como éxito.

Las reglas publicadas validan `affectedKeys().hasOnly/hasAll`, estado anterior, actor, `request.time`, ausencia previa del evento y sus campos con `getAfter()`. La regla del evento exige también el cambio del pedido en la misma operación. Los accesos se concentran en tres rutas: usuario, pedido y evento, con estados anteriores/posteriores. El número efectivo de accesos y los rechazos de escrituras parciales siguen pendientes de ejecución en el motor de reglas; no se asume un presupuesto basándose únicamente en que el SDK use una transacción.

No se probaron aprobaciones sobre `PED001`. Está aprobado y el protocolo de aplicación rechaza aprobarlo otra vez. Las reglas tampoco permiten esa transición desde `aprobado`.

## Lecturas, sesiones y datos históricos

- El login usa Authentication y consulta `usuarios/{uid}` desde servidor. El rol no procede de un selector editable por el cliente. Las reglas repiten la autorización del rol activo.
- El vendedor escucha pedidos reales y los ordena en memoria, evitando necesitar un índice compuesto nuevo. El contador incluye todos los pendientes consultados, sin un límite silencioso de 50. Se consultan también detalles, historial y referencias necesarias para mostrar farmacia, dirección y productos.
- La primera respuesta de servidor establece la referencia inicial. No se anuncian pedidos históricos al entrar. Se recuerdan los IDs observados para no repetir avisos ante modificaciones, metadatos o reapariciones. Una respuesta cacheada se identifica visualmente y no genera por sí sola un aviso de llegada confirmado.
- Al cambiar/cerrar sesión se cancelan suscripciones, se descartan respuestas tardías y se eliminan resultados visibles. Un error de permisos muestra un mensaje y limpia datos; no carga semillas.
- El detalle escucha pedido, detalles e historial; el cliente conserva su consulta por farmacia propia y el seguimiento cambia automáticamente al recibir un estado actualizado.
- El lector compartido mantiene precios y total históricos. Completa nombres faltantes en memoria desde referencias actuales; no los presenta como un snapshot histórico ni los escribe en la base. Productos históricos no legibles conservan su ID.
- El login real ya no inicializa semillas. El modo demo permanece separado.
- No hay un SLA de tiempo real ni funcionamiento offline de aprobación: una transacción requiere conexión. Las lecturas y listeners consumen las cuotas Spark. La lista actual carga todos los pedidos y sus detalles; para crecer deberá añadirse paginación y un contador/listener de pendientes separado sin perder avisos ni exactitud.

La comprobación IAM/REST de solo lectura se registra en `SPARK_LECTURA_REAL.json`: versiones de `PED001`, sus dos detalles, historial, dos productos y dos lotes. No verifica permisos del SDK móvil. La última actualización observada de `PED001` y ambos lotes es anterior a esta tarea. No se restauraron cantidades antiguas ni se modificaron precios, presentaciones o unidades por envase.

## Pruebas y evidencia

Resultados finales ejecutados: `flutter pub get` correcto; `flutter analyze` sin incidencias; `flutter test` **112 pruebas aprobadas, cero fallos**; `git diff --check` correcto. Las pruebas nuevas usan dobles de repositorio y transacción. **No son pruebas de reglas ni de concurrencia real contra Firestore.** No se inició Firebase Emulator Suite ni se ejecutaron las pruebas Node heredadas que lo requieren.

| Caso solicitado | Evidencia y estado |
|---|---|
| 1. Cliente autenticado/activo | Lógica de checkout y reglas revisadas; prueba móvil real pendiente |
| 2–3. Farmacia/dirección ajenas | Reglas revisadas; creación denegada globalmente; prueba adversarial de nueva confirmación pendiente |
| 4–5. Precio/cantidad manipulados | Checkout conserva carrito ante rechazo/precio cambiado; no demuestra Rules de una creación nueva |
| 6–7. Lote insuficiente/vencido | Confirmación y escritura de lotes denegadas; no se ejecutaron descuentos reales |
| 8. Compras simultáneas | Nueva confirmación bloqueada; prueba real de concurrencia pendiente |
| 9. Duplicados | Pruebas del coordinador de checkout para doble pulsación y reintento; no prueba de Rules nueva |
| 10. Historial omitido | Protocolo de aprobación siempre prepara dos escrituras; rechazo por Rules pendiente |
| 11–13. Stock sin pedido/pedido sin stock/descuento sin pedido | Reglas publicadas deniegan crear pedidos y cambiar lotes; no se intentaron ataques contra producción |
| 14. Recepción vendedor | Dobles: llegada, contador, caché, no repetir avisos, error, logout y cambio de cuenta |
| 15–17. Aprobación, cliente denegado y doble aprobación | Dobles del protocolo: vendedor/admin, rol cliente/repartidor, inactivo, estado no pendiente y evento existente; botón productivo bloqueado |
| 18. Seguimiento | Prueba de widget recibe el cambio pendiente→aprobado por un repositorio doble |
| 19. PED001 intacto | Solo lecturas de su versión y subcolecciones; ninguna operación comercial real |
| 20. Farmacias y NIT | Se conserva exactamente la sección publicada y pasan los flujos locales existentes; nueva ejecución de Rules no realizada |

## Requisitos funcionales

| RF | Estado en Firebase real |
|---|---|
| RF-07 Confirmación | Bloqueada; falta contrato de reglas verificable y probado para el alcance aceptado |
| RF-08 Descuento | Bloqueado junto a confirmación; no se escribe stock desde un permiso abierto |
| RF-09 Sobreventa | No hay nuevo escritor habilitado; garantía de transacción comercial nueva aún pendiente |
| RF-10 Recepción | Implementada mediante snapshots, contador y aviso dentro de la aplicación; falta validar en teléfono con cuenta vendedor |
| RF-11 Aprobación | Protocolo atómico preparado y probado con dobles; botón bloqueado por falta de prueba de Rules |
| RF-15 Seguimiento | Lecturas/stream reales implementados; actualización de interfaz probada con doble |
| RF-16 Historial cliente | Consulta real por farmacia propia, con detalles e historial compatibles con PED001; sin mezclar pedidos demo. Verificación móvil con cuenta existente pendiente |

## Archivos y ejecución

Reglas completas: `firestore.rules`. Nuevos: repositorio `staff_order_repository.dart`, lector `firestore_order_reader.dart`, datasource `firestore_staff_order_data_source.dart`, `spark_approval.dart`, `seller_orders_view_model.dart`, `remote_seller_orders_screen.dart`, pruebas `seller_orders_view_model_test.dart`, `spark_approval_test.dart` y `remote_order_tracking_test.dart`, y evidencias JSON de esta carpeta.

Integraciones modificadas: `firestore_order_data_source.dart`, `seller_shell.dart`, `checkout_screen.dart`, `order_tracking_screen.dart`, `order_history_view_model.dart`, `authentication.dart` y la expectativa del mensaje en `cart_view_model_test.dart`.

```powershell
flutter pub get
flutter devices
flutter run -t lib/main.dart -d ID_DEL_TELEFONO
```

No se necesita instalar Node, levantar un emulador ni tener Cloud Functions desplegadas para estas lecturas. El código heredado de Functions se conserva sin ejecutarlo; su inicialización en el datasource ahora es diferida y el modo real rechaza la llamada antes de obtener una instancia. Para validar visualmente, iniciar sesión personalmente como vendedor o cliente existente; no compartir contraseñas y no registrar compras experimentales.

## Alternativa gratuita para el carrito completo

Un backend HTTPS confiable externo puede mantener Firebase en Spark y reutilizar la lógica transaccional existente, sin desplegar Cloud Functions de Firebase. Una opción alojada a evaluar es **Cloudflare Workers Free** con Firestore REST y transacciones explícitas. Su cuota documentada es 100.000 solicitudes diarias y 10 ms de CPU por invocación; el prototipo debe comprobar esas restricciones y las cuotas de Firestore. No se garantiza capacidad ilimitada ni que el código Admin SDK/gRPC existente se ejecute sin adaptación en Workers.

Contrato necesario: Flutter envía ID token de Firebase, ID idempotente, referencias y cantidades. El servidor verifica firma/issuer/audience/expiración del token; vuelve a leer usuario activo y farmacia, dirección, precios y lotes; calcula importes y FEFO/FIFO; aplica pedido, detalles, historial, operación y descuentos en una transacción con precondiciones y reintentos. Debe rechazar cambios de precio, lotes vencidos, duplicados con contenido diferente y cantidades inválidas. Las reglas continúan denegando las escrituras comerciales directas del cliente.

Las credenciales privilegiadas se guardarían únicamente como secretos del servidor, con IAM restringido y rotación; nunca en Dart, assets o Git. El backend debe añadir límites de tamaño, autenticación, protección de abuso y logs sin secretos. La verificación comercial se repite allí porque IAM/REST privilegiado no queda protegido por las reglas del cliente. Otra opción sin coste de hosting es ejecutar un servidor Node confiable en una computadora propia con HTTPS; requiere disponibilidad y administración de esa máquina.

Esta alternativa **no está implementada ni desplegada** por esta tarea. Para habilitar el carrito completo faltan elegir ese backend o aceptar un contrato de compra acotado, implementar su protección, ejecutar pruebas adversariales aisladas y autorizar los cambios de producción. No se solicita Blaze como solución.

## Fuentes oficiales consultadas

- [Condiciones y límites de Rules](https://firebase.google.com/docs/firestore/security/rules-conditions).
- [Transacciones y getAfter](https://firebase.google.com/docs/firestore/manage-data/transactions).
- [Reglas y consultas](https://firebase.google.com/docs/firestore/security/rules-query).
- [Sincronización y pruebas de reglas](https://firebase.google.com/docs/rules/manage-deploy).
- [Cuotas de Firestore](https://firebase.google.com/docs/firestore/quotas).
- [Cloudflare Workers Free y límites](https://developers.cloudflare.com/workers/platform/pricing/).

No se publicaron reglas, índices ni backend. Las operaciones comerciales que requieren verificación adicional siguen bloqueadas en la app.
