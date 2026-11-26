# Etapa 7: empleados y dashboard

Trabajo continuado sobre `main`, sin commit, push, despliegue ni escrituras en Firebase real. No se cambiaron las transacciones de compra o logística, Gradle, Java, Kotlin ni los recursos Android.

## Estado recibido de OpenCode

Había 12 archivos rastreados modificados y 9 archivos nuevos. Ya existían el modelo Employee, repositorio, listado, formulario, hora de Bolivia, pruebas de empleados y avances en indicadores y gráficas. El análisis inicial no tenía errores y las 168 pruebas Flutter iniciales pasaron. Se conservaron esos avances.

Faltaba resolver el límite sin orden de 300 pedidos, la recuperación de detalles históricos, cambios locales anteriores a la persistencia, vías de edición de personal separadas de EMP, coherencia bidireccional de reglas y cobertura de concurrencia. El repositorio nuevo repetía el mecanismo de Auth secundaria del servicio anterior.

## Implementación final

- `Usuarios → Gestionar empleados EMP###`: listado Firestore con correo asociado, búsqueda, filtro de cargo, registro, edición y activación/desactivación. Las altas y ediciones de personal desde Usuarios conducen a esta gestión, evitando otro registro paralelo.
- El alta valida al administrador contra Firestore antes de crear credenciales. Usa el mecanismo de Firebase Auth secundaria del servicio existente y conserva la sesión principal. Nunca almacena contraseñas en Firestore ni elimina cuentas de Auth para compensar errores.
- Una transacción crea `empleado/EMP###`, `usuarios/{uid}` e incrementa `configuracion/contadores_empleados`. Los IDs EMP son los IDs reales de documentos. El contador no se inicializa desde la app. Rechaza un UID ya perfilado y conserva IDs y fechas históricos.
- Auth y Firestore NO son una transacción conjunta. Si falla Firestore, se conserva el UID y se ofrece completar el perfil. El repositorio conserva el borrador original para impedir que el reintento vincule otro correo. Después de reiniciar, repetir el formulario con el correo y contraseña originales autentica la cuenta secundaria existente y recupera su UID real; no crea otra cuenta.
- Edición y estado de empleado/usuario se guardan juntos. Las reglas rechazan cambios separados de estado/rol y cambios del vínculo EMP de perfiles enlazados. Un repartidor inactivo deja de cumplir `activeRole` para operaciones protegidas; sus entregas históricas permanecen.
- `updateUser` y `updateOwnProfile` esperan la persistencia antes de actualizar memoria; perfil propio y farmacia usan batch. `setUserActive` espera Firestore y dirige el personal a Empleados. La simulación de deuda no altera el estado de un cliente en modo Firebase.
- Dashboard interpreta `linea` Spark, fechas logísticas y esquemas históricos. Solo consulta `detalle_pedido` si falta la línea principal y nunca suma ambas representaciones. Los detalles recuperados se conservan al reconstruir el catálogo/listado. Acepta precios numéricos y cadenas decimales.
- Pedidos del día/mes, importes registrados y por estado, ventas entregadas diarias/mensuales/trimestrales, ticket, evolución y rankings usan los datos leídos de Firestore. `fecha_pedido` tiene prioridad para registro; ventas por fecha efectiva de entrega. `actualizado_en` no se inventa como fecha de entrega. Los importes se muestran en Bs, sin cobros, costos ni utilidades inventados.
- Se usa hora comercial de Bolivia UTC-4. Un histórico entregado sin fecha efectiva conserva el importe pero no entra en ventas por período.

## Contador: preparación manual pendiente

No se leyó la base de producción para confirmar su máximo actual, ni se inicializó ningún contador real. Antes de registrar personal, revisar Firebase Console, colección `empleado`, y comprobar TODOS los IDs existentes, incluidos empleados inactivos. No usar la cantidad de documentos como máximo.

Si los únicos IDs asignados son EMP001, EMP002 y EMP003 y el siguiente está libre, crear en Firestore:

```text
configuracion/contadores_empleados
  ultimo_numero: 3       (number entero)
  ultimo_id: "EMP003"    (string)
```

Si hay IDs superiores, usar el mayor número ya asignado y su EMP correspondiente; nunca retroceder ni reutilizar. Si el documento existe, revisar su coherencia antes de tocarlo. La app solo incrementa un contador previamente creado; las reglas no permiten crearlo desde el cliente. El siguiente registro con 3/EMP003 será EMP004, luego EMP005 y EMP006.

## Publicación manual de reglas

El archivo final es `firestore.rules` en la raíz del proyecto. No se publicó. Desde la raíz, cuando se decida desplegar:

```powershell
firebase.cmd deploy --only firestore:rules --project proyecto-pharmalab --config firebase.json
```

Las reglas mantienen los flujos de farmacia/NIT, stock, numeración comercial, aprobación y entrega. Eliminan el permiso de autoedición de `tiene_deuda_vencida`. No usan permisos abiertos.

## Recuperación de registros parciales

1. Guardar el UID y correo que muestra el error; no crear manualmente un segundo empleado con el mismo UID.
2. Corregir conexión, reglas o contador y pulsar `Completar perfil pendiente` en el mismo formulario.
3. Si se cerró la app, abrir Nuevo empleado y usar el mismo correo y contraseña temporal. La instancia secundaria verifica las credenciales y recupera el UID. Si ya existe un perfil, el alta se rechaza: revisar el listado, sin sobrescribirlo.
4. Si no se conoce la contraseña, un operador autorizado debe revisar la cuenta en Firebase Authentication Console, cotejar UID/correo y usar el procedimiento de restablecimiento de contraseña. Después completar el alta con credenciales verificadas. No introducir un UID arbitrario en Flutter.
5. Si existe un vínculo incoherente entre usuario y empleado, revisar ambos documentos manualmente en Console antes de reintentar. No borrar históricos ni modificar el contador para ocultar un error.

## Verificación y límites

Las pruebas usan exclusivamente datos desechables en proyectos `demo-*`, Firestore local 127.0.0.1:8085, sin importar respaldos. No se probaron altas/compras en producción.

```powershell
flutter pub get
flutter analyze
flutter test
firebase.cmd emulators:exec --only firestore --project demo-pharmalab-employees --config firebase.logistics-test.json "cd functions && node --test --test-concurrency=1 test/employees.rules.cjs test/logistics.rules.cjs test/spark_checkout.rules.cjs"
```

Los resultados finales se registran en `ETAPA_7_VERIFICACION.json`. Las pruebas de reglas verifican EMP004, exclusión de roles, enlaces, contador, saltos, sobrescrituras, concurrencia, estado coherente y regresiones comerciales/logísticas. Las pruebas Flutter incluyen mapeo Spark, decimales, cambio de día UTC-4, fecha de pedido diferente de entrega, histórico sin fecha y cálculos financieros. La conservación de sesión Auth y los errores reales del plugin Firebase móvil requieren la comprobación integrada descrita abajo; las pruebas unitarias no equivalen a probar producción.

Los pedidos y entregas se leen completos mediante paginación ordenada por ID, con actualización cada minuto y refresco del dashboard. `maxOrders` es el tamaño de página, no un límite de cobertura. Esto conserva documentos antiguos sin `fecha_pedido`, pero su costo crece con el historial. Las páginas y las dos colecciones no son una instantánea atómica: durante cambios concurrentes puede haber una discrepancia temporal hasta el refresco. Para un volumen grande se necesitará una estrategia de agregados y migración de fechas antes de restringir por ventanas sin perder históricos. En Spark conviene evitar mantener el panel abierto innecesariamente.

Los rankings dependen de los detalles disponibles y categorías del catálogo actual cuando el pedido no guardó categoría histórica. Los detalles históricos se consultan una vez por sesión y no son una escucha en vivo. Un error de lectura se informa; no se sustituyen datos reales por demo. Las ventas entregadas no prueban pago. No se validó visualmente una sesión Android conectada a Firebase real.

## Comprobación integrada con administrador

Primero usar el emulador o una instancia aislada. Para una operación real posterior, usar un empleado genuino autorizado, nunca un registro experimental en producción.

1. Verificar el contador en Console y publicar las reglas manualmente cuando corresponda.
2. Iniciar sesión con administrador activo. En Usuarios, abrir Empleados y revisar los históricos y sus correos.
3. Dar de alta al empleado autorizado con nombre, apellido, correo, teléfono, cargo y contraseña temporal. Verificar que el administrador continúa conectado y que solo aparece éxito al confirmarse Firestore.
4. Cotejar UID en Authentication, `usuarios/{uid}.empleado_id`, `empleado/EMP004.usuario_id`, roles/cargos y contador 4/EMP004. Repetir con empleados genuinos posteriores para EMP005/EMP006.
5. Editar datos y volver a cargar el listado. Desactivar en Empleados y verificar `estado: false` en ambos documentos. Comprobar que el repartidor no puede iniciar una nueva operación protegida y que sus históricos permanecen. Reactivar cuando proceda.
6. En el entorno aislado, provocar un fallo de Firestore después de Auth: debe aparecer perfil pendiente y ningún éxito. Corregirlo, completar y confirmar que no se creó otra cuenta ni se consumió doble número.
7. Comparar los importes del dashboard con los pedidos reales sin modificarlos: fechas comerciales UTC-4, totales de líneas una sola vez y fecha de entrega distinta de fecha de registro. Comprobar períodos diario, mensual y trimestral.

## Archivos afectados

Se conservaron y completaron: `firestore.rules`, `functions/package.json`, `functions/test/employees.rules.cjs`, `lib/models/employee.dart`, `lib/models/dashboard_metrics.dart`, `lib/models/dashboard_models.dart`, `lib/services/employee_repository.dart`, `lib/services/dashboard_repository.dart`, `lib/services/pharma/users.dart`, `lib/utils/bolivia_time.dart`, `lib/viewmodels/admin_dashboard_viewmodel.dart`, `lib/screens/administrador/admin_dashboard_screen.dart`, `admin_employee_form_screen.dart`, `admin_employees_screen.dart`, `admin_user_form_screen.dart`, `admin_users_screen.dart`, `lib/widgets/dashboard/dashboard_charts.dart`, `test/admin_employees_local_test.dart`, `test/bolivia_time_test.dart`, `test/employee_model_test.dart`, `test/dashboard_metrics_test.dart` y el nuevo `test/dashboard_firestore_mapping_test.dart`. Se añadieron este informe y el registro de verificación.
