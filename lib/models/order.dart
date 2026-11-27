import 'order_lifecycle.dart';

/// Estados originales más cancelado, ampliación propuesta RF-21.
enum OrderStatus {
  pendiente('Pendiente', 'Pedido recibido'),
  aprobado('Aprobado', 'Disponibilidad verificada'),
  enRuta('En ruta', 'Transporte iniciado'),
  entregado('Entregado', 'Recibido por la farmacia'),
  fallida('Entrega fallida', 'Intento fallido; pendiente de coordinación'),
  reprogramado('Reprogramado', 'El vendedor asignará una nueva fecha'),
  cancelado('Cancelado', 'Pedido cancelado antes del despacho');

  const OrderStatus(this.label, this.description);

  final String label;
  final String description;

  /// Pasos que ve la farmacia cliente en el seguimiento (RF-15).
  static const List<OrderStatus> deliverySteps = [
    pendiente,
    aprobado,
    enRuta,
    entregado,
  ];

  bool get isDelivered => this == OrderStatus.entregado;

  bool get isFailure => this == OrderStatus.fallida;

  /// Una entrega fallida ya no cierra el pedido: queda reprogramada para que
  /// el vendedor asigne una nueva fecha (RF-17).
  bool get isRescheduled => this == OrderStatus.reprogramado;

  bool get isFinal =>
      this == OrderStatus.entregado || this == OrderStatus.cancelado;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.brand,
    required this.presentation,
    required this.unitPrice,
    required this.quantity,
    this.saleUnit = '',
    this.presentationId,
    this.inventoryFactor = 1,
    this.inventoryQuantity,
    this.recordedSubtotal,
  });

  final String productId;
  final String name;
  final String brand;
  final String presentation;
  final double unitPrice;
  final int quantity;
  final String saleUnit;
  final String? presentationId;
  final int inventoryFactor;
  final int? inventoryQuantity;
  final double? recordedSubtotal;

  double get subtotal => recordedSubtotal ?? unitPrice * quantity;
}

class PharmacyOrder {
  PharmacyOrder({
    required this.number,
    required this.createdAt,
    required this.status,
    required this.items,
    required this.pharmacyName,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    this.notes = '',
    this.driverId,
    this.driverName,
    this.deliveredAt,
    this.failureReason,
    this.failureNote,
    this.scheduledFor,
    this.customerId,
    this.remote = false,
    this.failedAt,
    this.documentId,
    this.operationId,
    this.addressId,
    this.recordedTotal,
    this.fromCache = false,
    this.createdAtKnown = true,
    this.schemaVersion = '',
  }) {
    // Migración lógica: conserva el fallo histórico sin atribuirle una entrega.
    if (status == OrderStatus.enRuta ||
        status.isFailure ||
        status.isRescheduled) {
      hasBeenDispatched = true;
      if (status.isFailure || status.isRescheduled) {
        failedAt ??= deliveredAt;
        deliveredAt = null;
      }
      attempts.add(
        DeliveryAttempt(
          id: '$number-legacy-1',
          orderNumber: number,
          number: 1,
          driverId: driverId ?? '',
          closedAt: status.isFailure || status.isRescheduled ? failedAt : null,
          result: status.isFailure || status.isRescheduled
              ? AttemptResult.failed
              : AttemptResult.inProgress,
          reason: failureReason,
          note: failureNote ?? '',
        ),
      );
    }
  }

  final String number;
  final String schemaVersion;
  final String? documentId, operationId, addressId;
  final double? recordedTotal;
  final bool fromCache;
  final DateTime createdAt;
  final bool createdAtKnown;
  final List<OrderLine> items;
  final String pharmacyName;
  final String address;
  final String contactName;
  final String contactPhone;
  final String notes;
  final String? customerId;
  final bool remote;
  DateTime? assignedAt, dispatchedAt, failedAt, cancelledAt, rescheduledFor;
  DateTime? approvedAt;
  String? deliveryState;
  String deliveryReference = '';
  String? pharmacyId;
  String? assignedBy, dispatchedBy, cancelledBy, cancellationReason;
  bool hasBeenDispatched = false;
  bool stockRestored = false;
  final Map<String, int> localStockDebits = {};
  final List<LotStockAllocation> lotAllocations = [];
  final List<CancellationRequest> cancellationRequests = [];
  final List<DeliveryAttempt> attempts = [];
  final List<DeliveryIncident> incidents = [];
  final List<OrderHistoryEvent> history = [];
  final Set<String> appliedEventIds = {};
  CancellationRequest? get pendingCancellation {
    for (final request in cancellationRequests.reversed) {
      if (request.status == CancellationStatus.pending) return request;
    }
    return null;
  }

  DeliveryAttempt? get currentAttempt =>
      attempts.isEmpty ? null : attempts.last;

  /// El estado y los datos de entrega cambian durante el flujo operativo
  /// (RF-11, RF-12, RF-14 y RF-17).
  OrderStatus status;
  String? driverId;
  String? deliveryId;
  String? driverName;
  DateTime? deliveredAt;
  String? failureReason;
  String? failureNote;

  /// Nueva fecha acordada por el vendedor después de una entrega fallida
  /// (RF-17). El pedido vuelve a "Aprobado" para asignar al repartidor.
  DateTime? scheduledFor;

  int get totalUnits => items.fold(0, (sum, item) => sum + item.quantity);

  double get total =>
      recordedTotal ?? items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Posición dentro de los cuatro pasos del seguimiento. Una entrega fallida
  /// se detiene en el paso "En ruta".
  int get statusIndex {
    if (status == OrderStatus.cancelado) return -1;
    if (status.isFailure || status.isRescheduled) {
      return OrderStatus.deliverySteps.indexOf(OrderStatus.enRuta);
    }
    return OrderStatus.deliverySteps.indexOf(status);
  }

  bool get isPending => status == OrderStatus.pendiente;

  bool get isApproved => status == OrderStatus.aprobado;

  bool get isInTransit => status == OrderStatus.enRuta;

  bool get isRescheduled => status.isRescheduled;

  bool get canAssignDriver => status == OrderStatus.aprobado;

  bool get canDeliver => status == OrderStatus.enRuta;

  /// Un pedido reprogramado debe volver al panel del vendedor para fijar una
  /// nueva fecha antes de asignar repartidor.
  bool get needsReschedule => status.isRescheduled || status.isFailure;
}
