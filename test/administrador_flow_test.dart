import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';
import 'package:proyecto_final_movil/screens/administrador/admin_user_form_screen.dart';
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
  testWidgets('El administrador crea y desactiva un usuario', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PharmaLabApp());
    await tester.pumpAndSettle();
    await _loginAs(tester, 'Laura Rojas');

    expect(find.text('Todo PharmaLab, a la vista.'), findsOneWidget);

    await tester.tap(find.text('Usuarios'));
    await tester.pumpAndSettle();
    expect(find.text('Gestión de usuarios'), findsOneWidget);

    // Alta de usuario (RF-19).
    await tester.tap(find.text('Nuevo usuario'));
    await tester.pumpAndSettle();
    expect(find.text('Crea un usuario.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Pedro Quisbert');
    await tester.enterText(fields.at(1), '+591 700-11223');
    await tester.enterText(fields.at(2), 'pharmalab123');

    await tester.scrollUntilVisible(
      find.text('Repartidor'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(AdminUserFormScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repartidor'));
    await tester.pumpAndSettle();

    // El correo se genera con la convención institucional.
    expect(find.text('pedroq@rep.pharma.com'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Crear usuario'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(AdminUserFormScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear usuario'));
    await tester.pumpAndSettle();

    expect(
      PharmaService.instance.users.any(
        (user) => user.email == 'pedroq@rep.pharma.com',
      ),
      isTrue,
    );

    // Buscar la cuenta recién creada para verla en el listado.
    await tester.enterText(find.byType(TextField).last, 'Pedro');
    await tester.pumpAndSettle();
    expect(find.text('Pedro Quisbert'), findsOneWidget);

    // Edición y desactivación (RF-19).
    await tester.tap(find.text('Pedro Quisbert'));
    await tester.pumpAndSettle();
    expect(find.text('Editar usuario'), findsOneWidget);

    // Esperar a que se oculte el aviso de "Usuario creado" para que no tape
    // los botones del formulario.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cuenta activa'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(AdminUserFormScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta activa'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Guardar cambios'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(AdminUserFormScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Pedro Quisbert'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
  });
}
