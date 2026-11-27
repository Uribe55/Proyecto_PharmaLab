import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../domain/commercial_number.dart';
import '../../models/order.dart';
import '../../models/order_lifecycle.dart';

class FirestoreOrderMapper {
  static DateTime date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value).toLocal();
    throw const FormatException('Fecha de pedido no válida.');
  }

  static OrderStatus status(dynamic value) => switch (value) {
    'pendiente' || 'Pendiente' => OrderStatus.pendiente,
    'aprobado' || 'Aprobado' => OrderStatus.aprobado,
    'enRuta' || 'en_ruta' || 'En ruta' => OrderStatus.enRuta,
    'entregado' || 'Entregado' => OrderStatus.entregado,
    'fallida' || 'Fallida' || 'Entrega fallida' => OrderStatus.fallida,
    'reprogramado' || 'Reprogramado' => OrderStatus.reprogramado,
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
    Map<String, dynamic>? deliveryData,
  }) {
    final delivery = Map<String, dynamic>.from(data['entrega'] as Map? ?? {});
    final number = CommercialNumber.orderLabel(
      data['numero_comercial'],
      documentId,
    );
    final rawDate = data['fecha_pedido'];
    final created = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is String
        ? DateTime.tryParse(rawDate)?.toLocal()
        : null;
    final order = PharmacyOrder(
      number: number,
      schemaVersion: data['schema_version'] as String? ?? '',
      documentId: documentId,
      operationId: data['id_operacion'] as String?,
      addressId: data['id_direccion'] as String?,
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      createdAtKnown: created != null,
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
            presentationId: line['id_presentacion'] as String?,
            inventoryFactor: (line['factor_inventario'] as num?)?.toInt() ?? 1,
            inventoryQuantity: (line['cantidad_inventario'] as num?)?.toInt(),
            recordedSubtotal: (line['subtotal'] as num?)?.toDouble(),
          ),
      ],
    );
    order.deliveryId = data['id_entrega'] as String?;
    order.pharmacyId = data['id_cliente'] as String?;
    DateTime? optionalDate(dynamic value) => value is Timestamp
        ? value.toDate()
        : value is String
        ? DateTime.tryParse(value)?.toLocal()
        : value is DateTime
        ? value
        : null;
    order.approvedAt = optionalDate(data['fecha_aprobacion']);
    order.assignedAt = optionalDate(
      data['fecha_asignacion'] ?? deliveryData?['fecha_creacion'],
    );
    order.dispatchedAt = optionalDate(data['fecha_despacho']);
    order.cancelledAt = optionalDate(data['fecha_cancelacion']);
    order.cancellationReason = data['motivo_cancelacion'] as String?;
    order.deliveryReference = delivery['referencia'] as String? ?? '';
    order.deliveryState = deliveryData?['estado'] as String?;
    order.driverId = deliveryData?['id_repartidor'] as String?;
    order.driverName =
        (deliveryData?['repartidor_nombre'] ?? data['repartidor_nombre'])
            as String?;
    order.scheduledFor = optionalDate(deliveryData?['fecha_programada']);
    order.failureReason = deliveryData?['motivo'] as String?;
    order.failureNote = deliveryData?['observacion'] as String?;
    if (order.status == OrderStatus.entregado) {
      order.deliveredAt = optionalDate(
        data['fecha_logistica'] ?? deliveryData?['fecha_estado'],
      );
    }
    order.stockRestored = data['stock_restituido'] == true;
    final request = data['solicitud_cancelacion'];
    if (request is Map && request['estado'] == 'pendiente') {
      order.cancellationRequests.add(
        CancellationRequest(
          id: 'remota',
          requestedBy: request['usuario_id'] as String,
          reason: request['motivo'] as String,
          requestedAt: date(request['fecha']),
        ),
      );
    }
    if (data['fecha_logistica'] != null) {
      final at = optionalDate(data['fecha_logistica']);
      if (order.status == OrderStatus.entregado) order.deliveredAt = at;
      if (order.status == OrderStatus.fallida) order.failedAt = at;
      if (order.status == OrderStatus.enRuta) order.dispatchedAt = at;
    }
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
      OrderStatus after, before;
      try {
        after = status(event['estado'] ?? event['estado_nuevo']);
        before = event['estado_anterior'] == null
            ? after
            : status(event['estado_anterior']);
      } on FormatException {
        continue;
      }
      final eventDate = optionalDate(event['fecha'] ?? event['fecha_cambio']);
      order.history.add(
        OrderHistoryEvent(
          id: entry.key,
          orderNumber: number,
          before: before,
          after: after,
          operation: event['operacion'] as String? ?? 'estado',
          at: eventDate ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          atKnown: eventDate != null,
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
