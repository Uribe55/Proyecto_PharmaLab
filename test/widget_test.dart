import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';
import 'package:proyecto_final_movil/widgets/pharma_logo.dart';

void main() {
  testWidgets('La pantalla de inicio de sesión se muestra', (tester) async {
    await tester.pumpWidget(const PharmaLabApp());
    await tester.pump();

    expect(find.text('Bienvenido de nuevo.'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrar cliente'), findsOneWidget);
  });

  testWidgets('Los formularios se desplazan en una pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();
    expect(find.byType(PharmaLogo), findsOneWidget);

    final register = find.text('Registrar cliente');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pumpAndSettle();
    expect(find.byType(PharmaLogo), findsOneWidget);

    await tester.showKeyboard(find.byType(EditableText).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final submit = find.text('Crear cuenta');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
