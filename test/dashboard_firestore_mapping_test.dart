import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto_final_movil/services/dashboard_repository.dart';
import 'package:proyecto_final_movil/models/dashboard_metrics.dart';
import 'package:proyecto_final_movil/models/dashboard_models.dart';

void main() {
  final repository = DashboardRepository();
  test('Spark conserva una sola línea y la fecha de pedido prioritaria', () {
    final order = repository.mapOrder('random', {
      'schema_version': 'spark_single_v2',
      'numero_comercial': 'PED002',
      'estado': 'entregado',
      'total': 25.5,
      'fecha_pedido': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 3, 59)),
      'creado_en': Timestamp.fromDate(DateTime.utc(2026, 4, 2)),
      'fecha_logistica': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 4)),
      'linea': {
        'id_producto': 'P1',
        'producto_nombre': 'Producto',
        'cantidad': 3,
        'precio_unitario': '8.50',
      },
      'items': [
        {'cantidad': 3, 'precio_unitario': 8.5},
      ],
    });
    expect(order.items.length, 1);
    expect(order.total, 25.5);
    expect(order.createdAt, DateTime(2026, 3, 31, 23, 59));
    expect(order.deliveredAt, DateTime(2026, 4, 1));
    final metrics = DashboardMetrics.compute(
      orders: [order],
      inventory: const DashboardInventory.loading(),
      period: DateRange.ofMonth(DateTime(2026, 4, 1)),
      now: DateTime(2026, 4, 1, 12),
    );
    expect(metrics.totalInPeriod, 0);
    expect(metrics.salesToday, 25.5);
    expect(metrics.salesMonth, 25.5);
    expect(metrics.salesQuarter, 25.5);
    expect(metrics.averageTicket, 25.5);
    expect(metrics.topProducts.single.units, 3);
  });
  test('histórico conserva importe sin inventar fecha efectiva de entrega', () {
    final order = repository.mapOrder('PED001', {
      'estado': 'Entregado',
      'total': 100,
      'fecha_pedido': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      'actualizado_en': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
    });
    expect(order.number, 'PED001');
    expect(order.total, 100);
    expect(order.deliveredAt, isNull);
  });
}
