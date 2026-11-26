import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/models/dashboard_metrics.dart';
import 'package:proyecto_final_movil/models/dashboard_models.dart';
import 'package:proyecto_final_movil/models/order.dart';

DashboardOrder _order({
  required String id,
  required OrderStatus status,
  DateTime? createdAt,
  DateTime? deliveredAt,
  List<DashboardOrderLine> items = const [],
  double? declaredTotal,
  bool cancelled = false,
  String? driverId,
  String? driverName,
}) {
  return DashboardOrder(
    id: id,
    number: 'PED-$id',
    status: status,
    items: items,
    pharmacyName: 'Farmacia $id',
    createdAt: createdAt,
    deliveredAt: deliveredAt,
    declaredTotal: declaredTotal,
    cancelled: cancelled,
    driverId: driverId,
    driverName: driverName,
  );
}

DashboardOrderLine _line({
  required String name,
  required int quantity,
  required double price,
  String category = 'Genéricos',
}) {
  return DashboardOrderLine(
    productId: name,
    name: name,
    quantity: quantity,
    unitPrice: price,
    category: category,
  );
}

DashboardInventory _inventory({
  List<DashboardProductStock> products = const [],
  List<DashboardLot> lots = const [],
  bool hasLotData = false,
}) {
  return DashboardInventory(
    products: products,
    lots: lots,
    origin: InventoryOrigin.local,
    hasLotData: hasLotData,
  );
}

void main() {
  group('DateRange', () {
    final now = DateTime(2026, 6, 18, 15, 30);

    test('resuelve los períodos predefinidos', () {
      expect(
        DateRange.resolve(DashboardPeriod.hoy, now).start,
        DateTime(2026, 6, 18),
      );
      expect(
        DateRange.resolve(DashboardPeriod.sieteDias, now).start,
        DateTime(2026, 6, 12),
      );
      expect(
        DateRange.resolve(DashboardPeriod.mes, now).start,
        DateTime(2026, 6, 1),
      );
      expect(
        DateRange.resolve(DashboardPeriod.trimestre, now).start,
        DateTime(2026, 4, 1),
      );
      expect(
        DateRange.resolve(DashboardPeriod.anio, now).start,
        DateTime(2026, 1, 1),
      );
    });

    test('el rango anterior termina antes del rango actual', () {
      final month = DateRange.ofMonth(now);
      final previous = month.previous();
      expect(previous.end.isBefore(month.start), isTrue);
      expect(previous.contains(month.start), isFalse);
    });

    test('el rango personalizado se respeta', () {
      final custom = DateRange(
        start: DateTime(2026, 5, 3),
        end: DateTime(2026, 5, 9, 23, 59, 59, 999),
      );
      expect(
        DateRange.resolve(
          DashboardPeriod.personalizado,
          now,
          custom: custom,
        ).start,
        custom.start,
      );
      expect(custom.contains(DateTime(2026, 5, 9, 23, 59)), isTrue);
      expect(custom.contains(DateTime(2026, 5, 10)), isFalse);
    });
  });

  group('DashboardMetrics comerciales', () {
    final now = DateTime(2026, 6, 18, 18);
    final period = DateRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 18, 23, 59, 59, 999),
    );

    final orders = [
      _order(
        id: 'a',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 6, 10, 9),
        deliveredAt: DateTime(2026, 6, 12, 10),
        items: [_line(name: 'Paracetamol', quantity: 2, price: 10)],
      ),
      _order(
        id: 'b',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 6, 15, 10),
        deliveredAt: DateTime(2026, 6, 17, 11),
        items: [
          _line(
            name: 'Vitamina C',
            quantity: 1,
            price: 30,
            category: 'Vitaminas',
          ),
        ],
      ),
      _order(
        id: 'hoy',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 6, 18, 9),
        deliveredAt: DateTime(2026, 6, 18, 10),
        items: [_line(name: 'Ibuprofeno', quantity: 1, price: 10)],
      ),
      _order(
        id: 'sin-detalle',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 6, 14, 9),
        deliveredAt: DateTime(2026, 6, 14, 10),
        declaredTotal: 70,
      ),
      _order(
        id: 'pendiente',
        status: OrderStatus.pendiente,
        createdAt: DateTime(2026, 6, 18, 17, 30),
        items: [_line(name: 'No entregado', quantity: 1, price: 50)],
      ),
      _order(
        id: 'fallida',
        status: OrderStatus.fallida,
        createdAt: DateTime(2026, 6, 16, 9),
        deliveredAt: DateTime(2026, 6, 17, 9),
        items: [_line(name: 'Fallida', quantity: 1, price: 40)],
      ),
      _order(
        id: 'anulada',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 6, 13, 9),
        deliveredAt: DateTime(2026, 6, 14, 9),
        items: [_line(name: 'Anulada', quantity: 1, price: 99)],
        cancelled: true,
      ),
      _order(
        id: 'anterior',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 5, 30, 9),
        deliveredAt: DateTime(2026, 5, 31, 9),
        items: [_line(name: 'Mayo', quantity: 1, price: 5)],
      ),
    ];

    final metrics = DashboardMetrics.compute(
      orders: orders,
      inventory: _inventory(),
      period: period,
      now: now,
    );

    test('solo suma pedidos entregados del período', () {
      expect(metrics.deliveredInPeriod, 4);
      expect(metrics.deliveredValue, 130);
      expect(metrics.averageTicket, 32.5);
      expect(metrics.previousDeliveredValue, 5);
      expect(metrics.variationPercent, closeTo(2500, 0.001));
    });

    test('excluye pendientes, fallidas y anuladas del valor', () {
      expect(metrics.topProducts.any((p) => p.name == 'No entregado'), isFalse);
      expect(metrics.topProducts.any((p) => p.name == 'Fallida'), isFalse);
      expect(metrics.topProducts.any((p) => p.name == 'Anulada'), isFalse);
      expect(metrics.categories.any((c) => c.category == 'Genéricos'), isTrue);
    });

    test('cuenta estados del período y actividad de hoy', () {
      expect(metrics.statusCounts[OrderStatus.entregado], 4);
      expect(metrics.statusCounts[OrderStatus.pendiente], 1);
      expect(metrics.statusCounts[OrderStatus.fallida], 1);
      expect(metrics.deliveredToday, 1);
      expect(metrics.receivedToday, 2);
      expect(metrics.totalInPeriod, 6);
      expect(metrics.delivery.delivered, 4);
      expect(metrics.delivery.failed, 1);
      expect(metrics.delivery.successRate, closeTo(80, 0.001));
    });

    test('marca pedidos sin detalle sin inventar productos', () {
      expect(metrics.deliveredOrdersWithoutDetail, 1);
      expect(metrics.hasCommercialData, isTrue);
    });

    test('usa el total declarado si el detalle no trae precios', () {
      final sinPrecio = _order(
        id: 'sin-precio',
        status: OrderStatus.entregado,
        items: [_line(name: 'Producto sin precio', quantity: 2, price: 0)],
        declaredTotal: 25,
      );
      expect(sinPrecio.total, 25);
    });

    test('calcula ventas entregadas de hoy, mes y trimestre', () {
      // El trimestre (abril–junio) incluye la entrega de mayo de Bs 5.
      expect(metrics.salesToday, 10);
      expect(metrics.salesMonth, 130);
      expect(metrics.salesQuarter, 135);
    });

    test('suma el valor registrado del período sin anuladas', () {
      // a=20, b=30, hoy=10, sin-detalle=70, pendiente=50, fallida=40.
      // La anulada no se cuenta; la de mayo queda fuera del período.
      expect(metrics.registeredValueInPeriod, 220);
    });

    test('separa importes históricos por estado sin inventar cobros', () {
      expect(metrics.pendingValue, 50);
      expect(metrics.approvedValue, 0);
      expect(metrics.inTransitValue, 0);
      expect(metrics.failedValue, 40);
    });

    test('ordena productos por unidades y por importe', () {
      expect(metrics.topProducts.first.name, 'Paracetamol');
      expect(metrics.topProducts.first.units, 2);
      expect(metrics.topProductsByAmount.first.name, 'Vitamina C');
      expect(metrics.topProductsByAmount.first.amount, 30);
    });
  });

  group('DashboardMetrics logísticas', () {
    final now = DateTime(2026, 6, 18, 20);
    final period = DateRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 18, 23, 59, 59, 999),
    );

    final orders = [
      _order(
        id: 'x',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 6, 17, 10),
        deliveredAt: DateTime(2026, 6, 17, 11, 30),
        driverId: 'd1',
        driverName: 'Carlos Mamani',
      ),
      _order(
        id: 'y',
        status: OrderStatus.entregado,
        createdAt: DateTime(2026, 6, 18, 12),
        deliveredAt: DateTime(2026, 6, 18, 13),
        driverId: 'd1',
        driverName: 'Carlos Mamani',
      ),
      _order(
        id: 'z',
        status: OrderStatus.fallida,
        createdAt: DateTime(2026, 6, 18, 14),
        deliveredAt: DateTime(2026, 6, 18, 15),
        driverId: 'd2',
        driverName: 'Luis Quispe',
      ),
      _order(
        id: 'ruta',
        status: OrderStatus.enRuta,
        createdAt: DateTime(2026, 6, 18, 16),
        driverId: 'd1',
        driverName: 'Carlos Mamani',
      ),
    ];

    final metrics = DashboardMetrics.compute(
      orders: orders,
      inventory: _inventory(),
      period: period,
      now: now,
    );

    test('calcula tasa de éxito y tiempo promedio con fechas', () {
      expect(metrics.delivery.delivered, 2);
      expect(metrics.delivery.failed, 1);
      expect(metrics.delivery.successRate, closeTo(66.666, 0.01));
      expect(metrics.delivery.averageMinutes, 75);
      expect(metrics.delivery.averageSamples, 2);
    });

    test('agrupa actividad por repartidor y exige datos suficientes', () {
      final d1 = metrics.drivers.firstWhere((d) => d.driverId == 'd1');
      final d2 = metrics.drivers.firstWhere((d) => d.driverId == 'd2');
      expect(d1.delivered, 2);
      expect(d1.inTransit, 1);
      expect(d1.successRate, 100);
      expect(d2.failed, 1);
      expect(d2.successRate, 0);

      final sinFechas = DashboardMetrics.compute(
        orders: [
          _order(id: 'sin', status: OrderStatus.entregado, declaredTotal: 10),
        ],
        inventory: _inventory(),
        period: period,
        now: now,
      );
      expect(sinFechas.delivery.averageMinutes, isNull);
      expect(sinFechas.delivery.averageSamples, 0);
      expect(formatAverageTime(null), 'Sin fechas suficientes');
      expect(formatPercent(null), 'Sin datos');
    });
  });

  group('DashboardMetrics inventario', () {
    final now = DateTime(2026, 6, 18, 12);
    final period = DateRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 18, 23, 59, 59, 999),
    );

    DashboardLot lot({
      required String id,
      required int quantity,
      DateTime? expiresAt,
      bool requiresExpiration = true,
    }) {
      return DashboardLot(
        id: id,
        productId: 'p-$id',
        productName: 'Producto $id',
        quantity: quantity,
        requiresExpiration: requiresExpiration,
        expiresAt: expiresAt,
      );
    }

    DashboardProductStock stock({
      required String id,
      required int usable,
      required StockLevel level,
      int threshold = 10,
    }) {
      return DashboardProductStock(
        productId: id,
        name: id,
        category: 'Genéricos',
        usable: usable,
        expired: 0,
        threshold: threshold,
        level: level,
      );
    }

    final inventory = _inventory(
      hasLotData: true,
      products: [
        stock(id: 'Agotado', usable: 0, level: StockLevel.agotado),
        stock(id: 'Bajo', usable: 5, level: StockLevel.bajo),
        stock(id: 'Normal', usable: 25, level: StockLevel.normal),
      ],
      lots: [
        lot(id: 'vencido', quantity: 10, expiresAt: DateTime(2026, 6, 1)),
        lot(id: 'd30', quantity: 3, expiresAt: DateTime(2026, 6, 28)),
        lot(id: 'd60', quantity: 2, expiresAt: DateTime(2026, 8, 2)),
        lot(id: 'd90', quantity: 1, expiresAt: DateTime(2026, 9, 6)),
        lot(id: 'd91', quantity: 8, expiresAt: DateTime(2026, 9, 17)),
        lot(
          id: 'sin-control',
          quantity: 4,
          expiresAt: DateTime(2026, 6, 20),
          requiresExpiration: false,
        ),
      ],
    );

    final metrics = DashboardMetrics.compute(
      orders: const [],
      inventory: inventory,
      period: period,
      now: now,
    );

    test('excluye vencidos y agrupa los próximos 90 días', () {
      expect(metrics.inventory.hasLotData, isTrue);
      expect(metrics.inventory.expiredLots, 1);
      expect(metrics.inventory.expiredUnits, 10);
      expect(metrics.inventory.expiring30, 1);
      expect(metrics.inventory.expiring60, 1);
      expect(metrics.inventory.expiring90, 1);
      expect(metrics.inventory.outOfStock, 1);
      expect(metrics.inventory.lowStock, 1);
      expect(metrics.inventory.normalStock, 1);
    });

    test('respeta requiere_vencimiento en el cálculo por lote', () {
      final sinControl = inventory.lots.firstWhere(
        (item) => item.id == 'sin-control',
      );
      expect(sinControl.isExpiredAt(now), isFalse);
      expect(sinControl.daysToExpire(now), isNull);
      final expired = inventory.lots.firstWhere((item) => item.id == 'vencido');
      expect(expired.isExpiredAt(now), isTrue);
      expect(expired.daysToExpire(now), -17);
    });

    test('genera alertas accionables con su tipo', () {
      final types = metrics.alerts.map((alert) => alert.type).toSet();
      expect(types, contains(DashboardAlertType.vencidos));
      expect(types, contains(DashboardAlertType.agotados));
      expect(types, contains(DashboardAlertType.stockBajo));
      expect(types, contains(DashboardAlertType.porVencer));
    });
  });
}
