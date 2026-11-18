import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/main.dart';

void main() {
  testWidgets('La pantalla de inicio de sesión se muestra', (tester) async {
    await tester.pumpWidget(const PharmaLabApp());
    await tester.pump();

    expect(find.text('Bienvenido de nuevo.'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrar cliente'), findsOneWidget);
  });
}
