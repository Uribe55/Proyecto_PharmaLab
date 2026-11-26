import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/screens/administrador/admin_employees_screen.dart';

void main() {
  testWidgets('la gestión EMP### no escribe en modo demostración', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminEmployeesScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Empleados'), findsOneWidget);
    expect(find.text('Modo demostración'), findsOneWidget);
    expect(find.textContaining('EMP###'), findsWidgets);
    // No se ofrece el alta porque no hay Firebase inicializado.
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsNothing);
  });
}
