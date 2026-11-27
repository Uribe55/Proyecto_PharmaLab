import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_environment.dart';
import '../repositories/remote_order_repository.dart';

/// Frontera deliberada: nunca llama Functions en el proyecto de producción.
class EmulatorOrderGateway {
  Future<Map<String, dynamic>?> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (!FirebaseEnvironment.emulatorOrdersEnabled ||
        FirebaseEnvironment.firestore.app.options.projectId !=
            'demo-pharmalab') {
      throw StateError(
        'El backend múltiple requiere los emuladores explícitos.',
      );
    }
    final functions = FirebaseFunctions.instanceFor(
      app: FirebaseEnvironment.firestore.app,
      region: 'us-central1',
    );
    functions.useFunctionsEmulator(
      FirebaseEnvironment.emulatorHost!,
      5001,
      automaticHostMapping: false,
    );
    try {
      final response = await functions.httpsCallable(name).call<dynamic>(data);
      return response.data == null
          ? null
          : Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final prices = details is Map ? details['prices'] : null;
      throw RemoteOrderException(
        error.message ?? 'No se pudo verificar la operación. Conserva el mismo ID para reintentar.',
        definitive: [
          'invalid-argument',
          'permission-denied',
          'unauthenticated',
          'failed-precondition',
          'already-exists',
          'resource-exhausted',
        ].contains(error.code),
        prices: prices is Map
            ? prices.map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toInt()),
              )
            : const {},
      );
    }
  }
}
