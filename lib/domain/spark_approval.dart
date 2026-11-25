/// Contrato reducido de la transacción. Permite comprobar el protocolo sin
/// ejecutar escrituras comerciales en producción.
abstract interface class ApprovalTransaction {
  Future<Map<String, dynamic>?> read(String path);
  void update(String path, Map<String, dynamic> values);
  void create(String path, Map<String, dynamic> values);
}

class SparkApproval {
  static const enabled = false;
  static const blockedReason =
      'Aprobación real bloqueada: falta verificar las reglas de la transacción en un entorno aislado.';

  static Future<void> prepare(
    ApprovalTransaction tx, {
    required String uid,
    required String orderId,
    required Object serverTimestamp,
  }) async {
    if (uid.isEmpty ||
        orderId.isEmpty ||
        uid.contains('/') ||
        orderId.contains('/')) {
      throw StateError('Identificador no válido.');
    }
    final orderPath = 'pedidos/$orderId';
    final eventPath = '$orderPath/historial_estado/APROBACION';
    // Todas las lecturas preceden a cualquier escritura, también al reintentar.
    final user = await tx.read('usuarios/$uid');
    final order = await tx.read(orderPath);
    final event = await tx.read(eventPath);
    if (user?['estado'] != true ||
        !['vendedor', 'administrador'].contains(user?['rol'])) {
      throw StateError('Solo el personal autorizado puede aprobar.');
    }
    if (order?['estado'] != 'pendiente' || event != null) {
      throw StateError('El pedido ya no está pendiente o ya fue aprobado.');
    }
    tx.update(orderPath, {
      'estado': 'aprobado',
      'aprobado_por': uid,
      'fecha_aprobacion': serverTimestamp,
    });
    tx.create(eventPath, {
      'estado_anterior': 'pendiente',
      'estado_nuevo': 'aprobado',
      'fecha_cambio': serverTimestamp,
      'id_usuario': uid,
    });
  }
}
