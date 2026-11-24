# Etapa 4 — Ciclo de vida de pedidos, cancelaciones e incidencias

Fecha: 24 de noviembre de 2026. Iteración de Construcción de RUP sobre la rama local `feature/carrito-firebase-mvvm`. No se realizaron commits, merges ni push.

## Fuentes y alcance

No se encontró `Informe_Proyecto_PharmaLab_FINAL(1).docx` en el repositorio ni en los adjuntos accesibles. Se utilizaron exclusivamente los requisitos transcritos por el usuario. El informe original no se modificó. No se presume acceso a sus 20 RF y 15 RNF completos.

Implementación local en memoria. Firebase Auth, registro, NIT, reserva `nits_farmacia`, contador FARM, catálogo, unidades comerciales, carrito y reglas de Firestore permanecen fuera del alcance de modificación. No se escriben pedidos, entregas, historial remoto ni lotes. Se mantiene el bloqueo de confirmación real.

## Análisis y diseño incremental

Problemas anteriores: asignar iniciaba automáticamente la ruta; fallar usaba `deliveredAt`; faltaba propiedad del pedido y autorización efectiva de acciones; sincronizar eliminaba eventos no aplicados.

Flujo actual: View → OrderViewModel/DeliveryViewModel → adaptador PharmaService → OrderRepository → LocalOrderDataSource. El adaptador permite conservar las pantallas existentes sin reconstruir PharmaService. OrderPolicy es una política pura y comprobable sin Firebase. El repositorio revalida permisos, estado e inventario antes de mutar. OrderViewModel expone busy/error; DeliveryViewModel coordina el registro online local y la cola offline.

Los datos públicos mutables de los modelos se conservan para compatibilidad incremental con el proyecto. Las operaciones de la aplicación pasan por la política y el repositorio; una futura fuente remota debe verificar las mismas invariantes en un entorno confiable y no confiar en datos enviados por widgets.

## Matriz de archivos afectados

| Área | Creados | Adaptados |
|---|---|---|
| Dominio | `lib/domain/order_policy.dart`, `lib/models/order_lifecycle.dart` | `lib/models/order.dart` |
| Datos | `lib/data/datasources/local_order_data_source.dart`, `lib/data/repositories/order_repository.dart` | `lib/services/pharma/orders.dart`, `lib/services/pharma_service.dart`, `lib/services/seed_data.dart`, `lib/services/sync_service.dart` |
| MVVM | `lib/viewmodels/order_view_model.dart`, `lib/viewmodels/delivery_view_model.dart`, `lib/main_demo.dart` (arranque local explícito) | — |
| UI compartida | `lib/widgets/order_lifecycle_panel.dart`, `lib/screens/shared/order_operations_screen.dart` | `lib/widgets/order_detail_sheet.dart`, `lib/widgets/status_chip.dart` |
| Cliente | — | `lib/screens/cliente_farmacia/order_tracking_screen.dart` |
| Vendedor | — | `seller_review_screen.dart`, `seller_assign_screen.dart`, `seller_orders_screen.dart`, `seller_assignments_screen.dart` en `lib/screens/vendedor/` |
| Repartidor | — | `driver_deliveries_screen.dart`, `driver_delivery_detail_screen.dart`, `driver_failure_screen.dart`, `driver_history_screen.dart` en `lib/screens/repartidor/` |
| Administrador | — | `lib/screens/administrador/admin_shell.dart`, `lib/services/dashboard_repository.dart`, `lib/widgets/dashboard/dashboard_charts.dart` |
| Pruebas | `test/order_lifecycle_test.dart`, `test/order_lifecycle_widgets_test.dart` | `test/vendedor_flow_test.dart`, `test/repartidor_flow_test.dart` (autorización e inicio explícito de ruta; sin eliminar casos) |
| Documentación y artefactos | `docs/ETAPA_4_PEDIDOS.md` | `android/.gitignore` (excluye caché generada de Kotlin) |

## Modelos nuevos

- CancellationRequest: motivo, solicitante, fecha y resolución pendiente/aprobada/rechazada, actor y fecha de decisión. Las solicitudes previas se conservan.
- DeliveryAttempt: pedido, ID, número, repartidor, inicio, resultado preparado/en curso/fallido/entregado, motivo, observación y cierre.
- DeliveryIncident: pedido, intento, actor, fecha, motivo, observación y resultado del reporte. Una incidencia temporal no cierra el intento ni cancela el pedido.
- OrderHistoryEvent: ID, pedido, estados anterior/nuevo, operación, fecha, usuario, rol y observaciones. `toMap()` prepara su serialización; no persiste.
- LotStockAllocation: producto, lote y cantidad comercial, únicamente preparación para transacciones remotas futuras.

PharmacyOrder incorpora propietario por ID, metadatos de asignación/despacho/cancelación, intentos, incidencias, solicitudes, historial e IDs ya aplicados. `localStockDebits` registra únicamente descuentos realizados al confirmar en esta ejecución; los pedidos de ejemplo no reciben un descuento ficticio.

## Matriz de transiciones

| Estado inicial | Acción | Resultado | Condición |
|---|---|---|---|
| Pendiente | Aprobar | Aprobado | Vendedor o administrador activo |
| Pendiente | Cancelar | Cancelado | Cliente propietario y motivo |
| Aprobado | Asignar/reasignar | Aprobado | Gestor y repartidor activo; sin despacho actual |
| Aprobado | Solicitar cancelación | Aprobado | Propietario; nunca despachado; sin solicitud pendiente |
| Aprobado | Aprobar cancelación | Cancelado | Gestor; solicitud pendiente; se revalida ausencia de despacho |
| Aprobado / En ruta / Fallida | Rechazar solicitud pendiente | Sin cambio | Gestor y motivo; permite resolver una solicitud superada por el despacho |
| Aprobado asignado | Iniciar ruta | En ruta | Gestor o repartidor asignado; respetar fecha programada |
| En ruta | Incidencia temporal | En ruta | Repartidor asignado; propietario puede comunicar un problema |
| En ruta | Intento fallido | Fallida | Solo repartidor asignado; motivo; cierre del intento |
| Fallida | Reprogramar | Aprobado | Gestor; crea intento preparado y conserva los anteriores |
| Aprobado reprogramado | Iniciar ruta | En ruta | Acción explícita, después de la fecha programada |
| En ruta | Confirmar entrega | Entregado | Solo repartidor asignado; cierra intento y asigna deliveredAt |
| Aprobado / En ruta / Fallida | Coordinar o escalar | Sin cambio | Gestor; registra decisión y motivo |
| Entregado / Cancelado | Cualquier cambio de estado | Rechazado | Terminales comerciales |

Inválidas explícitas: despachar sin repartidor; cancelar después de cualquier despacho (incluso tras reprogramar); cliente ajeno; entrega por otro repartidor; entregar sin iniciar ruta; reactivar cancelado; cancelar entregado; fallar una entrega ya completada. Un replay del mismo evento aplicado y del mismo actor devuelve éxito sin nuevas consecuencias. Repetir la cancelación propia efectiva también es idempotente.

`fallida` se conserva como estado compatible, pero deja de ser final comercial. El historial del repartidor incluye fallos e intentos cerrados aun si el pedido se reprogramó.

## Matriz de permisos

| Acción | Cliente | Vendedor | Repartidor | Administrador |
|---|---|---|---|---|
| Consultar | Pedidos propios | Todos | Asignados e intentos propios históricos | Todos |
| Confirmar compra local | Propia | No | No | No |
| Aprobar pedido | No | Sí | No | Sí |
| Asignar/reasignar | No | Sí | No | Sí |
| Iniciar ruta | No | Sí, con asignación | Solo asignado | Sí, con asignación |
| Cancelar pendiente | Solo propio | No | No | No |
| Solicitar cancelación aprobado | Solo propio sin despacho | No | No | No |
| Resolver solicitud | No | Sí | No | Sí |
| Comunicar incidencia en ruta | Solo propio | Consulta/coordina | Solo asignado | Consulta/coordina |
| Confirmar entrega / fallo | No | No | Solo asignado | No |
| Reprogramar / coordinar / escalar | No | Sí | No | Sí |

Las vistas ocultan acciones no autorizadas, y el repositorio repite las verificaciones. La sesión inactiva o ausente no puede operar. No se muestran precios en el detalle del repartidor ni botones para cancelar comercialmente.

## Integridad y migración no destructiva

La confirmación local agrega cantidades por ID antes de validar el stock completo, evitando sobreventa mediante líneas repetidas. Solo después descuenta y registra el débito. Cancelar antes del despacho repone el débito exacto una vez. Aprobar, asignar, fallar o reprogramar no tocan existencias. Si falta un producto que requiere restitución se rechaza la operación completa.

Los pedidos históricos en ruta se reconocen como ya despachados. Los fallidos antiguos conservan motivo, observación y fecha histórica disponible como cierre fallido; `deliveredAt` pasa a null. No se inventa la hora de inicio ni despacho si no se conoce. La migración construye un primer intento histórico y permite reprogramarlo sin borrar antecedentes. Los pedidos con propietario desconocido no se atribuyen a un cliente por semejanza de nombre; requieren una vinculación fiable en una futura importación. Los datos de ejemplo incluyen IDs de sus propietarios.

## Cola offline

Solo memoria, sin almacenamiento duradero. Cada evento contiene ID único en la sesión, usuario, pedido, intento, acción, fecha del registro, motivo y observación. Repetir el registro no reemplaza el evento pendiente. Sincronizar comprueba sesión, rol, estado e intento; registra la fecha original del evento y retira únicamente los aplicados. Un conflicto queda visible en el detalle y se conserva hasta reintento o descarte explícito. Una cola de otro usuario permanece aislada y no se aplica al cambiar de cuenta.

Los IDs aplicados permanecen en el pedido durante esta ejecución para evitar duplicados. Al reiniciar se pierden pedidos y cola. Esto NO cumple persistencia local duradera ni sincronización remota completa.

## Trazabilidad de requisitos originales

Se mantienen las numeraciones y redacciones transcritas del informe; esta tabla describe el alcance de la iteración, no redefine los requisitos.

| RF | Texto transcrito | Evidencia / límite |
|---|---|---|
| RF-01 a RF-04 | No transcritos; conservar identificación | No evaluados ni modificados |
| RF-05 | Armar carrito de pedido. | Carrito conservado; regresión existente |
| RF-06 | Calcular automáticamente el total del pedido. | Importes y unidades comerciales conservados |
| RF-07 | Confirmar pedido y generar un número único, con estado inicial Pendiente. | Solo local; repositorio validado |
| RF-08 | Descontar stock al confirmar el pedido. | Débito único local y restitución de ese débito |
| RF-09 | Prevenir sobreventa de productos. | Validación agregada por ID y sin stock negativo |
| RF-10 | Listar pedidos pendientes para el vendedor. | Lista preservada con permisos |
| RF-11 | Aprobar pedido. | Política, actor e historial |
| RF-12 | Asignar entrega a repartidor. | Asignación separada del despacho |
| RF-13 | Listar entregas asignadas al repartidor. | Asignados sin despachar y en ruta; acceso restringido |
| RF-14 | Marcar pedido como entregado, registrando fecha y hora. | Solo asignado y con intento iniciado; deliveredAt exclusivo |
| RF-15 | Consultar el estado del pedido por el cliente. | Seguimiento reactivo, cancelación e historial |
| RF-16 | Consultar el historial de pedidos del cliente. | Filtrado por propietario; cancelados conservados |
| RF-17 | Registrar entrega fallida con observación. | Intento e incidencia separados de cancelación |
| RF-18 | Permitir modo offline básico al repartidor. | Cola local idempotente; conflictos retenidos |
| RF-19 | Gestionar usuarios y roles. | Gestión existente preservada; permisos de pedidos reforzados |
| RF-20 | Generar resumen del pedido para compartir. | Flujo existente de resumen conservado |

## Ampliación propuesta (no parte de los 20 RF originales)

- **RF-21 propuesto: Cancelar pedidos según estado y rol.** Cancelación directa pendiente propia, motivo, trazabilidad y restitución local idempotente.
- **RF-22 propuesto: Solicitar y resolver cancelaciones.** Una solicitud pendiente por pedido aprobado no despachado, aprobación/rechazo autorizado y conservación del resultado.
- **RF-23 propuesto: Registrar incidencias logísticas diferenciadas.** Diferenciar reporte temporal, intento fallido y cancelación comercial.
- **RF-24 propuesto: Reprogramar intentos de entrega.** Varios intentos del mismo pedido, asignación y fechas, sin otro descuento ni pérdida de antecedentes.

## Matriz RNF (alcance real)

| RNF | Relación con la iteración y limitación |
|---|---|
| RNF-01 Seguridad | Auth y datos de credenciales no se modifican; no hay escrituras remotas nuevas |
| RNF-02 Control de acceso | Política y repositorio comprobados por rol y propiedad en pruebas locales |
| RNF-03 | Identificado; texto no transcrito; no evaluado |
| RNF-04 Usabilidad | Acciones en componentes existentes y panel compartido; sin estudio de usuarios |
| RNF-05 Compatibilidad | Se conserva configuración Android; Android 8 no se declara probado sin dispositivo API 26 |
| RNF-06 Integridad del stock | Validación previa, agregación por ID, restitución única; pruebas locales |
| RNF-07 Persistencia local | Pendiente: pedidos y cola solo en memoria |
| RNF-08 Sincronización offline | Idempotencia y conflictos locales comprobados; remoto y persistencia pendientes |
| RNF-09 Claridad visual | Colores/estados preservados y botones nuevos con mínimo 44 px; sin auditoría completa de accesibilidad |
| RNF-10 Mantenibilidad | Modelos, política, repositorio, fuente y ViewModels separados |
| RNF-11 Escalabilidad | Contrato local y eventos serializables preparados; transacciones remotas pendientes |
| RNF-12 Tiempo de respuesta | Operaciones locales síncronas pequeñas; sin benchmark ni medición de red real |
| RNF-13 Disponibilidad para consulta | Información cargada permanece en memoria; sin garantía tras reiniciar |
| RNF-14 | Identificado; texto no transcrito; no evaluado |
| RNF-15 Documentación mínima | Este documento, matrices y pruebas |

## Diseño Firestore para la siguiente iteración (propuesta, no desplegada)

- `pedidos/{pedidoId}`: farmacia/usuario propietario, estado comercial, asignación actual, despacho, versión, totales inmutables y referencias a asignaciones de stock.
- `pedidos/{pedidoId}/solicitudes_cancelacion/{solicitudId}`: solicitante, motivo, fecha, estado y decisión de gestor.
- `pedidos/{pedidoId}/intentos_entrega/{intentoId}`: número, repartidor, inicio, resultado, cierre y observaciones.
- `pedidos/{pedidoId}/incidencias/{incidenciaId}`: actor, intento, fecha, motivo, observaciones y resultado.
- `pedidos/{pedidoId}/historial_estado/{eventoId}`: campos de OrderHistoryEvent; registro append-only.
- `pedidos/{pedidoId}/asignaciones_stock/{asignacionId}`: producto, lote y cantidad comercial efectivamente descontada.
- Registro de movimientos/eventos idempotentes con IDs estables. Confirmación y cancelación deben verificar versión, permisos y stock mediante una transacción atómica confiable. Devolver solo los lotes realmente descontados y marcar la restitución en la misma transacción.

No desplegar esta estructura sin reglas por UID/rol activo, verificación del repartidor asignado, pruebas en emulador y una decisión sobre persistencia/retención de eventos. No confiar en rol, precio ni débito suministrados por el cliente móvil. No se crearon estas colecciones ni se cambiaron las reglas actuales.

## Prueba manual Android

1. Ejecutar `flutter devices` y `flutter run -d <id-android> -t lib/main_demo.dart` desde el proyecto. Las operaciones de esta etapa se prueban con las cuentas locales de demostración de la pantalla de login, usando el arranque explícito main_demo.dart sin inicializar Firebase (las cuentas Firebase permanecen en modo consulta). No cambiar ni eliminar la configuración Firebase para simular pedidos reales.
2. Cliente: crear un pedido local, abrir seguimiento y Cancelar pedido, indicar motivo. Confirmar que permanece Cancelado en historial. Otro cliente no debe poder operarlo.
3. Vendedor: aprobar otro pedido y asignarlo. Debe permanecer Aprobado / asignado sin despachar. En Entregas, abrir el icono Cancelaciones e incidencias.
4. Cliente: solicitar cancelación del aprobado. Vendedor/administrador: resolver con motivo antes del despacho. Probar rechazo y posterior conservación del resultado.
5. Repartidor: abrir asignado y pulsar Iniciar ruta. Confirmar que ahora aparecen Confirmar entrega, Reportar incidencia temporal y No se pudo entregar.
6. Registrar incidencia temporal: el pedido sigue En ruta. Registrar fallo: cerrar intento sin deliveredAt. Vendedor: reprogramar con fecha/hora. Iniciar otro intento después de la fecha y entregar; se conserva el primero.
7. Activar Modo sin conexión desde la cuenta del repartidor. Registrar entrega/fallo, reconectar y Sincronizar ahora. Repetir no duplica; si el pedido cambió de intento, mostrar conflicto y conservar el evento.
8. Administrador: pestaña Operaciones para solicitudes, incidencias, reprogramaciones e historial. La pestaña Panel mantiene su lectura de dashboard.
9. Para Firebase: comprobar que el carrito funciona y que Confirmar pedido sigue deshabilitado; no esperar pedidos nuevos en Firestore.

La aplicación normal inicializa Firebase en main. Las cuentas locales y operaciones de demostración no deben habilitarse como fallback silencioso ante fallos de autenticación. Las pruebas automatizadas omiten main y construyen PharmaLabApp sin Firebase; la comprobación manual local utiliza el nuevo punto de entrada explícito lib/main_demo.dart.

## Verificación

| Comando | Resultado observado |
|---|---|
| `flutter pub get` | Correcto; 12 paquetes con versiones más nuevas incompatibles con las restricciones actuales; no se actualizaron dependencias |
| `dart format lib test` | Ejecutado. Se retiraron después únicamente los cambios de formato de archivos ajenos a esta etapa; los archivos nuevos y editados se formatearon |
| `flutter analyze` | No issues found; sin errores ni advertencias del analizador |
| `flutter test` | 71 pruebas aprobadas: 47 existentes conservadas/adaptadas y 24 nuevas |
| `flutter build apk --debug --target lib/main_demo.dart` | Correcto; APK en `build/app/outputs/flutter-apk/app-debug.apk` |

Las pruebas cubren cancelación propia/ajena, solicitudes duplicadas y resolución, bloqueo tras despacho o cierre, permisos, asignación separada, incidencia temporal, tres intentos sobre un pedido, fecha exclusiva de entrega, historial, reprogramación futura, descuento agregado, restitución única, eventos repetidos/conflictos offline, interfaz y validación de NIT. La suite anterior conserva carrito, bloqueo Firebase, vendedor, repartidor y administración. Las unidades no se conectan a Firebase real.

La compilación mantiene una advertencia existente sobre la futura migración al Kotlin integrado de AGP. No se cambió la configuración Android en esta iteración. No se verificó manualmente en un dispositivo Android 8 ni se realizó un ensayo autenticado real de cancelaciones (estas escrituras permanecen deshabilitadas). Ningún requisito remoto se considera cumplido por estas pruebas locales.
