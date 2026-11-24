import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/screens/login_screen.dart';

void main() {
  testWidgets(
    'El login admite la altura cero transitoria del arranque Android',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Align(child: SizedBox(height: 0, child: LoginScreen()))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
