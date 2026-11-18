/// Estados del pedido definidos en el RF-15.
enum OrderStatus {
  pendiente('Pendiente', 'Pedido recibido'),
  aprobado('Aprobado', 'Disponibilidad verificada'),
  enRuta('En ruta', 'Asignado a un repartidor'),
  entregado('Entregado', 'Recibido por la farmacia');

  const OrderStatus(this.label, this.description);

  final String label;
  final String description;

  bool get isDelivered => this == OrderStatus.entregado;
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
  const PharmacyOrder({
    required this.number,
    required this.createdAt,
    required this.status,
    required this.items,
    required this.pharmacyName,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    this.notes = '',
  });

  final String number;
  final DateTime createdAt;
  final OrderStatus status;
  final List<OrderLine> items;
  final String pharmacyName;
  final String address;
  final String contactName;
  final String contactPhone;
  final String notes;

  int get totalUnits => items.fold(0, (sum, item) => sum + item.quantity);

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  int get statusIndex => OrderStatus.values.indexOf(status);
}
