/// Estados del pedido definidos en el RF-15 y el RF-17.
enum OrderStatus {
  pendiente('Pendiente', 'Pedido recibido'),
  aprobado('Aprobado', 'Disponibilidad verificada'),
  enRuta('En ruta', 'Asignado a un repartidor'),
  entregado('Entregado', 'Recibido por la farmacia'),
  fallida('Entrega fallida', 'No se pudo completar la entrega'),
  reprogramado('Reprogramado', 'El vendedor asignará una nueva fecha');

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
      this == OrderStatus.entregado || this == OrderStatus.fallida;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.brand,
    required this.presentation,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String name;
  final String brand;
  final String presentation;
  final double unitPrice;
  final int quantity;

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
    this.scheduledFor,
  });

  final String number;
  final DateTime createdAt;
  final List<OrderLine> items;
  final String pharmacyName;
  final String address;
  final String contactName;
  final String contactPhone;
  final String notes;

  /// El estado y los datos de entrega cambian durante el flujo operativo
  /// (RF-11, RF-12, RF-14 y RF-17).
  OrderStatus status;
  String? driverId;
  String? driverName;
  DateTime? deliveredAt;
  String? failureReason;
  String? failureNote;

  /// Nueva fecha acordada por el vendedor después de una entrega fallida
  /// (RF-17). El pedido vuelve a "Aprobado" para asignar al repartidor.
  DateTime? scheduledFor;

  int get totalUnits => items.fold(0, (sum, item) => sum + item.quantity);

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Posición dentro de los cuatro pasos del seguimiento. Una entrega fallida
  /// se detiene en el paso "En ruta".
  int get statusIndex {
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
