# Permission-denied al confirmar: causa y solución

Revisión del 25/11/2026, rama `pedidos-firestore-transaccionales`, sin cambiar de rama, hacer commit ni push.

## Causa comprobada

**Las reglas Spark locales NO están publicadas en `proyecto-pharmalab`.** Se consultó la release real por Firebase Rules API, sin desplegar ni modificar documentos.

| Versión | Resultado |
|---|---|
| Publicada | Ruleset `33f8ba18-0155-4332-bbee-bad53090d818`, actualización `2026-11-25T14:43:56.837810Z` |
| SHA-256 publicada | `B8C7697A45DB6C384FAF240BAD15A023CCB073F856F4A0752C54BDB72965E552` |
| SHA-256 local | `E4527C1B23FF60E31C31F44E4EE2B65B658D708C1DC312F01B61E6DBD7DD3DF0` |

La copia exacta de las reglas publicadas está en `functions/test/fixtures/firestore.before-spark.rules`. En esa versión:

- Línea 362: `allow get, list: if readsOrder(resource.data);`. Un cliente no puede leer un pedido que todavía no existe, porque no hay un `id_cliente` que permita comprobar su propiedad.
- Línea 367: `allow create: if false;`. Aunque se omitiera la lectura, la creación seguiría denegada.
- Las creaciones de detalles y operaciones idempotentes, el historial inicial y las actualizaciones de lotes tampoco tienen los permisos Spark nuevos.

El primer rechazo **reproducido** ocurre en `SparkCheckout.prepare`, al leer `pedidos/{autoId}` dentro de la transacción, después de leer el registro idempotente. No llega a encolar sus cinco escrituras. La excepción nativa es `permission-denied`; `FirestoreSparkCheckout` la convertía en el mensaje genérico observado en el teléfono.

La regresión ejecuta la compra con las reglas publicadas exactas y comprueba ese punto de fallo; después carga las reglas locales y confirma la misma compra anonimizada de FARM004 correctamente. **No fue necesario cambiar las reglas locales ni el contrato comercial.** `firebase.json` ya apunta a `firestore.rules`.

## Datos reales consultados, sin escrituras

La búsqueda por el nombre indicado identificó **FARM004**, no FARM001. Se leyó su `usuario_id` y el documento `usuarios/{uid asociado}`:

- El perfil existe, `rol: cliente`, `estado: true`.
- La farmacia está activa y vinculada a ese UID.
- La dirección que coincide con la indicada por el usuario es `direcciones/KKp8HDRwSfgBBiGAaVpr`, pertenece a FARM004 y está activa.
- `productos/PROD001` está activo; `precio` es **doubleValue 150**.
- `lotes_productos/LOTE001` pertenece a PROD001; `cantidad_disponible` es **integerValue 100** y `fecha_vencimiento` es **timestampValue 2027-06-30T04:00:00Z**, futura al revisar.

No se cambiaron esos valores ni se restableció el stock. La consulta se hizo por IAM/REST con una sesión local existente: **no demuestra que el UID activo en la memoria de la app sea el mismo**. El teléfono estaba conectado, pero no se encontró el proceso de PharmaLab para extraer un log del intento original. No se reprodujo una compra contra producción ni se afirma haber capturado su transacción real. El diagnóstico opt-in permite contrastar ese UID y las rutas en un nuevo intento del propietario.

Los datos personales obtenidos para preparar la reproducción solo estuvieron en un archivo ignorado temporal, que se retira al finalizar. El fixture conservado anonimiza nombres, teléfono, NIT, dirección, correo y UID, manteniendo las relaciones, campos presentes y tipos. Los tipos numéricos y timestamps de los datos comerciales se conservan mediante REST tipado en el emulador.

## Cambios pequeños realizados

- `checkout_diagnostics.dart`: diagnóstico de desarrollo, desactivado por defecto y en release. Registra proyecto, UID, farmacia, operación, etapa, ruta cuando se conoce, intento, existencia conocida del pedido y código/plugin/mensaje de `FirebaseException`. Redacta patrones de credenciales. No acepta ni imprime el payload, notas, correo, contraseña o tokens.
- `firestore_spark_checkout.dart`: marca consultas, lecturas transaccionales, escrituras encoladas y commit; registra también errores de consulta anteriores a la transacción. Un rechazo del commit se identifica como tal y no se atribuye falsamente a la última escritura del lote.
- `firestore_order_data_source.dart`: diagnóstico de la consulta idempotente y separación de la carga de documentos relacionados.
- `checkout_diagnostics_test.dart`: pruebas de activación, etapa/ruta/intento, existencia desconocida frente a confirmada y redacción de secretos.
- `functions/test/spark_checkout.rules.cjs` y dos fixtures pequeños: regresión y pruebas de seguridad reproducibles. `functions/package.json` añade el comando `test:spark-rules`.

El protocolo de cinco escrituras, las condiciones de stock, el historial, la aprobación y el registro de farmacias/NIT permanecen intactos. `firestore.rules` no cambió en esta tarea. La interfaz conserva mensajes comprensibles; los detalles técnicos solo aparecen al activar el diagnóstico.

## Verificación ejecutada

- `flutter pub get`: correcto.
- `flutter analyze`: sin incidencias.
- `flutter test`: **138 pruebas aprobadas** (134 anteriores y cuatro de diagnóstico), sin fallos.
- **25 pruebas Firestore Rules aprobadas**, sin fallos, en `demo-pharmalab-spark-regression`, puerto local 8085, sin importar respaldos.
- Incluyen reglas publicadas frente a locales, lectura de documento inexistente, los cinco documentos atómicos, dobles nativos y `REQUEST_TIME`, precio manipulado, farmacia/dirección ajenas, cantidades no válidas, stock insuficiente/negativo, lote vencido, cliente inactivo, doble confirmación, concurrencia sin sobreventa, snapshots de vendedor/cliente, aprobación con historial, bloqueo de cambios de total y registro/NIT sin regresión.
- El fixture de PED001 permanece aprobado con total 385 y dos detalles. No se escribió el documento real ni se hicieron compras experimentales en producción.

No se ejecutó la suite Node heredada de Cloud Functions, que pertenece al backend anterior. La seguridad del flujo Spark se comprueba con el nuevo comando independiente, sin Functions.

Para repetir las pruebas de reglas en desarrollo, después de reinstalar sus dependencias:

```powershell
npm.cmd --prefix functions ci
firebase.cmd emulators:exec --config firebase.emulator.json --project demo-pharmalab-spark-regression --only firestore "npm.cmd --prefix functions run test:spark-rules"
```

El script rechaza hosts que no sean `127.0.0.1:8080` o `127.0.0.1:8085` y utiliza un proyecto demo fijo. Limpia exclusivamente sus datos desechables. No añadir importaciones de respaldos personales. Las dependencias instaladas, registros, datos privados temporales y compilaciones se retiran después de verificar; se conservan el código de regresión y el fixture anonimizado.

## Acción necesaria antes de registrar pedidos reales

**Publicar el archivo local completo `firestore.rules`.** Ejecutar Flutter no publica las reglas. No se ejecutó el siguiente comando porque el usuario pidió autorización previa para desplegar:

```powershell
firebase.cmd deploy --only firestore:rules --project proyecto-pharmalab --config firebase.json
```

Si la CLI necesita autenticar al propietario, ejecutar primero `firebase.cmd login`. El despliegue indicado publica solo reglas de Firestore, sin Functions, índices, migraciones ni cambios de plan. Como alternativa, copiar todo `firestore.rules` al editor de reglas de Firestore `(default)` en Firebase Console y pulsar Publicar. Esperar su propagación y confirmar que ya no está activa la release antigua. No sobrescribir cambios posteriores de otra persona sin compararlos.

## Repetir desde Android

Después de publicar, el propietario puede ejecutar:

```powershell
flutter run -t lib/main.dart -d 103953738A008993 --dart-define=SPARK_CHECKOUT_DIAGNOSTICS=true
```

Iniciar sesión personalmente, comprobar FARM004 y la dirección elegida, dejar una sola caja de Paracetamol y confirmar. **Esa acción del propietario sí creará un pedido real y descontará una caja**, si las reglas y la sesión lo autorizan. Esperar el resultado del servidor; no crear otro ID manualmente si queda una operación incierta. La terminal mostrará líneas `[SparkCheckout]` con la etapa exacta si algo falla. `orderExists: null` significa que todavía no se pudo comprobar, no que el pedido no exista. Cada reintento reinicia esa información; el commit confirmado la marca como verdadera.

Comprobar el nuevo pedido pendiente, el detalle LINEA1, CONFIRMACION, el registro idempotente y el delta de una caja. Abrir el vendedor para recibirlo/aprobarlo y observar el seguimiento del cliente. No cambiar PED001 ni editar manualmente inventarios para repetir la prueba.

Para ejecutar después sin diagnósticos, omitir `--dart-define=SPARK_CHECKOUT_DIAGNOSTICS=true`. No se necesita emulador para usar la aplicación.
