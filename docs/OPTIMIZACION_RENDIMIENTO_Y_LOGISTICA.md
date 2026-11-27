# Inicio de reparto y rendimiento transaccional

Fecha: 27/11/2026. Proyecto operacional indicado por el usuario: `proyecto-pharmalab`. API operacional indicada: **https://pharmlab-api.onrender.com** (sin la segunda «a» de PharmaLab). No se consultaron ni modificaron documentos operacionales, no se desplegó Render, no se publicaron reglas y no se hicieron commits/push.

## Causa y corrección del botón

`driver_shell.dart` selecciona `RemoteLogisticsScreen` y su variante de historial cuando `service.usesFirebase` es verdadero. Las pantallas de demostración `driver_deliveries_screen.dart` y `driver_delivery_detail_screen.dart` no eran el lugar adecuado para corregir este fallo.

El defecto verificable estaba en `FirestoreLogisticsDataSource.watchDeliveries()`: usaba `query.snapshots()` y trasladaba `metadata.isFromCache` al registro. La vista remota excluía las acciones cuando ese valor era verdadero. Sin escuchar cambios de metadatos, una entrega cuyo contenido no cambia al llegar la confirmación del servidor puede quedarse representada como cacheada. Esto explica un mecanismo concreto de desaparición del botón; no se inspeccionó una entrega operacional para afirmar que fuera la única causa en el dispositivo.

La suscripción ahora utiliza `snapshots(includeMetadataChanges: true)`. Tanto caché como escrituras locales pendientes mantienen deshabilitadas las acciones. Los botones permanecen visibles y se explica que se está esperando sincronización; no se retiran las restricciones de datos desactualizados. Las lecturas de detalles históricos se conservan.

Para una entrega asignada compatible (`spark_logistics_v1` o `transactional_logistics_v1`), el repartidor ve **Iniciar reparto**, con icono de transporte. Se pide confirmación, se bloquean las acciones durante la operación y se muestra un indicador indeterminado. El repositorio existente envía `state: en_ruta` a `POST /api/deliveries/:id/transition` para el contrato múltiple. No hay nueva operación logística ni descuento de inventario.

El filtro existente comprueba la relación entre UID y empleado activo único y consulta `entregas.id_repartidor` con ese ID EMP. También filtra `repartidor_uid` cuando está presente. El backend vuelve a comprobar perfil, empleado activo, cargo, UID e ID del repartidor asignado dentro de la transacción. Las pruebas rechazan al cliente y a otro repartidor.

Antes del inicio: pedido `aprobado`, entrega `asignada`. Después: ambos `en_ruta`, con fecha de despacho, fecha logística e historial. La repetición de la misma solicitud es idempotente, no crea otro inicio. Completar antes de iniciar se rechaza. En ruta aparecen **Confirmar entrega** y **Registrar entrega fallida**. Entregadas/fallidas quedan sin acciones de reinicio; las entregadas aparecen en historial y conservan su detalle. Las suscripciones existentes de cliente, vendedor y administrador reciben las modificaciones de los documentos; no se modificó su arquitectura ni se requiere reabrir la app. La comprobación final en los cuatro teléfonos/cuentas operacionales queda para después del despliegue manual.

## Diagnóstico de la confirmación

Se encontraron tres costes concretos:

1. `http_app.js` leía el usuario y `clientContext()` volvía a leerlo dentro de la transacción.
2. Dirección, contador, pedido existente y productos se leían secuencialmente. Las consultas de lotes estaban dentro del bucle de líneas.
3. Tras una respuesta HTTP exitosa, Flutter volvía a cargar el pedido y sus subcolecciones antes de presentar la confirmación.

Los aproximadamente 20 segundos son una observación del dispositivo comunicada por el usuario. No se midió Render operacional ni se atribuye toda esa demora al código: también intervienen Ohio–São Paulo, autenticación, red móvil, carga y posible reactivación del servicio gratuito.

## Optimizaciones aplicadas

- Usuario y operación idempotente se leen con `tx.getAll()`. Tras validar usuario y farmacia se conserva la salida temprana para operaciones existentes, sin consultar inventario.
- Dirección, contador, existencia del pedido y productos únicos se agrupan en otra lectura. Las referencias ya son conocidas; la propiedad de la dirección se valida con la farmacia obtenida.
- Las categorías únicas se agrupan. Los lotes de cada producto se consultan una sola vez con concurrencia máxima **cuatro**; la consulta de categorías puede coexistir con esas consultas. Todos los reads siguen dentro de la misma transacción y antes de escribir.
- Los mapas de productos, categorías y lotes se reutilizan entre presentaciones. La lista FEFO se calcula una vez por producto; la asignación sigue un orden determinista y comparte el mapa de existencias restantes.
- Se eliminó la lectura del usuario del transporte HTTP. Todas las rutas comerciales siguen validando usuario, estado y permisos dentro de sus transacciones. La verificación de revocación del token en producción continúa activa; no se añadió caché de autorizaciones.
- La cancelación obtiene todos los lotes históricos mediante `tx.getAll()` y valida producto, cantidades y trazabilidad antes de restituir. Conserva la restitución exacta y única. Aprobación, asignación y transiciones conservan su contrato; también dejan de pagar la lectura redundante del transporte.
- Para una compra nueva, la API devuelve, además de los IDs estables en `data`, el snapshot del pedido confirmado en `order`. Se construye durante la transacción y solo se envía cuando `runTransaction()` termina correctamente. No se almacena otra copia en la operación idempotente ni se cambia el esquema de Firestore.
- Flutter verifica propietario, farmacia y operación y transforma ese snapshot sin otra carga bloqueante de Firestore. Los reintentos ya confirmados y servidores anteriores conservan la carga normal como compatibilidad. Esta compatibilidad es de lectura: no cambia de ruta de escritura después de un error.

Se conservan las colecciones, FEFO y vencimientos, precios históricos, presentaciones comerciales, inventario base compartido, contador, movimientos, atomicidad, protección contra sobreventa e idempotencia. No se fracciona el pedido ni se mueve ninguna lectura crítica fuera de la transacción. El carrito sigue guardado hasta confirmación definitiva; los timeouts conservan ID y contenido pendientes.

## Instrumentación disponible

`functions/src/performance.js` usa `performance.now()`. El evento JSON `order_confirmation_metrics` contiene tiempos de autenticación, recepción/decodificación del cuerpo, usuario+operación, farmacia, documentos agrupados, categorías, lotes, presentaciones, FEFO, asignación y preparación de escrituras. Incluye productos, lotes leídos/utilizados, intentos, lecturas y llamadas de lectura al SDK, escrituras preparadas, duración total de la transacción y respuesta.

`commitAndRetryTailMs` mide el tramo desde la última preparación de escrituras hasta la resolución del SDK, no una medición exclusiva del RPC de commit. Los intentos permiten distinguir reintentos transaccionales. Los tiempos de consultas paralelas se solapan: no deben sumarse como duración total. Los documentos agrupados comparten una duración; no se inventan tiempos separados para cada documento. Las lecturas incluyen intentos completados y consultas vacías como una lectura mínima lógica; no son una factura exacta de Firestore ni cuentan reintentos internos de transporte del SDK.

La respuesta incluye `Server-Timing: processing;dur=...`. Flutter registra JSON `order_http_metrics` con tiempo de token, HTTP y procesamiento comunicado por el servidor. `networkQueueAndWakeEstimateMs` es HTTP menos procesamiento: mezcla red, TLS, proxy, cola y posible reactivación; **no identifica por sí solo un arranque en frío**. El evento de arranque `server_started` y `processUptimeSeconds` ayudan a interpretarlo.

También se registra `order_confirmation_local_metrics.postRepositoryMs` para la actualización local y `firstFrameAfterConfirmationMs` para el primer frame después de navegar a la confirmación. Son tramos distintos, no una medición precisa de toda la red hasta el píxel final.

No se registran tokens, IDs de usuario/pedido, contenido del carrito, nombres, direcciones, teléfonos ni secretos. Se mantiene el indicador de espera sin porcentajes ni etapas ficticias. No se añadieron pings, cron ni servicios para impedir la suspensión. No se añadió una llamada preventiva a `/health`: no es necesaria para la integridad y una llamada extra tampoco garantiza que el servidor permanezca activo.

## Comparación ejecutada antes/después

Entorno: **Firebase Emulator Suite local, Node.js 22.23.5**, tres muestras por versión/escenario; se presenta la mediana. Baseline: commit `48c9ea37ec2c8600d673ac05cf021694a6e79e71`. Datos completos y hash del código anterior: [RENDIMIENTO_EMULADOR.json](RENDIMIENTO_EMULADOR.json).

| Escenario | Backend antes → después | Lecturas de documentos antes/después | Llamadas de lectura al SDK antes → después | Escrituras antes/después | Intentos |
| --- | --- | --- | --- | --- | --- |
| 1 producto, 1 lote utilizado | 151,62 → 78,76 ms | 9 / 9 | 9 → 5 | 7 / 7 | 1 / 1 |
| 3 productos, 4 lotes utilizados | 198,06 → 84,22 ms | 16 / 16 | 13 → 7 | 15 / 15 | 1 / 1 |
| 5 productos, 10 lotes utilizados | 234,38 → 100,30 ms | 22 / 22 | 17 → 9 | 29 / 29 | 1 / 1 |
| 20 productos, 100 lotes utilizados | 622,65 → 186,01 ms | 127 / 127 | 47 → 24 | 224 / 224 | 1 / 1 |

Estas cifras corresponden a la transacción del backend, excluyen HTTP, Authentication, dispositivo y Render. La lectura redundante eliminada del middleware supone **una lectura adicional menos por petición HTTP**, fuera de esa tabla. Los documentos críticos no se dejaron de comprobar. Las llamadas agrupadas y paralelas reducen las esperas: los cuatro escenarios pasan aproximadamente de 9/13/17/47 etapas seriales a 4/4/5/8 grupos dependientes de lectura, sin contar commit, variación de planificación o reintentos internos del SDK.

No se afirma que producción ya tarde esos milisegundos, ni que se hayan alcanzado los objetivos orientativos de 1–6 segundos. Para medirlo después del despliegue, realizar compras manuales autorizadas equivalentes con el servicio activo y, por separado, después de suspensión. Comparar logs del teléfono con `order_confirmation_metrics`; registrar intentos y tamaños. No hacer compras automatizadas contra la base operacional. La latencia entre regiones y Render Free siguen siendo limitaciones.

## Pruebas y reproducción

- Backend completo: **51 pruebas aprobadas** con Node.js 22.23.5, incluidas las 10 HTTP, concurrencia, precios, FEFO, presentaciones, cancelación, restitución, idempotencia, ausencia de escrituras parciales y recuperación de respuesta perdida.
- HTTP final tras completar los registros de recepción/arranque: **10 aprobadas**. Incluye snapshot de confirmación, `Server-Timing`, repartidor ajeno, rechazo de completar sin iniciar e inicio repetido sin segundo descuento.
- Reglas Spark, logística y empleados: **103 aprobadas** con Node.js 22.23.5. HTTP también carga y prueba `firestore.render.rules`.
- `flutter test`: **196 aprobadas**, incluidas cuatro pruebas nuevas de la pantalla remota: caché→servidor, bloqueo durante inicio, compatibilidad Spark, entrega completada/fallida e historial.
- `flutter analyze`: sin incidencias en la verificación final. Tras los últimos registros de diagnóstico también pasaron las 15 pruebas dirigidas de checkout y acciones remotas; están incluidas en el alcance de las 196 pruebas, no se suman como casos diferentes.
- No se cambió Gradle, reglas, credenciales, región ni plan. La orquestación local y los workers de los callables heredados pueden usar el Node 26 del host; los tests del núcleo/API y el benchmark se ejecutaron expresamente bajo Node 22.23.5, incluido el arranque HTTP mediante npm.

Desde `functions`, ejecutar suites de emuladores secuencialmente:

```powershell
firebase.cmd emulators:exec --project demo-pharmalab --config ../firebase.emulator.json --only auth,firestore,functions "npm.cmd exec --yes --package=node@22 -- node --test --test-concurrency=1 test/*.test.js"
firebase.cmd emulators:exec --project demo-pharmalab --config ../firebase.emulator.json --only firestore "npm.cmd exec --yes --package=node@22 -- node test/performance.bench.cjs"
firebase.cmd emulators:exec --project demo-pharmalab-security --config ../firebase.logistics-test.json --only firestore "npm.cmd exec --yes --package=node@22 -- node --test --test-concurrency=1 test/spark_checkout.rules.cjs test/logistics.rules.cjs test/employees.rules.cjs"
```

Con Node 22 ya seleccionado localmente puede omitirse `npm exec --package=node@22`. El benchmark recupera el baseline con `git show`; requiere un clon con ese commit, no una descarga ZIP. No usa datos ni credenciales reales. El reporte puede sobrescribirse al repetirlo: comparar sus muestras, no exigir tiempos idénticos entre equipos.

## Archivos y actualización manual

Backend: `functions/src/orders.js`, `order_actions.js`, `http_app.js`, `server.js`, nuevo `performance.js`, script de benchmark en `functions/package.json`, pruebas `functions/test/http.test.js` y nuevo `performance.bench.cjs`.

Flutter: `firestore_logistics_data_source.dart`, `firestore_order_data_source.dart`, `order_gateway.dart`, `remote_logistics_screen.dart`, `checkout_screen.dart`, `checkout_view_model.dart` y nuevo `test/remote_driver_actions_test.dart`. Documentación: este archivo y `RENDIMIENTO_EMULADOR.json`.

**Sí: hay que volver a desplegar Render** para aplicar las optimizaciones y métricas. Revisar/subir esos cambios a GitHub manualmente y ejecutar **Manual Deploy → Deploy latest commit** en el servicio existente. Mantener `functions`, `npm ci`, `npm start`, Node 22 y las variables/Secret Files actuales. No se proporcionan comandos de commit/push automáticos ni se generan credenciales.

**No: no hay que volver a publicar reglas.** `firestore.rules` y `firestore.render.rules` no se modificaron. Desplegar primero el backend y después actualizar la app; la respuesta HTTP ampliada es compatible con la versión anterior de Flutter, y la nueva app conserva la lectura tradicional si el servidor todavía no devuelve el snapshot.

Desde la raíz del proyecto:

```powershell
flutter analyze
flutter test
flutter run --dart-define=PHARMALAB_API_URL=https://pharmlab-api.onrender.com
flutter build apk --release --dart-define=PHARMALAB_API_URL=https://pharmlab-api.onrender.com
```

Instalar `build/app/outputs/flutter-apk/app-release.apk` como actualización, conservando datos locales para no perder operaciones pendientes. No usar flags de emulador en esa APK. No se compiló ni ejecutó una nueva APK contra producción en esta intervención; la prueba final de dispositivo, disponibilidad remota y tiempos operacionales queda pendiente del despliegue del usuario.

Fuentes: [Firebase: eventos de metadatos](https://firebase.google.com/docs/firestore/query-data/listen#events_for_metadata_changes). La compatibilidad de `Transaction.getAll()` se verificó también en el SDK instalado, `@google-cloud/firestore/build/src/transaction.js`; las pruebas Node 22 la ejercitan sobre transacciones reales del emulador.
