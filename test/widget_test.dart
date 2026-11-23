
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';
import 'package:proyecto_final_movil/screens/register_screen.dart';
import 'package:proyecto_final_movil/widgets/app_text_field.dart';

void main() {
  testWidgets(
    'La pantalla de inicio de sesión se muestra',
    (tester) async {
      await tester.pumpWidget(const PharmaLabApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Bienvenido de nuevo.'),
        findsOneWidget,
      );

      expect(
        find.text('Iniciar sesión'),
        findsOneWidget,
      );

      expect(
        find.text('Registrar cliente'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'El enlace de registro abre el formulario de farmacia',
    (tester) async {
      await tester.pumpWidget(const PharmaLabApp());
      await tester.pumpAndSettle();

      // Localizar el botón de registro.
      final registroButton = find.text('Registrar cliente');

      // Desplazarse hasta el botón.
      await tester.ensureVisible(registroButton);
      await tester.pumpAndSettle();

      // Pulsar el botón.
      await tester.tap(registroButton);
      await tester.pumpAndSettle();

      // Comprobar que se abrió RegisterScreen.
      expect(
        find.byType(RegisterScreen),
        findsOneWidget,
      );

      // Comprobar el título del formulario.
      expect(
        find.text('REGISTRO DE CLIENTE'),
        findsOneWidget,
      );

      // Comprobar que existe el campo Nombre comercial.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppTextField &&
              widget.label == 'Nombre comercial',
        ),
        findsOneWidget,
      );
    },
  );
}
