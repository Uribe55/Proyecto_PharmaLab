import 'order_lifecycle.dart';

/// Estados originales más cancelado, ampliación propuesta RF-21.
enum OrderStatus {
  pendiente('Pendiente', 'Pedido recibido'),
  aprobado('Aprobado', 'Disponibilidad verificada'),
  enRuta('En ruta', 'Transporte iniciado'),
  entregado('Entregado', 'Recibido por la farmacia'),
  fallida('Entrega fallida', 'Intento fallido; pendiente de coordinación'),
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
  });

  final String productId;
  final String name;
  final String brand;
  final String presentation;
  final double unitPrice;
  final int quantity;
  final String saleUnit;

  double get subtotal => unitPrice * quantity;
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
    this.customerId,
    this.remote = false,
    this.failedAt,
    this.documentId,
    this.operationId,
    this.addressId,
    this.recordedTotal,
    this.fromCache = false,
  }) {
    // Migración lógica: conserva el fallo histórico sin atribuirle una entrega.
    if (status == OrderStatus.enRuta || status == OrderStatus.fallida) {
      hasBeenDispatched = true;
      if (status == OrderStatus.fallida) {
        failedAt ??= deliveredAt;
        deliveredAt = null;
      }
      attempts.add(
        DeliveryAttempt(
          id: '$number-legacy-1',
          orderNumber: number,
          number: 1,
          driverId: driverId ?? '',
          closedAt: status == OrderStatus.fallida ? failedAt : null,
          result: status == OrderStatus.fallida
              ? AttemptResult.failed
              : AttemptResult.inProgress,
          reason: failureReason,
          note: failureNote ?? '',
        ),
      );
    }
  }

  final String number;
  final String? documentId, operationId, addressId;
  final double? recordedTotal;
  final bool fromCache;
  final DateTime createdAt;
  final List<OrderLine> items;
  final String pharmacyName;
  final String address;
  final String contactName;
  final String contactPhone;
  final String notes;
  final String? customerId;
  final bool remote;
  DateTime? assignedAt, dispatchedAt, failedAt, cancelledAt, rescheduledFor;
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
  String? driverName;
  DateTime? deliveredAt;
  String? failureReason;
  String? failureNote;

  int get totalUnits => items.fold(0, (sum, item) => sum + item.quantity);

  double get total =>
      recordedTotal ?? items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Posición dentro de los cuatro pasos del seguimiento. Una entrega fallida
  /// se detiene en el paso "En ruta".
  int get statusIndex {
    if (status == OrderStatus.cancelado) return -1;
    if (status.isFailure) {
      return OrderStatus.deliverySteps.indexOf(OrderStatus.enRuta);
    }
    return OrderStatus.deliverySteps.indexOf(status);
  }

  bool get isPending => status == OrderStatus.pendiente;

  bool get isApproved => status == OrderStatus.aprobado;

  bool get isInTransit => status == OrderStatus.enRuta;

  bool get canAssignDriver => status == OrderStatus.aprobado;

  bool get canDeliver => status == OrderStatus.enRuta;
}
