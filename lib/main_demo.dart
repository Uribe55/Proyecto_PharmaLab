import 'package:flutter/material.dart';

import 'main.dart' show PharmaLabApp;

/// Arranque explícito de demostración local. No inicializa Firebase ni es
/// una recuperación automática ante errores de autenticación.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PharmaLabApp());
}
