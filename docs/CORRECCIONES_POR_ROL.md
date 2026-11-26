# Correcciones funcionales por rol

## Causas y soluciones

- **Teléfono del personal:** el login leía solo `usuarios`. Ahora consulta `empleado` por `usuario_id == UID` y prioriza su teléfono; conserva el dato de `usuarios` como respaldo para cuentas sin documento de empleado. No confunde UID con EMP. La cuenta muestra «Sin teléfono registrado» cuando falta el dato. La edición propia guarda el teléfono en el empleado vinculado, sin crear otro campo duplicado; el perfil de usuario conserva los datos generales.
- **Cancelar Mi cuenta:** los controladores se eliminaban al completar `showDialog`, antes de que acabara la animación de cierre. `ContactEditDialog` es dueño de sus controladores y devuelve un borrador solo al guardar. Cancelar no llama al servicio ni altera los valores originales. Se usa también en el perfil del cliente. El diálogo remoto de entrega fallida espera la destrucción de su ruta antes de liberar su controlador.
- **Pedidos del vendedor:** había filtros incompletos y no se priorizaban pendientes antiguos. La política compartida filtra todos los estados existentes, incluidos reprogramados y cancelados. En Todos coloca los pendientes primero, ascendentes por fecha, y después los restantes descendentes; en cada categoría aplica el orden correspondiente. Fechas faltantes o inválidas quedan al final de su grupo, sin ordenar por ID ni mostrar una fecha ficticia. El modelo mantiene una marca de fecha conocida por compatibilidad con sus consumidores existentes.
- **Entregas:** las pantallas remotas eran principalmente bloques de texto. Se incorporaron tarjetas compartidas con pedido, entrega, farmacia, dirección, contacto, fechas, estado, repartidor para el vendedor y acciones operativas. Los datos secundarios se consultan mediante detalle. Se conservaron asignación, inicio, entrega exitosa, fallo y las restricciones de transición. El repartidor sigue sin visualizar importes comerciales.
- **Mis entregas e Historial:** hay categorías horizontales para todas, asignadas, en ruta, entregadas y fallidas. El historial contiene exclusivamente entregas exitosas, ordenadas por fecha efectiva y sin duplicados. La fuente remota conserva la búsqueda del EMP por UID y consulta entregas por ese EMP; adicionalmente verifica el UID cuando está presente. Los documentos de otros repartidores permanecen protegidos por las reglas. Las tarjetas finalizadas no ofrecen acciones de reinicio o cierre.
- **Catálogo y detalle:** cuando el producto ya está en el carrito, el botón pasa a «Ver carrito». Un acceso compartido devuelve a la pestaña existente del carrito, sin añadir otra unidad ni crear otro carrito. Los listados escuchan los cambios del carrito y restauran `+` al eliminar la línea. La identidad se conserva por ID de producto/presentación comercial.
- **Cantidad editable:** el carrito usa un campo numérico entre los botones, con controlador y foco propios y una clave estable por producto. Conserva el texto temporal vacío, rechaza negativos y decimales, valida al confirmar o perder foco, normaliza cero a uno y limita cantidades al stock con un mensaje. Los subtotales y totales se actualizan al confirmar el valor. El botón menos queda desactivado en uno; Eliminar permanece independiente.
- **Inventario:** se conservó la disponibilidad obtenida desde lotes y su reconciliación con el carrito. Se añadió la exclusión de lotes desactivados en catálogo, selección, validación transaccional y reglas. La confirmación vuelve a leer stock y datos del lote dentro de la transacción existente. No se descuenta stock al añadir al carrito y se conserva la idempotencia de las operaciones.

## Unidades comerciales y alcance

El esquema existente cuenta el stock por unidad comercial del documento de producto: por ejemplo, 100 cajas. `unidad_por_envase` describe el contenido y no convierte esas 100 cajas en tabletas. Se conserva esta convención, que ya tiene pruebas de regresión. El carrito agrupa por ID, por lo que las cantidades del mismo producto se acumulan en una sola línea y comparten su límite. No se inventaron relaciones de stock común entre documentos distintos: el esquema actual no define presentaciones intercambiables sobre un inventario base compartido.

La confirmación Spark mantiene su restricción existente de **un producto y un lote por pedido**. Si ningún lote vigente cubre la cantidad, rechaza toda la operación; no combina lotes ni confirma parcialmente un carrito con varios productos. No se amplió el checkout para ocultar esta limitación.

No se cambiaron las pantallas, gráficas, indicadores ni componentes de scroll del administrador. No se instalaron dependencias ni se modificaron datos Firebase reales. No se hicieron commit, push ni despliegues.

## Seguridad y publicación

La lectura del empleado propio ya estaba permitida. Fue indispensable añadir una actualización estricta de `telefono` para un empleado activo que sea dueño del documento; no puede cambiar cargo, UID, estado o identificadores. También se rechazan ventas de lotes con `estado: false`.

Las reglas están modificadas localmente y **no publicadas**. La edición propia del teléfono requiere publicar esta versión. Comando manual desde la raíz:

```powershell
firebase.cmd deploy --only firestore:rules --project proyecto-pharmalab --config firebase.json
```

No hacen falta nuevas colecciones, índices ni inicializaciones de datos.

## Verificación

Se ejecutaron `dart format lib test`, `flutter analyze` y la suite completa de Flutter. El formato ajeno a estos cambios se retiró para conservar el alcance. El resultado final y el detalle de las pruebas se registran en `CORRECCIONES_POR_ROL_VERIFICACION.json`.

Las pruebas incluyen filtros y antigüedad, fechas desconocidas, navegación y sincronización del carrito, cantidades vacías/inválidas/excesivas, conservación de foco, cancelación del perfil, historial exitoso sin duplicados, diálogos remotos, aprobación, cierre y fallo de entregas, stock transaccional, idempotencia y regresiones administrativas de scroll.

Las pruebas de Firestore Rules se ejecutaron únicamente en emulador local con proyectos `demo-*`, sin importar respaldos: 97 aprobadas, cero fallos. Incluyen teléfono propio, bloqueo de modificaciones ajenas, lotes desactivados y regresiones de registro, compra, numeración y logística.

## Comprobación manual pendiente

No se verificaron cuentas de producción ni una sesión Android física. Revisar con cuentas reales autorizadas, después de publicar las reglas cuando corresponda:

1. Teléfono de vendedor, repartidor y administrador al iniciar sesión; editar el teléfono permitido y cotejar el empleado vinculado por UID.
2. Cancelar perfil con el teclado abierto; comprobar que no se guarda nada y que se conservan los datos.
3. Pedidos de todos los estados, pendientes antiguos y registros sin fecha válida.
4. Entregas exclusivas de cada repartidor, inicio, cierre exitoso, fallo y actualización de Historial.
5. Catálogo, detalle, navegación al carrito, cantidades manuales y reducción de stock mientras se edita.
6. Aspecto táctil de tarjetas y botones en los tamaños Android usados por el equipo.

Usar operaciones comerciales genuinas autorizadas para producción; mantener pruebas experimentales en el emulador.

## Archivos

Los archivos creados y modificados están enumerados en el registro de verificación adjunto. Se reutilizaron AppTheme, AppColors, AppText, AppTabHeader, EmptyState, los repositorios y ViewModels existentes, los botones y el mecanismo transaccional Spark.
