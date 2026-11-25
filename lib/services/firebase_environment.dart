import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Selección de servicios: Firebase real por defecto o emulador explícito.
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

  static Future<void> initializeEmulators(String host) async {
    if (Firebase.apps.isNotEmpty) {
      throw StateError('Firebase ya fue inicializado.');
    }
    emulatorHost = host;
    _emulatorApp = await Firebase.initializeApp(
      name: 'pharmalab-emulator',
      // El SDK genera las opciones demo con el formato que exige Android.
      demoProjectId: 'demo-pharmalab',
    );
    // El host ya es explícito: 127.0.0.1 para adb reverse en teléfono físico,
    // 10.0.2.2 para Android Emulator. Evitar que el SDK lo reescriba.
    firestore.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    _emulatorsConfigured = true;
  }
}
