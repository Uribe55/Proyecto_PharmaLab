# Confirmación y aprobación Spark implementadas

Fecha: 25/11/2026. Rama: `pedidos-firestore-transaccionales`, sin cambiar de rama. Este documento sustituye el estado de bloqueo descrito en `PEDIDOS_SPARK_SEGURIDAD.md`.

## Qué funciona y qué falta publicar

Se implementó el flujo **confirmación directa → pedido pendiente + descuento → recepción del vendedor → aprobación atómica → seguimiento del cliente** usando Authentication, SDK Flutter de Firestore, transacciones y reglas. No requiere Node, Cloud Functions, Blaze, backend externo ni emuladores para ejecutar la app.

**Las reglas nuevas todavía NO están publicadas.** No hubo autorización para desplegarlas ni realizar compras reales. El código y las reglas locales coinciden y se probaron con datos desechables; la comprobación en Android con las reglas publicadas y cuentas reales queda pendiente. Antes de publicar, Firebase real seguirá rechazando la creación de pedidos. La app no mostrará éxito ante ese rechazo.

## Límite explícito de la primera versión

**Un producto y un lote por pedido, cantidad entera de 1 a 1000 cajas.** Es posible comprar Paracetamol o Guantes, pero no ambos en una misma compra en esta versión. El lote elegido debe cubrir la cantidad completa. El mensaje se muestra antes de confirmar y el botón se desactiva si el carrito tiene varias líneas. El carrito permanece intacto: no se borran productos ni se convierten sus líneas en compras independientes.

No se combinan lotes. Se prefiere el lote vigente más próximo a vencer que cubra la cantidad; si no requiere vencimiento, se ordena por ingreso e ID. La selección entre todos los lotes es una preferencia de la app, no una garantía global FEFO impuesta por Rules. Las reglas sí imponen la relación producto/lote, vencimiento cuando corresponde, cantidad exacta y stock no negativo.

No se multiplica la cantidad por `unidad_por_envase`: comprar dos cajas resta **2** de `cantidad_disponible`, no 40 tabletas ni 200 guantes. No se modifican los productos existentes, sus precios ni sus unidades por envase.

## Contrato de cinco escrituras

La transacción lee sus documentos antes de escribir y relee producto, precio y lote dentro del intento transaccional. La consulta previa de lotes solo selecciona un candidato; no autoriza ni fija sus cantidades. Los reintentos releen el stock actual.

| Documento | Resultado |
|---|---|
| `pedidos/{autoId}` | Esquema `spark_single_v1`, pendiente, fecha del servidor, farmacia/dirección, UID, total autorizado, línea canónica y observaciones |
| `pedidos/{autoId}/detalle_pedido/LINEA1` | Copia exacta de la línea canónica, con producto, lote, cantidad, precio histórico y subtotal |
| `pedidos/{autoId}/historial_estado/CONFIRMACION` | Estado anterior nulo, nuevo pendiente, fecha del servidor y UID del cliente |
| `usuarios/{uid}/operaciones_pedido/{autoId}` | Registro inmutable que vincula ID, farmacia, dirección, línea, observaciones y fecha |
| `lotes_productos/{loteId}` | Resta exacta de cajas y referencia `ultimo_pedido_id`, sin cambiar otros campos |

El ID interno de 20 caracteres se genera una vez y se persiste localmente **antes** de enviar la compra. El número mostrado es `PED-{autoId}`. No se consulta el máximo ID ni se incrementa el contador de farmacias. No se sobrescribe `PED001`.

El registro idempotente permite recuperar un resultado tras timeout o reinicio, incluso si el lote quedó sin stock. Si el mismo ID se reenvía, el protocolo compara el contenido persistido y no aplica otro descuento. Si el contenido no coincide, rechaza el reemplazo. La interfaz bloquea doble pulsación, conserva los errores y solo vacía el carrito tras leer el resultado confirmado desde servidor. Si el carrito cambió durante el envío, conserva su contenido nuevo.

## Seguridad verificada

`firestore.rules` es el archivo completo que debe publicarse. Se mantuvieron el registro transaccional de farmacias, formato `FARM###`, contador y reserva única de NIT.

Las reglas exigen cliente activo, farmacia propia activa, dirección propia activa, producto activo, precio vigente del producto, cantidad positiva entera y lote correspondiente vigente. El total es exactamente precio vigente por cantidad. El detalle debe ser idéntico a la línea del pedido. Se prohíben detalles adicionales, cambios de importes históricos y escrituras de inventario que no correspondan a un nuevo pedido en esa misma operación.

El pedido comprueba el estado posterior del lote, detalle, historial y operación con `getAfter()`. Cada documento secundario comprueba a su vez la creación del pedido. El lote solo puede cambiar cantidad y último pedido, y su delta debe coincidir exactamente con la línea canónica. Así se rechazan pedido sin descuento, descuento sin pedido, historial omitido, dos pedidos compartiendo un descuento y descuentos arbitrarios sobre otros lotes.

El contrato mantiene un conjunto finito de accesos: la creación del pedido consulta perfil, farmacia, dirección, producto, lote anterior/posterior, detalle, historial y operación. Las operaciones válidas completas fueron aceptadas por el motor de reglas bajo sus límites de 10 accesos por operación y 20 por transacción/batch. No se generaliza este contrato a dos productos añadiendo escrituras: hacerlo requeriría rediseñar y probar de nuevo el presupuesto de accesos y las comprobaciones cruzadas.

La aprobación permite únicamente vendedor/administrador activo y transición pendiente→aprobado. `runTransaction` cambia solo estado, UID del aprobador y fecha del servidor, y crea simultáneamente el evento determinista `APROBACION`. No descuenta inventario otra vez. Rechaza usuario cliente, aprobación duplicada, evento aislado, cambio de total y pedido ya aprobado. `SparkApproval.enabled` está habilitado tras verificar el protocolo y sus reglas.

## Pruebas realizadas

- `flutter pub get`: correcto. Se retiraron `cloud_functions` y sus paquetes específicos del lockfile; ningún código Flutter importa ese SDK.
- `flutter analyze`: sin incidencias.
- `flutter test`: **134 pruebas aprobadas**, cero fallos. Incluyen protocolo de confirmación, lectura de precio, cajas, validaciones, reintento idempotente, carrito, seguimiento, recepción y botón de aprobación sin doble pulsación.
- `flutter build apk --debug`: compilación Android correcta. El APK generado se retira con las demás salidas regenerables; `flutter run` lo reconstruye. Gradle mostró una advertencia de migración futura de Kotlin, sin impedir esta compilación.
- **46 pruebas del motor Firestore Rules aprobadas**, cero fallos, con el SDK cliente y datos desechables. Incluyeron transacción válida para cada producto, actores inválidos, farmacia/dirección ajenas, precio falsificado, cantidades inválidas, insuficiencia y vencimiento, las cinco escrituras omitidas por separado, detalle extra/inconsistente, timestamps/actores falsos, cambios de metadatos, delta incorrecto y stock negativo; además idempotencia, concurrencia sin sobreventa, snapshots de vendedor/cliente, aprobación de vendedor y administrador, doble aprobación rechazada, registro de farmacia y NIT único sin regresión.
- El emulador se autorizó únicamente para estas pruebas. Usó el proyecto ficticio `demo-pharmalab-spark-check`, puerto 8085, sin importar respaldos. El script exigía ese host antes de arrancar. No se ejecutaron pruebas comerciales sobre producción.
- `PED001` se conservó en la prueba histórica con estado aprobado, total 385 y dos detalles. No hubo escrituras sobre el documento real ni sobre los lotes reales.
- Evidencia compacta: `SPARK_CONFIRMACION_PRUEBAS.json`, con nombres de casos, resultados y SHA-256 de las reglas exactas probadas. El motor de reglas de producción aún no ha sido comprobado con la nueva release, porque no se publicó.

Los archivos temporales del emulador y las dependencias Node instaladas para probar se retiran al terminar, como pidió el usuario. No se borran los respaldos locales anteriores. Permanecen las pruebas unitarias de Flutter y la evidencia pequeña; no son requisitos operativos adicionales para Android.

## Archivos de implementación

Nuevos:

- `lib/domain/spark_checkout.dart`: contrato, validaciones y cinco escrituras del protocolo transaccional.
- `lib/data/datasources/firestore_spark_checkout.dart`: selección de lote, `runTransaction` y adaptador de Firestore.
- `test/spark_checkout_test.dart`: pruebas del protocolo y reintentos.
- `test/spark_seller_approval_widget_test.dart`: procesamiento, botón desactivado y éxito tras commit.

Modificados:

- `firestore.rules`: contrato acotado y permisos estrictos, sin alterar el alta de farmacias/NIT.
- `lib/data/datasources/firestore_order_data_source.dart`: confirmación y recuperación directas de Firestore; sin callable.
- `lib/viewmodels/checkout_view_model.dart` y `lib/screens/cliente_farmacia/checkout_screen.dart`: límite visible, validación y conservación del carrito.
- `lib/domain/spark_approval.dart`, `lib/data/datasources/firestore_staff_order_data_source.dart` y `lib/screens/vendedor/remote_seller_orders_screen.dart`: aprobación habilitada, comprobación de sesión y UX de procesamiento.
- `lib/data/mappers/firestore_order_mapper.dart`: lectura del lote canónico manteniendo los formatos anteriores.
- `lib/services/firebase_environment.dart`, `lib/main.dart`, `pubspec.yaml` y `pubspec.lock`: selección de entorno conservada, banner actualizado y retirada del SDK Cloud Functions.
- Pruebas existentes de mensajes, aprobación habilitada y fixture histórico de total 385.

Se reutilizan `SellerOrdersViewModel`, `snapshots()`, historial y seguimiento existentes. No se usa la lista local como fuente en Firebase real. El modo demo conserva sus flujos y pasó sus pruebas. El código backend heredado versionado no se borró, pero no es llamado ni requerido por la nueva app.

## Publicación de reglas: paso pendiente

No se ejecutaron estos comandos de despliegue. Cuando el propietario decida publicar, desde la raíz del proyecto:

```powershell
firebase.cmd login
firebase.cmd deploy --only firestore:rules --project proyecto-pharmalab --config firebase.json
```

Ese comando publica únicamente `firestore.rules` en el proyecto indicado; no despliega Functions ni índices. No usar el archivo de configuración de emuladores para producción. Como alternativa, copiar el contenido **completo** de `firestore.rules` al editor de reglas de Firestore `(default)` en Firebase Console y pulsar Publicar. Esperar la propagación antes de probar. Verificar que no se sobrescriban cambios posteriores hechos por otra persona en Console.

## Demostración en Android con Firebase real

```powershell
flutter pub get
flutter devices
flutter run -t lib/main.dart -d ID_DEL_TELEFONO
```

No iniciar emuladores, no usar `adb reverse` y no ejecutar `main_emulator.dart` para esta demostración. No se necesita instalar las dependencias de `functions/`.

Una vez publicadas las reglas, el propietario puede realizar la demostración real:

1. Iniciar sesión personalmente como cliente existente. Comprobar su farmacia, catálogo y dirección activa; `DIR001` solo es válida para su farmacia propietaria.
2. Dejar **un solo producto** en el carrito y una cantidad que cubra un lote vigente. Si se seleccionaron dos productos, retirar uno explícitamente en el carrito; la aplicación no lo hará por el usuario.
3. Confirmar. La operación creará un pedido real y descontará cajas del lote real. Esperar el éxito y anotar el número `PED-{autoId}`. Si hay error de reglas, el carrito se conserva y no se presenta una confirmación falsa.
4. Revisar en Console pedido, `detalle_pedido/LINEA1`, `historial_estado/CONFIRMACION`, registro idempotente y cantidad del lote. No editar sus valores manualmente ni restablecer el stock.
5. Abrir la cuenta vendedor en otra sesión/dispositivo, preferiblemente antes de confirmar para observar el aviso. Si se entra después, el pedido aparece pero no se notifican de nuevo todos los pedidos históricos.
6. Abrir el pendiente y pulsar **Aprobar pedido**. Esperar el éxito. Verificar `estado: aprobado`, `aprobado_por`, `fecha_aprobacion` y `historial_estado/APROBACION`. El stock debe permanecer igual que después de confirmar.
7. Mantener el seguimiento del cliente abierto en otro dispositivo/sesión para observar el cambio automático. Con un solo teléfono, cambiar de cuenta permite revisar el estado persistido, pero no demuestra dos sesiones simultáneas.

No se efectuó esa compra de demostración por el agente. No se cambió de base de datos, no hubo migraciones ni se activó facturación. No se hicieron commits, merges ni push.
