## Estado de la integración (22 de noviembre de 2026)

Parche integrado en el proyecto existente. Validación local: flutter analyze sin problemas y flutter test con 10 pruebas aprobadas. Se añadió la referencia a firestore.rules en firebase.json. Las reglas no se publicaron ni se verificaron contra Firebase o su emulador. El registro y la validación de NIT existentes se conservaron. Los pedidos reales siguen bloqueados según el alcance del parche.

Las siguientes instrucciones y limitaciones corresponden al documento original del ZIP; sus pasos de copia ya se completaron y su nota sobre falta de SDK describe únicamente la preparación original del parche.

# PharmaLab: catálogo real Firestore (MVVM) — fase de lectura

Basado en `Proyecto_PharmaLab(1).zip` del usuario, sin cambiar las colecciones, el registro de farmacias ni el control de NIT.

## Antes de instalar

1. Guarda una copia de tu proyecto o crea una rama: `git switch -c feature/catalogo-firestore`.
2. Guarda una copia de las reglas actuales publicadas en Firestore.
3. El contenido del archivo `firestore.rules` incluido aquí conserva el registro actual y añade solo los permisos de lectura de `categorias`, `productos` (activos) y `lotes_productos`, para cuentas con `usuarios/{uid}.rol == 'cliente'` y `estado == true`.
4. Comprueba las nuevas reglas con Firebase Emulator Suite cuando te sea posible. Pégalas en Firestore Database → Reglas y pulsa «Publicar». La regla final que deniega operaciones no impide lecturas expresamente autorizadas por otras reglas.
5. Copia la carpeta `lib/` y el archivo nuevo `test/catalog_repository_test.dart` a la raíz del proyecto, reemplazando archivos con la misma ruta. No borres ni reemplaces carpetas enteras: combina su contenido.

## Ejecución en VS Code

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Usa una cuenta real de farmacia activa, no un usuario demo. Abre el inicio y luego el catálogo.

## Resultado esperado

- `PROD001`: Paracetamol, Bs 150, categoría Medicamentos, stock 100 (LOTE001 vigente).
- `PROD002`: Guantes de nitrilo, Bs 85, categoría tomada de CAT002, stock 50 (LOTE002 sin fecha, `requiere_vencimiento: false`).
- Al cambiar temporalmente `productos/PROD001.precio` desde Firebase, el catálogo debería reflejar el nuevo precio y después el anterior al revertirlo. No cambies el valor de stock si no estás realizando un ajuste real de inventario.
- El cliente puede buscar y filtrar por categorías que existen en Firestore.
- Las tarjetas y detalles de productos reales son de solo lectura. La confirmación de pedidos reales está bloqueada hasta que implementemos pedidos con transacciones en Firestore.
- Los pedidos de demostración no se mostrarán en el historial de una cuenta real.

## Estructura MVVM introducida

- `lib/data/datasources/firestore_catalog_data_source.dart`: consulta Firestore en tiempo real.
- `lib/data/repositories/catalog_repository.dart`: transforma documentos y agrega stock por lotes.
- `lib/viewmodels/catalog_view_model.dart`: administra la carga y el estado para la interfaz.
- `lib/models/catalog_category.dart` y `lib/models/product_batch.dart`: entidades del catálogo.
- `lib/screens/cliente_farmacia/` y widgets: consumen el ViewModel, conservando diseño existente.

## Advertencias

- No se tocó Authentication, NIT, contador ni la lógica de registro.
- Esta fase no crea pedidos ni modifica inventario.
- Los lotes sin fecha no aportan stock a un producto con `requiere_vencimiento == true`. Los lotes con fecha vencida tampoco aportan stock.
- La vista de detalle abierta no se actualiza automáticamente si cambia un producto mientras el detalle está visible; regresar al catálogo permite ver el nuevo valor.
- El cálculo de vencimiento usa la fecha del dispositivo cuando se cargan/actualizan los datos. En una futura versión productiva debe definirse una fuente horaria fiable y la política de corte.
- No se ejecutó Flutter en el entorno de preparación del parche porque el SDK no está disponible. Valida `flutter analyze` y `flutter test` en tu PC; si hay errores, comparte el primer mensaje de error completo.
