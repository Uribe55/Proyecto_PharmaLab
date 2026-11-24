## Estado de integración (22 de noviembre de 2026)

Integrado sobre el catálogo Firebase/MVVM existente. Se corrigió el cierre de main en la prueba incluida en el ZIP y un aviso de estilo en Product. Validación: flutter analyze sin problemas y flutter test con 12 pruebas aprobadas. No se modificaron el servicio de registro ni las reglas de Firestore en esta integración. La comprobación manual con una cuenta Firebase sigue pendiente.

El documento original del ZIP se conserva debajo como referencia; los pasos de copia ya están completados.

# PharmaLab — selector informativo y unidades comerciales

## Objetivo
Mostrar precios por caja (u otra unidad comercial), stock en cajas, permitir sumar/restar unidades y calcular un total estimado sin registrar pedidos ni descontar lotes de Firestore.

## Instalación
1. Guarda una copia del proyecto actualizado (o crea una rama de Git).
2. Copia los archivos `lib/` del parche a las MISMAS rutas dentro del proyecto, combinando carpetas y sustituyendo solo archivos coincidentes.
3. Copia `test/product_sale_units_test.dart` a `test/`.
4. No reemplaces `pharma_service.dart`, ni las reglas `firestore.rules`, ni ninguna colección en Firebase.
5. Ejecuta `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`.

## Qué hará la pantalla
- Lee `unidadMedida` (tal como aparece en tu Firestore) o `unidad_medida` como nombre alternativo, y `unidad_por_envase`.
- Muestra `Bs 150,00` por caja, `Stock: 100 cajas` y `Cantidad de cajas`.
- Los botones `+` y `−` modifican solo `_quantity` (estado local en la pantalla).
- El pie muestra el total estimado y mantiene el botón de compras deshabilitado para el catálogo Firebase.
- No escribe en `pedidos`, `lotes_productos` ni ninguna colección. Tampoco agrega artículos al carrito del modo Firebase.
- El modo de demostración local conserva su botón de carrito.

## Prueba manual
En la cuenta Firebase abre PROD001 (Paracetamol), pulsa + dos veces: debe mostrar 3 cajas y Bs 450. Vuelve a consultar `lotes_productos/LOTE001`: la cantidad debe seguir siendo 100. Comprueba también guantes: 2 cajas = Bs 170, existencias siguen siendo 50.

Nota: cuando se implemente la compra real, se necesitará una transacción de servidor que valide existencias y descuente lotes. Cambiar solo esta pantalla NO realiza compras.

Este paquete fue preparado desde la versión de catálogo Firebase/MVVM que se compartió anteriormente y no se ha ejecutado Flutter en este contenedor.
