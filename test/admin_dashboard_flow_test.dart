import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';
import 'package:proyecto_final_movil/screens/administrador/admin_dashboard_screen.dart';
import 'package:proyecto_final_movil/screens/administrador/admin_shell.dart';

Future<void> _loginAs(WidgetTester tester, String name) async {
  await tester.tap(find.text('Ver'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pumpAndSettle();
}

Finder _dashboardList() {
  return find
      .descendant(
        of: find.byType(AdminDashboardScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  // Las pestañas vuelven a su posición al regresar al inicio del contenido.
  final position = tester.state<ScrollableState>(_dashboardList()).position;
  position.jumpTo(position.minScrollExtent);
  await tester.pumpAndSettle();
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el panel administrativo bloquea roles no autorizados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AdminShell()));
    await tester.pumpAndSettle();

    expect(find.text('Acceso restringido'), findsOneWidget);
    expect(find.text('Volver al inicio de sesión'), findsOneWidget);
    expect(find.text('Todo PharmaLab, a la vista.'), findsNothing);
  });

  testWidgets('el dashboard navega entre pestañas y abre sus listados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();
    await _loginAs(tester, 'Laura Rojas');

    expect(find.text('Todo PharmaLab, a la vista.'), findsOneWidget);
    expect(find.text('Resumen operativo'), findsOneWidget);
    expect(find.text('Recibidos hoy'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Alertas accionables'),
      250,
      scrollable: _dashboardList(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alertas accionables'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _openTab(tester, 'Ventas');
    expect(find.text('Análisis comercial'), findsOneWidget);
    expect(find.text('Valor de pedidos entregados'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Productos más vendidos'),
      300,
      scrollable: _dashboardList(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Productos más vendidos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _openTab(tester, 'Logística');
    expect(find.text('Logística y entregas'), findsOneWidget);
    expect(find.text('Tasa de éxito'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Actividad reciente'),
      300,
      scrollable: _dashboardList(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Actividad reciente'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Ver todos'),
      200,
      scrollable: _dashboardList(),
    );
    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos de farmacias.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardScreen), findsOneWidget);

    await _openTab(tester, 'Inventario');
    expect(find.text('Inventario y vencimientos'), findsOneWidget);

    await tester.tap(find.text('Ver inventario'));
    await tester.pumpAndSettle();
    expect(find.text('Existencias y vencimientos.'), findsOneWidget);
    expect(find.text('Resumen de stock'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardScreen), findsOneWidget);

    await _openTab(tester, 'Empleados');
    expect(find.text('Modo demostración'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AdminDashboardScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Usuarios'));
    await tester.pumpAndSettle();
    expect(find.text('Gestión de usuarios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
