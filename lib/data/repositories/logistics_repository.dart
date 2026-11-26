import '../../models/order.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryRecord {
  const DeliveryRecord(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get state {
    final raw = (data['estado'] ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    return switch (raw) {
      'enruta' => 'en_ruta',
      'entrega_fallida' => 'fallida',
      'pendiente' || 'aprobado' => 'asignada',
      _ => raw,
    };
  }

  bool get delivered => state == 'entregado';
  DateTime? get assignedAt =>
      readDate(data['fecha_creacion'] ?? data['fecha_asignacion']);
  DateTime? get completedAt =>
      readDate(data['fecha_entrega'] ?? data['fecha_estado']);
  static DateTime? readDate(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : value is String
      ? DateTime.tryParse(value)
      : null;
}

class LogisticsDriver {
  const LogisticsDriver(this.id, this.name);
  final String id, name;
}

abstract interface class LogisticsRepository {
  Stream<List<LogisticsDriver>> watchDrivers();
  Stream<List<DeliveryRecord>> watchDeliveries();
  Future<void> assign(PharmacyOrder order, String employeeId);
  Future<void> transition(
    DeliveryRecord delivery,
    String state, {
    String reason = '',
    String note = '',
  });
}

/// Historial exitoso, ordenado por fecha efectiva; registros sin fecha al final.
List<DeliveryRecord> deliveryList(
  Iterable<DeliveryRecord> source, {
  bool history = false,
  String? filter,
}) {
  final unique = {for (final record in source) record.id: record};
  final records = unique.values
      .where((d) => history ? d.delivered : filter == null || d.state == filter)
      .toList();
  records.sort((a, b) {
    final x = history ? a.completedAt : a.assignedAt;
    final y = history ? b.completedAt : b.assignedAt;
    if (x == null) return y == null ? 0 : 1;
    if (y == null) return -1;
    return y.compareTo(x);
  });
  return records;
}
