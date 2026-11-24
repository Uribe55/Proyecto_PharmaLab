/// Estados del pedido definidos en el RF-15 y el RF-17.
enum OrderStatus {
  pendiente('Pendiente', 'Pedido recibido'),
  aprobado('Aprobado', 'Disponibilidad verificada'),
  enRuta('En ruta', 'Asignado a un repartidor'),
  entregado('Entregado', 'Recibido por la farmacia'),
  fallida('Entrega fallida', 'No se pudo completar la entrega');

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

  int get totalUnits => items.fold(0, (sum, item) => sum + item.quantity);

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Posición dentro de los cuatro pasos del seguimiento. Una entrega fallida
  /// se detiene en el paso "En ruta".
  int get statusIndex {
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
