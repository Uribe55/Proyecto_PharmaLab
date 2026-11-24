import 'package:flutter/material.dart';

import 'main.dart' show PharmaLabApp;
import 'services/firebase_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const host = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  await FirebaseEnvironment.initializeEmulators(host);
  runApp(const PharmaLabApp());
}
