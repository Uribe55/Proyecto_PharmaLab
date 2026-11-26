import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../domain/commercial_number.dart';
import '../../models/order.dart';
import '../../models/order_lifecycle.dart';

class FirestoreOrderMapper {
  static DateTime date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    throw const FormatException('Fecha de pedido no válida.');
  }

  static OrderStatus status(dynamic value) => switch (value) {
    'pendiente' || 'Pendiente' => OrderStatus.pendiente,
    'aprobado' || 'Aprobado' => OrderStatus.aprobado,
    'enRuta' || 'en_ruta' || 'En ruta' => OrderStatus.enRuta,
    'entregado' || 'Entregado' => OrderStatus.entregado,
    'fallida' || 'Fallida' => OrderStatus.fallida,
    'cancelado' || 'Cancelado' => OrderStatus.cancelado,
    _ => throw const FormatException('Estado de pedido desconocido.'),
  };

  static PharmacyOrder fromMaps({
    required String documentId,
    required String ownerUid,
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> details,
    required Map<String, Map<String, dynamic>> history,
    bool fromCache = false,
  }) {
    final delivery = Map<String, dynamic>.from(data['entrega'] as Map? ?? {});
    final number = CommercialNumber.orderLabel(
      data['numero_comercial'],
      documentId,
    );
    final order = PharmacyOrder(
      number: number,
      documentId: documentId,
      operationId: data['id_operacion'] as String?,
      addressId: data['id_direccion'] as String?,
      createdAt: date(data['fecha_pedido']),
      status: status(data['estado']),
      recordedTotal: (data['total'] as num).toDouble(),
      remote: true,
      fromCache: fromCache,
      customerId: ownerUid,
      pharmacyName:
          data['nombre_farmacia'] as String? ?? data['id_cliente'] as String,
      address:
          delivery['direccion'] as String? ??
          'Dirección histórica no disponible',
      contactName: data['responsable'] as String? ?? '',
      contactPhone: data['telefono'] as String? ?? '',
      notes: data['observaciones'] as String? ?? '',
      items: [
        for (final line in details)
          OrderLine(
            productId: line['id_producto'] as String,
            name: line['nombre'] as String? ?? line['id_producto'] as String,
            brand: line['marca'] as String? ?? '',
            presentation: line['presentacion'] as String? ?? '',
            saleUnit: line['unidad_medida'] as String? ?? '',
            unitPrice: (line['precio_unitario'] as num).toDouble(),
            quantity: (line['cantidad'] as num).toInt(),
          ),
      ],
    );
    for (final line in details) {
      if (line['id_lote'] is String) {
        order.lotAllocations.add(
          LotStockAllocation(
            productId: line['id_producto'] as String,
            batchId: line['id_lote'] as String,
            quantity: (line['cantidad'] as num).toInt(),
          ),
        );
      }
      for (final raw in line['asignaciones_lotes'] as List? ?? []) {
        final allocation = Map<String, dynamic>.from(raw as Map);
        order.lotAllocations.add(
          LotStockAllocation(
            productId: line['id_producto'] as String,
            batchId: allocation['id_lote'] as String,
            quantity: (allocation['cantidad'] as num).toInt(),
          ),
        );
      }
    }
    for (final entry in history.entries) {
      final event = entry.value;
      final after = status(event['estado'] ?? event['estado_nuevo']);
      order.history.add(
        OrderHistoryEvent(
          id: entry.key,
          orderNumber: number,
          before: event['estado_anterior'] == null
              ? after
              : status(event['estado_anterior']),
          after: after,
          operation: event['operacion'] as String? ?? 'estado',
          at: date(event['fecha'] ?? event['fecha_cambio']),
          actorId:
              event['usuario_id'] as String? ??
              event['id_usuario'] as String? ??
              '',
          role: _role(event['rol']),
          note:
              event['nota'] as String? ??
              event['observaciones'] as String? ??
              '',
        ),
      );
    }
    order.history.sort((a, b) => a.at.compareTo(b.at));
    return order;
  }

  static UserRole? _role(dynamic value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}
