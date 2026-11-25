import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/spark_checkout.dart';
import '../../domain/spark_approval.dart';
import '../repositories/remote_order_repository.dart';

class FirestoreSparkCheckout {
  FirestoreSparkCheckout(this.db);
  final FirebaseFirestore db;

  Future<void> confirm({
    required String uid,
    required String farmId,
    required Map<String, dynamic> request,
    required bool Function() sessionValid,
  }) async {
    final item = SparkCheckout.item(request);
    // Las consultas no están disponibles en Transaction de Flutter. Solo
    // elegimos un candidato aquí; todos sus valores se releen en la transacción.
    final product = await db
        .collection('productos')
        .doc(item['productId'] as String)
        .get(const GetOptions(source: Source.server));
    final lots = await db
        .collection('lotes_productos')
        .where('producto_id', isEqualTo: item['productId'])
        .get(const GetOptions(source: Source.server));
    final needsExpiry = product.data()?['requiere_vencimiento'] == true;
    final now = DateTime.now();
    final eligible =
        lots.docs.where((doc) {
          final data = doc.data();
          final stock = data['cantidad_disponible'];
          final expiry = data['fecha_vencimiento'];
          return stock is int &&
              stock >= (item['quantity'] as int) &&
              (!needsExpiry ||
                  (expiry is Timestamp && expiry.toDate().isAfter(now)));
        }).toList()..sort((a, b) {
          final field = needsExpiry ? 'fecha_vencimiento' : 'fecha_ingreso';
          final first = a.data()[field], second = b.data()[field];
          final compare = first is Timestamp && second is Timestamp
              ? first.compareTo(second)
              : 0;
          return compare != 0 ? compare : a.id.compareTo(b.id);
        });
    if (eligible.isEmpty) {
      throw const RemoteOrderException(
        'Ningún lote vigente cubre todas las cajas solicitadas. Esta versión no combina lotes.',
        definitive: true,
      );
    }
    if (!sessionValid()) throw StateError('La sesión cambió.');
    try {
      await db.runTransaction((transaction) async {
        if (!sessionValid()) throw StateError('La sesión cambió.');
        await SparkCheckout.prepare(
          SparkTransactionAdapter(db, transaction),
          uid: uid,
          farmId: farmId,
          lotId: eligible.first.id,
          request: request,
          serverTimestamp: FieldValue.serverTimestamp(),
          now: DateTime.now(),
        );
        if (!sessionValid()) throw StateError('La sesión cambió.');
      });
    } on FirebaseException catch (error) {
      throw RemoteOrderException(
        error.code == 'permission-denied'
            ? 'Firestore rechazó la operación. Publica las reglas Spark verificadas y revisa los permisos de tu cuenta.'
            : 'No se pudo verificar la confirmación. Consulta la misma operación antes de reintentar.',
        definitive:
            error.code == 'permission-denied' ||
            error.code == 'unauthenticated',
      );
    }
  }
}

class SparkTransactionAdapter implements ApprovalTransaction {
  SparkTransactionAdapter(this.db, this.transaction);
  final FirebaseFirestore db;
  final Transaction transaction;
  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final data = (await transaction.get(db.doc(path))).data();
    return data?.map(
      (key, value) =>
          MapEntry(key, value is Timestamp ? value.toDate() : value),
    );
  }

  @override
  void update(String path, Map<String, dynamic> values) =>
      transaction.update(db.doc(path), values);
  @override
  void create(String path, Map<String, dynamic> values) =>
      transaction.set(db.doc(path), values);
}
