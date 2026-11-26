import 'commercial_number.dart';
import 'spark_approval.dart';

class SparkAddress {
  static Future<void> prepare(
    ApprovalTransaction tx, {
    required String uid,
    required String farmId,
    required String documentId,
    required String name,
    required String address,
    required String reference,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(documentId) ||
        uid.isEmpty ||
        uid.contains('/') ||
        farmId.contains('/') ||
        name.trim().isEmpty ||
        name.trim().length > 80 ||
        address.trim().isEmpty ||
        address.trim().length > 300 ||
        reference.trim().length > 300) {
      throw StateError('Revisa los datos de la dirección.');
    }
    final user = await tx.read('usuarios/$uid');
    final farm = await tx.read('farmacia_cliente/$farmId');
    final counter = await tx.read('configuracion/contadores_direcciones');
    final existing = await tx.read('direcciones/$documentId');
    if (user?['rol'] != 'cliente' ||
        user?['estado'] != true ||
        farm?['usuario_id'] != uid ||
        farm?['estado'] != true) {
      throw StateError('Farmacia no autorizada.');
    }
    // Reintento del SDK o resultado perdido: conserva documento y número.
    if (existing != null) {
      if (existing['id_cliente'] == farmId &&
          existing['nombre'] == name.trim() &&
          existing['direccion'] == address.trim() &&
          existing['referencia'] == reference.trim()) {
        return;
      }
      throw StateError('La dirección ya existe con otros datos.');
    }
    final number = CommercialNumber.next(counter, 'DIR');
    tx.create('direcciones/$documentId', {
      'id_cliente': farmId,
      'nombre': name.trim(),
      'direccion': address.trim(),
      'referencia': reference.trim(),
      'latitud': null,
      'longitud': null,
      'estado': true,
      'numero_comercial': CommercialNumber.code('DIR', number),
    });
    tx.update(
      'configuracion/contadores_direcciones',
      CommercialNumber.counter('DIR', number, documentId),
    );
  }
}
