import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';

Future<void> _loginAs(WidgetTester tester, String name) async {
  await tester.tap(find.text('Ver'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('El vendedor aprueba y asigna un pedido', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();
    await _loginAs(tester, 'Ana Vargas');

    expect(find.text('Pedidos de farmacias.'), findsOneWidget);
    expect(find.text('PL-2026-0841'), findsOneWidget);

    // Revisión y aprobación (RF-11).
    await tester.tap(find.text('PL-2026-0841'));
    await tester.pumpAndSettle();
    expect(find.text('Revisión y aprobación'), findsOneWidget);
    expect(find.text('Verificación de stock'), findsOneWidget);

    await tester.tap(find.text('Aprobar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();

    // Asignación de entrega (RF-12).
    expect(find.text('Asignación de entrega'), findsOneWidget);
    await tester.ensureVisible(find.text('Carlos Mendoza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Mendoza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar a Carlos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar'));
    await tester.pumpAndSettle();

    expect(find.text('Panel de pedidos'), findsOneWidget);
    expect(
      PharmaService.instance.orders
          .firstWhere((order) => order.number == 'PL-2026-0841')
          .status
          .label,
      'En ruta',
    );

    // La entrega aparece en la pestaña de logística.
    await tester.tap(find.text('Entregas'));
    await tester.pumpAndSettle();
    expect(find.text('Del almacén a la farmacia.'), findsOneWidget);
    expect(find.text('PL-2026-0841'), findsOneWidget);
  });
}
