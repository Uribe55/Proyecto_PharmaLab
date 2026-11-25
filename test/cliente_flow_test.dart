import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';
import 'package:proyecto_final_movil/widgets/product_card.dart';

void main() {
  testWidgets('Flujo completo del cliente farmacia', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();

    // Acceso con la cuenta de prueba del cliente.
    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('María Fernández'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Productos destacados'), findsOneWidget);

    // Recorrer el inicio para construir todas las tarjetas.
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    // Carrito vacío.
    await tester.tap(find.text('Carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Tu carrito está vacío'), findsOneWidget);

    // Catálogo y detalle.
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('Productos destacados'), findsOneWidget);
    expect(find.byType(ProductCard), findsWidgets);

    final productTitle = find.text('Glucosa oxidasa (reactivo)').first;
    await tester.ensureVisible(productTitle);
    await tester.pumpAndSettle();
    await tester.tap(productTitle);
    await tester.pumpAndSettle();
    expect(find.text('Detalle de producto'), findsOneWidget);
    expect(find.textContaining('Añadir al carrito'), findsOneWidget);

    await tester.tap(find.textContaining('Añadir al carrito'));
    await tester.pumpAndSettle();

    // Volver y revisar el carrito.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar pedido'), findsOneWidget);

    // Confirmar el pedido.
    await tester.tap(find.text('Continuar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen de compra'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Progreso de entrega'), findsOneWidget);

    // Historial y perfil.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Cada pedido, a la vista.'), findsOneWidget);

    await tester.tap(find.text('Mi cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Datos de la farmacia'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });
}
