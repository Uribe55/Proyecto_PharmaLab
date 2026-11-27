# PharmaLab: Render Free + Firebase Spark

## Estado de la implementación

La API HTTP está en `functions/src/server.js`; `npm start` la inicia sin desplegar Cloud Functions. Usa el servidor HTTP nativo de Node.js, escucha `0.0.0.0:$PORT` y reutiliza `orders.js`, `inventory.js` y `order_actions.js`. `src/index.js` conserva los callables exclusivos de emuladores.

No se ha desplegado Render, publicado reglas, generado claves, cambiado facturación ni modificado datos operacionales. Las pruebas usan únicamente `demo-pharmalab`. El acceso operacional comenzará cuando configures las credenciales y uses la APK con la URL de tu servicio.

## 1. Proyecto Firebase identificado

**Project ID real: `proyecto-pharmalab`.** Coincide en `lib/firebase_options.dart`, `android/app/google-services.json` y `firebase.json`. No existe `.firebaserc`: los comandos siguientes incluyen `--project` para evitar seleccionar otro proyecto. `demo-pharmalab` y los proyectos `demo-pharmalab-*` de pruebas no son la base operacional.

No hay que modificar `google-services.json` ni incluir credenciales administrativas en Flutter.

## 2. Web Service en Render

| Campo | Valor |
| --- | --- |
| Repository | `https://github.com/Uribe55/Proyecto_PharmaLab.git` |
| Connection | Public Git Repository |
| Name | `pharmalab-api` |
| Branch | `main` |
| Language | Node |
| Region | Ohio (US East) |
| Root Directory | `functions` |
| Build Command | `npm ci` |
| Start Command | `npm start` |
| Compute | Free; conservar los recursos ofrecidos por Render |
| Health Check Path | `/health` |
| Pre-Deploy Command | Vacío |
| Build Filters | Vacíos |
| Persistent Disk | Ninguno |
| Auto-Deploy | Desactivado/manual durante la transición; si no está disponible para repositorio público, usar Manual Deploy |

Node.js requerido: **22.x**, declarado en `functions/package.json`. Fijar también `NODE_VERSION=22` para evitar el valor predeterminado de Render. No se necesita Firebase CLI en el servidor.

## 3. Environment Variables

| KEY | VALUE | Uso |
| --- | --- | --- |
| `NODE_ENV` | `production` | Ejecución operacional |
| `PHARMALAB_ENV` | `production` | Selección explícita y obligatoria del entorno |
| `FIREBASE_PROJECT_ID` | `proyecto-pharmalab` | Proyecto real verificado |
| `GOOGLE_APPLICATION_CREDENTIALS` | `/etc/secrets/firebase-service-account.json` | ADC de Firebase Admin |
| `NODE_VERSION` | `22` | Versión de Node en Render |
| `RATE_LIMIT_PER_MINUTE` | `60` | Solicitudes autenticadas por UID y proceso |
| `CORS_ORIGINS` | Vacío | APK Android no requiere CORS; para Web introducir exclusivamente sus orígenes HTTPS exactos, separados por comas |

`PORT` lo proporciona Render: no fijarlo. No configurar `FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST`, `FUNCTIONS_EMULATOR` ni credenciales mediante JSON público. El servidor rechaza combinaciones de producción y emulación. `.env.example` documenta las variables, pero el servidor no carga automáticamente archivos `.env`.

## 4. Cuenta de servicio y Secret Files

1. Abrir Google Cloud Console, proyecto **proyecto-pharmalab**, IAM y administración → Cuentas de servicio.
2. Crear una cuenta dedicada, por ejemplo `pharmalab-render`. No utilizar una cuenta con Owner, Editor ni Firebase Admin.
3. Asignar `roles/datastore.user` (Cloud Datastore User) para transacciones, consultas y escrituras Firestore. La API no necesita permisos de administración de bases ni de despliegue.
4. Para comprobar revocación y usuarios deshabilitados con `verifyIdToken(token, true)`, necesita además `firebaseauth.users.get`. La opción de menor alcance es un rol personalizado que contenga ese permiso. Como alternativa predefinida, `roles/firebaseauth.viewer` incluye lectura adicional de Authentication; **no** asignar Firebase Authentication Admin.
5. Crear manualmente una clave JSON de esa cuenta desde la consola. Si una política de organización impide claves, no desactivar esa política automáticamente: habrá que resolver una identidad externa compatible antes del despliegue.
6. En Render → Environment → Secret Files añadir el archivo llamado exactamente **`firebase-service-account.json`** y pegar su contenido privado allí.
7. La ruta de ejecución es **`/etc/secrets/firebase-service-account.json`**. Verificar que el `project_id` de la cuenta corresponda a `proyecto-pharmalab`; el arranque comprueba esa correspondencia sin imprimir el secreto.

La cuenta del operador que crea la clave necesita permisos IAM para hacerlo; esos permisos no deben concederse a la cuenta que ejecutará la API. El SDK usa Application Default Credentials. No necesita claves de firma de tokens personalizados: verifica los ID Tokens existentes.

IAM autoriza a Admin SDK fuera de las reglas Firestore. Por ello las transacciones comprueban propietario, rol y estado, farmacia/dirección, precios, inventario y estados. Vendedores y repartidores requieren exactamente un empleado asociado activo con el cargo correspondiente. Administradores usan su perfil activo; no se exige un empleado ficticio.

No guardar la clave en GitHub, `functions/`, Flutter, APK, logs ni documentos. `.gitignore` excluye archivos de cuentas de servicio, `.env`, claves y dependencias.

## 5. Endpoints y comportamiento

Todas las rutas `/api/*` requieren `Authorization: Bearer ID_TOKEN` obtenido de Firebase Authentication. `/health` responde `{"status":"ok"}` sin autenticación ni consultas a Firebase; comprobarlo no verifica por sí solo IAM o conectividad con Firestore.

| Método | Ruta | Operación |
| --- | --- | --- |
| GET | `/health` | Comprobación de proceso |
| POST | `/api/orders` | Confirmación múltiple transaccional |
| GET | `/api/operations/:operationId` | Recuperación idempotente del cliente propietario |
| POST | `/api/orders/:id/approve` | Aprobación por vendedor/administrador |
| POST | `/api/orders/:id/cancel` | Cancelar, solicitar, aceptar o rechazar cancelación |
| POST | `/api/orders/:id/assign` | Asignar repartidor activo |
| POST | `/api/deliveries/:id/transition` | Transición por el repartidor asignado |

Los cuerpos reutilizan el contrato existente: `operationId`, `addressId`, `notes`, `items` para confirmar; `action` y `reason` para cancelaciones; `employeeId` para asignar; `state`, `reason`, `note` para entrega. Los IDs de las rutas prevalecen sobre cualquier ID enviado en el cuerpo. Las respuestas exitosas contienen `data`; los errores contienen `error.code`, `error.message` y, cuando corresponde, precios para revisar.

Se mantienen 20 líneas comerciales, hasta 100 lotes registrados por producto y 100 lotes distintos utilizados por pedido, con validaciones de tamaño y cantidades existentes. El transporte acepta cuerpos JSON de hasta 64 KiB; puede rechazar un cuerpo aunque no alcance los límites comerciales. No se fracciona el pedido: cada confirmación o restitución se realiza en una transacción completa.

Se conserva FEFO, exclusión de vencidos, presentaciones y unidades base explícitas, inventario compartido, precios históricos, movimientos y contador. Aprobar y entregar no descuentan nuevamente inventario. Cancelar restituye los lotes históricos una sola vez; pedidos despachados no admiten esa restitución.

Los límites de solicitudes se mantienen en memoria por proceso, se reinician cuando Render reinicia y no son un límite distribuido. Hay un límite previo por conexión/IP y otro por UID; el servidor no confía en `X-Forwarded-For` arbitrario. No se registran tokens, payloads ni errores internos del SDK. No almacenar operaciones en el disco de Render.

## 6. Flutter y tiempos de espera

Selección de transporte en `OrderGateway`:

- Demostración local: continúa el repositorio local existente.
- Firebase Emulator Suite explícito: conserva los callables locales.
- Firebase real sin `PHARMALAB_API_URL`: conserva la ruta Spark histórica de un producto y un lote, mientras sus reglas estén habilitadas.
- Firebase real con `PHARMALAB_API_URL`: API HTTPS externa; consultas y suscripciones seguras continúan directamente en Firestore.

No combinar API externa y emuladores. La URL debe ser un origen HTTPS, sin credenciales, ruta adicional, query ni fragmento. Un error de Render **no activa otra ruta de escritura**.

El cliente espera hasta 120 segundos por solicitud HTTP y muestra «Conectando con el servidor de pedidos…». Guarda ID y payload pendientes en SQLite antes de enviar. Un timeout conserva la operación y el carrito; consultar o reintentar usa el mismo ID. Una respuesta perdida después del commit se recupera mediante `/api/operations/:operationId`. No cambiar de build/transporte mientras existan operaciones pendientes sin resolver.

Render Free puede suspender el servicio tras inactividad y tardar aproximadamente un minuto en reactivarlo. No se añadieron pings artificiales. Si no responde dentro del tiempo disponible, recuperar la operación en vez de crear otra.

## 7. Reglas preparadas y transición

`firestore.rules` conserva el contrato anterior y sus pruebas. **`firestore.render.rules`** es la variante preparada para el cambio; **`firebase.render.json`** la selecciona explícitamente.

La variante Render bloquea creación directa de pedidos, auxiliares de confirmación, operaciones idempotentes y descuentos Spark desde clientes. Bloquea aprobación directa de pedidos `transactional_multi_v1`; se hace por API. Conserva las lecturas autorizadas de clientes y personal, entregas sin precios para repartidores y gestión histórica Spark. Mantiene permisos administrativos existentes para mantenimiento de catálogo/inventario; no convierte al administrador en comprador por escritura directa. Las reglas del cliente no se aplican a Admin SDK.

Procedimiento manual:

1. Guardar una copia de las reglas **realmente publicadas** desde Firebase Console y revisar diferencias con ambos archivos locales. Este trabajo no descargó reglas operacionales.
2. Resolver operaciones pendientes con la versión anterior. Revisar que contador, productos y empleados existentes satisfacen el contrato; no se inicializan ni migran automáticamente.
3. Desplegar Render con las credenciales y verificar `/health`. Comprobar errores de configuración desde logs sin publicar secretos. No abrir aún el flujo de compras a usuarios.
4. Preparar/distribuir la APK con la URL efectiva de Render. Para un cierre completo del acceso Spark anterior hay que coordinar una ventana breve de cambio y retirar las versiones anteriores; no se promete cero interrupciones para APK antiguas.
5. Repetir pruebas locales y revisar `firestore.render.rules`. Publicar manualmente **solo reglas**, desde la raíz:

```powershell
firebase.cmd deploy --only firestore:rules --project proyecto-pharmalab --config firebase.render.json
```

6. Verificar manualmente con cuentas autorizadas un pedido, recuperación, aprobación, entrega y cancelación. Esa comprobación operacional crea documentos reales y no fue ejecutada automáticamente.
7. Supervisar cuotas Spark y logs. No reabrir reglas Spark como respuesta automática a un timeout. Un rollback requiere revisar primero pedidos y operaciones en curso.

No ejecutar `firebase deploy --only functions`. No usar `firebase.emulator.json` para un despliegue operacional. Al mantener dos archivos de reglas, cualquier cambio de permisos compartidos debe revisarse y probarse en ambos.

## 8. Archivos que deben estar en GitHub y despliegue

Subir `functions/package.json`, `functions/package-lock.json`, `functions/src/` completo, `functions/test/`, `functions/.env.example`, cambios de Flutter en `lib/`, `pubspec.yaml`, `pubspec.lock`, `firestore.render.rules`, `firebase.render.json` y esta guía. Incluir también los archivos todavía no versionados del trabajo anterior —modelos auxiliares, widgets, pruebas y documentación— que esos cambios utilizan. Revisar `git status --short` y `git diff` antes de seleccionar archivos. No subir `node_modules`, `build`, caches, logs, exports locales ni secretos.

No se hizo commit ni push. Cuando hayas revisado y subido tus cambios a `main`, usar **Create Web Service** o **Manual Deploy → Deploy latest commit** en Render. Los comandos del servicio son `npm ci` y `npm start`; no hay un comando Firebase para desplegar esta API. La conexión por repositorio público puede requerir despliegues manuales posteriores.

## 9. Verificación y APK

La URL definitiva no puede obtenerse del repositorio antes de crear el servicio: copiar la que Render muestre. El nombre solicitado sugiere `https://pharmalab-api.onrender.com`, pero su disponibilidad no está confirmada. No sustituir la URL por una dirección local del PC.

Desde PowerShell, asignar la URL efectiva que muestre Render:

```powershell
$apiUrl = Read-Host 'Pega el origen HTTPS que muestra Render, sin barra final'
Invoke-RestMethod "$apiUrl/health"
flutter run --dart-define="PHARMALAB_API_URL=$apiUrl"
flutter build apk --release --dart-define="PHARMALAB_API_URL=$apiUrl"
```

APK esperada: `build/app/outputs/flutter-apk/app-release.apk`. El teléfono necesita Internet; el PC puede apagarse después de instalarla. El proyecto mantiene su configuración de firma Android existente: **release utiliza actualmente la clave debug**. Sirve para instalación de prueba; para distribución formal hay que configurar una firma propia sin incluir claves en GitHub. No se modificó Gradle.

Verificar una ruta `/api/*` sin token debe devolver 401. Para probar operaciones reales, utilizar la sesión de la app; no pegar tokens en repositorios ni logs. Una respuesta correcta de `/health` solo indica que el proceso HTTP está vivo.

## 10. Pruebas reproducibles y límites pendientes

Desde la raíz, con Node 22, Java y Firebase CLI instalados:

```powershell
npm.cmd --prefix functions ci
firebase.cmd emulators:exec --project demo-pharmalab --config firebase.emulator.json --only auth,firestore,functions "npm.cmd --prefix functions test"
firebase.cmd emulators:exec --project demo-pharmalab --config firebase.emulator.json --only auth,firestore "npm.cmd --prefix functions run test:http"
Push-Location functions
firebase.cmd emulators:exec --project demo-pharmalab-security --config ../firebase.logistics-test.json --only firestore "node --test --test-concurrency=1 test/spark_checkout.rules.cjs test/logistics.rules.cjs test/employees.rules.cjs"
Pop-Location
flutter analyze
flutter test
```

Ejecutar suites de emuladores secuencialmente para no compartir puertos/hub. Las pruebas HTTP usan la variante de reglas Render, tokens reales del emulador Authentication y transacciones de Firestore emulado. Incluyen autenticación, roles, empleado desactivado, productos/lotes múltiples, FEFO, precio manipulado, concurrencia, recuperación idempotente, cancelación, bloqueo de bypass, tamaños y rate limiting. Las pruebas anteriores cubren presentaciones e inventario base. La prueba `npm start -- --smoke-test` arranca el punto de entrada real con configuración demo, comprueba `/health` y sale sin credenciales operacionales; esa opción se rechaza en producción.

Resultados ejecutados el 27/11/2026:

| Verificación | Resultado |
| --- | --- |
| `npm ci` en `functions` | Correcto: 293 paquetes instalados |
| Backend completo final con emuladores y callables | **51 pruebas aprobadas**, incluidas las 10 HTTP |
| Suite HTTP final ampliada | 10 pruebas aprobadas; incluye respuesta perdida después del commit y `npm start` real |
| Regresión de reglas Spark, logística y empleados | 103 pruebas aprobadas |
| `flutter analyze` | Sin incidencias; repetido después de formatear |
| `flutter test` | 192 pruebas aprobadas |
| Cambios en Gradle/configuración Android | Ninguno |

Las 10 pruebas HTTP incluyen la carga y ejecución de `firestore.render.rules`; la regresión de 103 utiliza `firestore.rules`. No sumar 51 y 10 como si fueran pruebas diferentes: las HTTP están incluidas en la ejecución completa final.

El host tiene Node 26.9.0; Render debe usar Node 22. No se ha validado un despliegue remoto, compilado una APK nueva para una URL definitiva ni ejecutado el teléfono contra producción. `npm ci` mostró 13 avisos en su resumen inicial; una auditoría posterior de dependencias de ejecución (`npm audit --omit=dev`) informó **12 entradas moderadas y ninguna alta/crítica**, relacionadas con la dependencia transitiva `uuid` y su cadena de SDKs. El aviso es [GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq), sobre buffers de determinadas variantes UUID; PharmaLab utiliza SHA-256 para sus IDs y no expone esas funciones directamente. npm no ofreció corrección compatible para esa cadena en la auditoría. No se forzó una sustitución de SDKs ni se afirma que el árbol esté libre de vulnerabilidades. Revisar las actualizaciones de los proveedores antes de distribución pública.

Render Free no ofrece disponibilidad continua garantizada y su documentación desaconseja usar instancias gratuitas para producción. Firestore conserva las cuotas y restricciones de Spark; un backend externo no elimina esas cuotas. No hay otra base, migración, contratación ni cambio a Blaze.

## Fuentes oficiales consultadas

- [Render: desplegar Node](https://render.com/docs/deploy-node-express-app).
- [Render: variables y Secret Files](https://render.com/docs/configure-environment-variables).
- [Render: versión Node](https://render.com/docs/node-version).
- [Render: límites gratuitos](https://render.com/docs/free).
- [Firebase Admin: ADC](https://firebase.google.com/docs/admin/setup).
- [Firebase: verificar ID Tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens).
- [Firebase: revocación de sesiones](https://firebase.google.com/docs/auth/admin/manage-sessions).
- [IAM: roles Firestore](https://docs.cloud.google.com/iam/docs/roles-permissions/firestore).
