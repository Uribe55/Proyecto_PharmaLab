# Etapa 6 — Logística con Firestore Spark

Implementación local preparada para revisión y despliegue manual. No se publicaron reglas ni se escribieron datos de producción. Se conserva la rama `pedidos-firestore-transaccionales`; no se hizo commit, merge ni push.

## Flujo implementado

1. El cliente confirma usando el flujo Spark existente y el vendedor aprueba con su transacción existente.
2. Vendedor → Pedidos → Todos → pedido aprobado → **ASIGNAR REPARTIDOR**. La lista consulta empleados con cargo `Repartidor` y `estado: true`. La confirmación valida además en reglas que `usuarios/{usuario_id}` sea un repartidor activo.
3. La transacción crea `entregas/{autoId}`, `detalle_entrega/DENT001` y la referencia `pedidos/{id}.id_entrega`. El pedido continúa aprobado. No modifica inventario, precios ni total.
4. Repartidor → Mis entregas escucha exclusivamente `id_repartidor == EMP###`. Resuelve EMP### desde `empleado.usuario_id == UID`, exige exactamente un empleado activo y muestra contacto, dirección, referencia, producto y cantidad sin precios.
5. **INICIAR REPARTO** cambia entrega y pedido a `en_ruta` y crea `historial_estado/LOG_en_ruta` en una transacción.
6. **MARCAR COMO ENTREGADO** cambia ambos a `entregado`, crea `LOG_entregado` y actualiza la cantidad entregada de DENT001 al total programado, atómicamente.
7. **REGISTRAR ENTREGA FALLIDA** guarda motivo y observación, cambia ambos a `fallida` y crea `LOG_fallida`. No cancela ni restituye inventario. Se muestra en Historial y en las entregas del vendedor.
8. El seguimiento del cliente reutiliza sus listeners de pedido, detalles e historial; recibe automáticamente los nuevos estados, fechas y observaciones. El dashboard administrativo existente integra entregas por `id_pedido` y repartidor por `id_repartidor`.

## Alcance y compatibilidad

- Escrituras logísticas habilitadas para pedidos `spark_single_v2`, aprobados, de una línea con `DET001`, sin `id_entrega` previo. Es el contrato de compra que ya utiliza Firebase real.
- Este alcance permite verificar todos los documentos obligatorios dentro de los límites de acceso de Security Rules. No se habilitan operaciones genéricas sobre pedidos históricos de varias líneas.
- IDs internos automáticos; etiqueta comercial determinista `ENT-PED002`, `ENT-PED003`, etc. La referencia única del pedido y su número comercial ya protegido evitan colisiones de asignación. No se introduce un contador de entregas que requiera inicializar producción.
- `ENT001` y sus detalles conservan lectura autorizada y permanecen sin nuevas escrituras. La vista muestra sus cantidades históricas; indica cuando faltan snapshots de dirección o contacto. No se permite al repartidor consultar documentos comerciales para completar esos datos.
- `PED001` no se migra ni se modifica. Tampoco se reescriben compras existentes.
- Las entregas nuevas incluyen una copia mínima de contacto, dirección y producto, cotejada con los documentos originales por las reglas; no contienen precios ni ingresos.
- `fecha_creacion` registra asignación; `fecha_estado` registra el último evento logístico, incluida entrega o fallo; `fecha_logistica` y el historial guardan las fechas del pedido. Son timestamps del servidor.
- No hay entrega parcial, reasignación, reprogramación, segundo intento, devolución automática ni cancelación remota. Una entrega fallida conserva la referencia para una futura coordinación explícita.
- El modo demostración conserva sus pantallas, PharmaService y cola SyncService locales. En Firebase real no se utiliza esa cola: las transacciones necesitan conexión y una confirmación del servidor.
- El contador de la barra inferior del repartidor no presenta datos demo en Firebase real. No se agregaron métricas simuladas.

## Archivos

Nuevos:

- `lib/data/repositories/logistics_repository.dart`: contrato y registros logísticos sin precios.
- `lib/data/datasources/firestore_logistics_data_source.dart`: consultas remotas y transacciones.
- `lib/viewmodels/logistics_view_model.dart`: bloqueo de doble pulsación, estado ocupado y errores.
- `lib/screens/shared/remote_logistics_screen.dart`: asignación, entregas, historial y acciones remotas.
- `test/logistics_view_model_test.dart`: concurrencia, rechazo remoto y cierre durante escritura.
- `functions/test/logistics.rules.cjs`: pruebas de seguridad aisladas.
- `firebase.logistics-test.json`: únicamente Firestore local, puerto 8085; no configura la app.
- Este documento.

Modificados:

- `firestore.rules`: asignación y transiciones atómicas, historial y cantidades obligatorias, campos restringidos, repartidor activo y asignado. Las reglas de registro/NIT, confirmación y aprobación se conservan.
- `lib/models/order.dart`: referencia logística `deliveryId` separada del ID del empleado.
- `lib/data/mappers/firestore_order_mapper.dart`: referencia y fechas logísticas, compatibilidad de estado fallido.
- `lib/screens/vendedor/seller_shell.dart`: pestaña de entregas remotas.
- `lib/screens/vendedor/remote_seller_orders_screen.dart`: acceso de asignación desde pedido aprobado.
- `lib/screens/repartidor/driver_shell.dart`: entregas e historial remotos cuando usa Firebase.
- `lib/services/dashboard_repository.dart`: nombres de referencias reales y normalización de asignada/fallida.

## Seguridad

La asignación valida vendedor/administrador activo, pedido actual aprobado sin entrega previa, empleado repartidor y cuenta activa. Exige entrega, detalle y vínculo del pedido en la misma operación. La copia de contacto no se puede falsificar.

Las transiciones solo corresponden al repartidor activo del empleado asignado. Las reglas cotejan estados previos, vínculo con pedido, cambios exclusivos de campos logísticos, timestamp de servidor e historial exacto. La entrega final exige cantidades completas. No existen permisos nuevos de escritura sobre inventario ni detalles comerciales.

El repartidor opera sobre la entrega sin leer el pedido comercial. Las reglas consultan ese pedido internamente con `get/getAfter`; esas consultas no conceden lectura al cliente Flutter. Las pruebas verifican que el repartidor no pueda leer el pedido nuevo ni entregas ajenas.

## Índices

Las consultas nuevas no combinan filtro con ordenación:

- `empleado`: igualdad por `usuario_id`.
- `empleado`: igualdades por `cargo` y `estado`, resueltas por combinación de índices de campo único.
- `entregas`: igualdad por `id_repartidor`.
- Personal: todas las entregas, sin ordenación de servidor.

No necesitan nuevos índices compuestos con los índices automáticos de campo único habilitados. Se conserva el índice existente de pedidos por cliente/fecha. No se modificó la configuración productiva de índices.

## Despliegue manual

Revisar el diff y los resultados antes de publicar. Este comando queda preparado; **no fue ejecutado**:

```powershell
firebase.cmd deploy --only firestore:rules --project proyecto-pharmalab
```

Publica únicamente `firestore.rules` mediante `firebase.json`. No despliega Functions, no cambia el plan Spark y no migra documentos. La nueva versión Flutter requiere esas reglas; con las reglas anteriores las escrituras serán denegadas y la interfaz mostrará el error.

Ejecutar normalmente con `flutter run` y `lib/main.dart`, que inicializa el proyecto Firebase real. No iniciar emuladores para usar la aplicación real. El modo de demostración conserva `flutter run -t lib/main_demo.dart`.

## Prueba manual con tres cuentas

1. Comprobar en consola que las cuentas cliente y vendedor tengan `usuarios/{uid}` activos con sus roles correctos. Para el repartidor comprobar además `empleado/EMP###` con cargo `Repartidor`, estado true y su UID en `usuario_id`. No cambiar IDs para igualarlos al UID.
2. Con las reglas publicadas manualmente y tres sesiones independientes, cliente confirma un pedido nuevo. Este paso comercial descuenta inventario según el contrato existente; hacerlo solo con un pedido de demostración autorizado. Las pruebas automatizadas nunca usan producción.
3. Vendedor encuentra el pedido pendiente y lo aprueba. En Todos abre su detalle, selecciona ASIGNAR REPARTIDOR, elige el empleado activo y confirma. Comprobar que el pedido permanece aprobado y solo existe una entrega vinculada.
4. Repartidor ve la nueva entrega sin reiniciar. Verificar contacto, teléfono, dirección, referencia y producto/cantidad; no aparecen importes.
5. Repartidor inicia reparto. Mantener abierto el seguimiento del cliente: debe mostrar En ruta con su evento y fecha.
6. Marcar entregado. Cliente debe ver Entregado; vendedor y administrador deben ver el resultado. DENT001 debe tener cantidad_entregada igual a cantidad_programada.
7. Con otro pedido nuevo repetir hasta En ruta y registrar fallo con motivo/observación. Verificar Fallida en las tres sesiones y el historial. No debe aparecer cancelado ni restituirse stock.
8. Comparar total y stock antes/después de asignar, despachar y cerrar: permanecen iguales. No utilizar PED001 ni ENT001 para estos pasos.

## Pruebas automatizadas

```powershell
flutter pub get
flutter analyze
flutter test
npm.cmd --prefix functions ci --ignore-scripts --no-audit --no-fund
firebase.cmd emulators:exec --only firestore --project demo-pharmalab-logistics --config firebase.logistics-test.json "cd functions && node --test --test-concurrency=1 test/logistics.rules.cjs test/spark_checkout.rules.cjs"
```

El emulador es exclusivamente una herramienta de pruebas. Los scripts exigen host loopback y proyectos `demo-*`, siembran datos ficticios y no usan credenciales administrativas productivas. No se ejecutan Cloud Functions ni Admin SDK en Flutter.

Resultados de la verificación del 26/11/2026:

| Comprobación | Resultado |
| --- | --- |
| `flutter pub get` | Correcto |
| `flutter analyze` | Sin incidencias |
| `flutter test` | 153 pruebas aprobadas |
| Reglas de logística | 19 pruebas aprobadas |
| Reglas Spark existentes | 50 pruebas aprobadas |
| Total de reglas | 69 aprobadas, 0 fallos |
| `git diff --check` | Correcto |

Las regresiones incluyen aprobación con snapshots, stock sin segundo descuento, pedido histórico de varias líneas y registro transaccional de farmacia/NIT único. La nueva suite comprueba roles, empleados/cuentas inactivos, pedido pendiente, duplicados, privacidad del repartidor, ruta/entrega/fallo, motivo/observación, historial y cantidades obligatorias, total/stock e inmutabilidad de ENT001.

No se ejecutó el antiguo `functions/test/orders.test.js`: prueba el backend histórico de Cloud Functions con emuladores Auth/Functions, que no participa en este flujo Spark. Se ejecutó la suite existente específica de Spark y las nuevas reglas logísticas.

La ejecución real con cuentas productivas queda pendiente del despliegue manual y la autorización para usar un pedido de demostración. El log local de reglas es `logistics-rules-test.log` (ignorado por Git); el emulador se detuvo automáticamente al terminar.
