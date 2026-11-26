import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/spark_checkout.dart';
import '../../domain/spark_approval.dart';
import '../repositories/remote_order_repository.dart';
import 'checkout_diagnostics.dart';
import 'numbered_transaction.dart';

class FirestoreSparkCheckout {
  FirestoreSparkCheckout(this.db);
  final FirebaseFirestore db;

  Future<void> confirm({
    required String uid,
    required String farmId,
    required Map<String, dynamic> request,
    required bool Function() sessionValid,
  }) async {
    final diagnostics = CheckoutDiagnostics(
      uid: uid,
      farmId: farmId,
      orderId: request['operationId'] as String,
      projectId: db.app.options.projectId,
    );
    diagnostics.mark('confirmacion.inicio');
    try {
      final item = SparkCheckout.item(request);
      // Las consultas no están disponibles en Transaction de Flutter. Solo
      // elegimos un candidato aquí; todos sus valores se releen en la transacción.
      diagnostics.mark(
        'catalogo.producto',
        document: 'productos/${item['productId']}',
      );
      final product = await db
          .collection('productos')
          .doc(item['productId'] as String)
          .get(const GetOptions(source: Source.server));
      diagnostics.mark('catalogo.lotes', document: 'lotes_productos');
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
      await numberedTransaction(db, 'configuracion/contadores_pedidos', (
        transaction,
      ) async {
        if (!sessionValid()) throw StateError('La sesión cambió.');
        await SparkCheckout.prepare(
          SparkTransactionAdapter(db, transaction, diagnostics: diagnostics),
          uid: uid,
          farmId: farmId,
          lotId: eligible.first.id,
          request: request,
          serverTimestamp: FieldValue.serverTimestamp(),
          now: DateTime.now(),
        );
        if (!sessionValid()) throw StateError('La sesión cambió.');
        // El SDK valida el commit después de salir del callback. Un rechazo en
        // esta etapa afecta al conjunto, no necesariamente a la última escritura.
        diagnostics.mark('transaccion.commit');
      }, diagnostics: diagnostics);
      diagnostics.mark(
        'transaccion.confirmada',
        document: 'pedidos/${request['operationId']}',
        exists: true,
      );
    } on FirebaseException catch (error) {
      diagnostics.failure(error);
      throw RemoteOrderException(
        error.code == 'permission-denied'
            ? 'Firestore rechazó la confirmación. Revisa los permisos de tu cuenta y que las reglas publicadas correspondan a esta versión.'
            : 'No se pudo verificar la confirmación. Consulta la misma operación antes de reintentar.',
        definitive:
            error.code == 'permission-denied' ||
            error.code == 'unauthenticated',
      );
    }
  }
}

class SparkTransactionAdapter implements ApprovalTransaction {
  SparkTransactionAdapter(this.db, this.transaction, {this.diagnostics});
  final FirebaseFirestore db;
  final Transaction transaction;
  final CheckoutDiagnostics? diagnostics;
  @override
  Future<Map<String, dynamic>?> read(String path) async {
    diagnostics?.mark('transaccion.lectura', document: path);
    final snapshot = await transaction.get(db.doc(path));
    diagnostics?.mark(
      'transaccion.leida',
      document: path,
      exists: snapshot.exists,
    );
    final data = snapshot.data();
    return data?.map(
      (key, value) =>
          MapEntry(key, value is Timestamp ? value.toDate() : value),
    );
  }

  @override
  void update(String path, Map<String, dynamic> values) {
    diagnostics?.mark('transaccion.encolar_actualizacion', document: path);
    transaction.update(db.doc(path), values);
  }

  @override
  void create(String path, Map<String, dynamic> values) {
    diagnostics?.mark('transaccion.encolar_creacion', document: path);
    transaction.set(db.doc(path), values);
  }
}
