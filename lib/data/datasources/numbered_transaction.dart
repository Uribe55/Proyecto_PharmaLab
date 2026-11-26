import 'package:cloud_firestore/cloud_firestore.dart';

import 'checkout_diagnostics.dart';

/// Con reglas que verifican +1, una colisión también puede devolver
/// permission-denied antes de que el SDK la clasifique como aborted.
/// Solo reintenta si se demuestra que OTRO commit avanzó el contador.
Future<void> numberedTransaction(
  FirebaseFirestore db,
  String counterPath,
  Future<void> Function(Transaction) prepare, {
  CheckoutDiagnostics? diagnostics,
}) async {
  for (var attempt = 0; ; attempt++) {
    int? observed;
    try {
      await db.runTransaction((tx) async {
        diagnostics?.beginAttempt();
        diagnostics?.mark('numeracion.lectura', document: counterPath);
        final counter = await tx.get(db.doc(counterPath));
        diagnostics?.mark(
          'numeracion.leida',
          document: counterPath,
          exists: counter.exists,
        );
        final value = counter.data()?['ultimo_numero'];
        observed = value is int ? value : null;
        await prepare(tx);
      });
      return;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' ||
          attempt >= 2 ||
          observed == null) {
        rethrow;
      }
      diagnostics?.mark('numeracion.verificar_colision', document: counterPath);
      final current = await db
          .doc(counterPath)
          .get(const GetOptions(source: Source.server));
      final value = current.data()?['ultimo_numero'];
      if (value is! int || value <= observed!) rethrow;
      // Mismo ID interno, nuevo snapshot; nunca se reutiliza un número calculado.
    }
  }
}
