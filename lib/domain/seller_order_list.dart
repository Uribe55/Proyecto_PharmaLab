import '../models/order.dart';

/// Los pendientes más antiguos primero; fechas desconocidas al final del grupo.
List<PharmacyOrder> sellerOrderList(
  Iterable<PharmacyOrder> source, {
  OrderStatus? status,
}) {
  final indexed = source
      .where((o) => status == null || o.status == status)
      .toList()
      .asMap()
      .entries
      .toList();
  indexed.sort((a, b) {
    final x = a.value, y = b.value;
    if (status == null && x.isPending != y.isPending) {
      return x.isPending ? -1 : 1;
    }
    if (x.createdAtKnown != y.createdAtKnown) return x.createdAtKnown ? -1 : 1;
    if (!x.createdAtKnown) return a.key.compareTo(b.key);
    final oldestFirst =
        status == OrderStatus.pendiente || (status == null && x.isPending);
    final comparison = oldestFirst
        ? x.createdAt.compareTo(y.createdAt)
        : y.createdAt.compareTo(x.createdAt);
    return comparison == 0 ? a.key.compareTo(b.key) : comparison;
  });
  return indexed.map((entry) => entry.value).toList();
}

String orderFilterLabel(OrderStatus? status) => switch (status) {
  null => 'Todos',
  OrderStatus.pendiente => 'Pendientes',
  OrderStatus.aprobado => 'Aprobados',
  OrderStatus.enRuta => 'En ruta',
  OrderStatus.entregado => 'Entregados',
  OrderStatus.fallida => 'Entregas fallidas',
  OrderStatus.reprogramado => 'Reprogramados',
  OrderStatus.cancelado => 'Cancelados',
};
