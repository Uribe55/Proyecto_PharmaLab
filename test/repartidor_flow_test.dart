import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';
import 'package:proyecto_final_movil/screens/repartidor/driver_delivery_detail_screen.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/services/sync_service.dart';

Future<void> _loginAs(WidgetTester tester, String name) async {
  await tester.tap(find.text('Ver'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pumpAndSettle();
}

//actor repartidor
void main() {
  testWidgets('El repartidor cierra una entrega sin ver precios', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();
    await _loginAs(tester, 'Carlos Mendoza');

    expect(find.text('RUTA DEL DÍA'), findsOneWidget);
    expect(find.text('PL-2026-0842'), findsOneWidget);

    await tester.tap(find.text('PL-2026-0842'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de entrega'), findsOneWidget);
    expect(find.textContaining('Bs '), findsNothing);
    expect(find.text('Confirmar entrega'), findsOneWidget);

    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, entregado'));
    await tester.pumpAndSettle();

    expect(
      find.text('Todas'),
      findsOneWidget,
    ); // La vista Todas conserva las finalizadas.
    expect(
      PharmaService.instance.orders
          .firstWhere((order) => order.number == 'PL-2026-0842')
          .status
          .label,
      'Entregado',
    );

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Tu historial de ruta.'), findsOneWidget);
    expect(find.text('PL-2026-0842'), findsOneWidget);
  });

  testWidgets('El repartidor registra una entrega sin conexión y sincroniza', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = PharmaService.instance;
    await service.login(
      email: service.users.firstWhere((u) => u.role.name == 'vendedor').email,
      password: PharmaService.demoPassword,
    );
    final order = service.orders.firstWhere(
      (item) => item.number == 'PL-2026-0809',
    );
    final carlos = service.users.firstWhere(
      (user) => user.email == 'carlosm@rep.pharma.com',
    );
    expect(service.assignDelivery(order, carlos), isTrue);
    await service.logout();

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();
    await _loginAs(tester, 'Carlos Mendoza');

    // Activar el modo sin conexión desde la cuenta (RF-18).
    await tester.tap(find.text('Mi cuenta'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Modo sin conexión'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo sin conexión'));
    await tester.pumpAndSettle();
    expect(SyncService.instance.isOffline, isTrue);

    // Registrar la entrega sin conexión.
    await tester.tap(find.text('Mis entregas').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PL-2026-0809'),
      240,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.text('PL-2026-0809'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar ruta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, entregado'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(SyncService.instance.pendingCount, 1);
    expect(order.status.label, 'En ruta');

    // Volver a conectar y sincronizar.
    await tester.tap(find.text('Mi cuenta'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Modo sin conexión'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo sin conexión'));
    await tester.pumpAndSettle();
    expect(SyncService.instance.isOffline, isFalse);

    await tester.ensureVisible(find.text('Sincronizar ahora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sincronizar ahora'));
    await tester.pumpAndSettle();

    expect(SyncService.instance.pendingCount, 0);
    expect(order.status.label, 'Entregado');
  });

  testWidgets('El repartidor registra una entrega fallida', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = PharmaService.instance;
    await service.login(
      email: service.users.firstWhere((u) => u.role.name == 'vendedor').email,
      password: PharmaService.demoPassword,
    );
    final order = service.orders.firstWhere(
      (item) => item.number == 'PL-2026-0839',
    );
    final carlos = service.users.firstWhere(
      (user) => user.email == 'carlosm@rep.pharma.com',
    );
    expect(service.approveOrder(order), isTrue);
    expect(service.assignDelivery(order, carlos), isTrue);
    await service.logout();

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();
    await _loginAs(tester, 'Carlos Mendoza');

    await tester.scrollUntilVisible(
      find.text('PL-2026-0839'),
      240,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.text('PL-2026-0839'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar ruta'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo entregar'), findsOneWidget);
    await tester.tap(find.text('No se pudo entregar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué ocurrió con la entrega?'), findsOneWidget);
    await tester.tap(find.text('La farmacia estaba cerrada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar entrega fallida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Entrega reprogramada: La farmacia estaba cerrada'),
      160,
      scrollable: find.descendant(
        of: find.byType(DriverDeliveryDetailScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Entrega reprogramada: La farmacia estaba cerrada'),
      findsOneWidget,
    );
    expect(order.status.label, 'Reprogramado');
    expect(order.failureReason, 'La farmacia estaba cerrada');
  });
}
