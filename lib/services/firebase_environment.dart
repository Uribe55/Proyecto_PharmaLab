import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Solo el arranque explícito de emuladores puede habilitar confirmaciones.
class FirebaseEnvironment {
  static bool _emulatorsConfigured = false;
  static FirebaseApp? _emulatorApp;
  static String? emulatorHost;
  static bool get emulatorOrdersEnabled => _emulatorsConfigured;
  static FirebaseFirestore get firestore => _emulatorApp == null
      ? FirebaseFirestore.instance
      : FirebaseFirestore.instanceFor(app: _emulatorApp!);
  static FirebaseAuth get auth => _emulatorApp == null
      ? FirebaseAuth.instance
      : FirebaseAuth.instanceFor(app: _emulatorApp!);
  static FirebaseFunctions get functions => _emulatorApp == null
      ? FirebaseFunctions.instance
      : FirebaseFunctions.instanceFor(app: _emulatorApp!);

  static Future<void> initializeEmulators(String host) async {
    if (Firebase.apps.isNotEmpty) {
      throw StateError('Firebase ya fue inicializado.');
    }
    emulatorHost = host;
    _emulatorApp = await Firebase.initializeApp(
      name: 'pharmalab-emulator',
      options: const FirebaseOptions(
        apiKey: 'demo-pharmalab-key',
        appId: '1:123456789:android:demo',
        messagingSenderId: '123456789',
        projectId: 'demo-pharmalab',
      ),
    );
    firestore.useFirestoreEmulator(host, 8080);
    await auth.useAuthEmulator(host, 9099);
    functions.useFunctionsEmulator(host, 5001);
    _emulatorsConfigured = true;
  }
}
