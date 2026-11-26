import 'dart:math' as math;

import '../models/dashboard_models.dart';
import '../models/order.dart';

class EvolutionPoint {
  const EvolutionPoint({
    required this.label,
    required this.value,
    required this.orders,
  });

  final String label;
  final double value;
  final int orders;
}

/// Punto de evolución del tiempo promedio de entrega.
class DeliveryTimePoint {
  const DeliveryTimePoint({
    required this.label,
    required this.minutes,
    required this.samples,
  });

  final String label;

  /// `null` cuando el intervalo no tiene entregas con fechas válidas.
  final double? minutes;
  final int samples;
}

class ProductSales {
  const ProductSales({
    required this.productId,
    required this.name,
    required this.category,
    required this.units,
    required this.amount,
  });

  final String productId;
  final String name;
  final String category;
  final int units;
  final double amount;
}

class CategorySales {
  const CategorySales({
    required this.category,
    required this.units,
    required this.amount,
    required this.share,
    this.amountShare = 0,
  });

  final String category;
  final int units;
  final double amount;

  /// Participación sobre las unidades entregadas.
  final double share;

  /// Participación sobre el valor comercial entregado.
  final double amountShare;
}

class DeliveryMetrics {
  const DeliveryMetrics({
    required this.delivered,
    required this.failed,
    required this.successRate,
    required this.averageMinutes,
    required this.averageSamples,
  });

  final int delivered;
  final int failed;

  /// Porcentaje de entregas exitosas sobre las finalizadas. `null` si no hay
  /// entregas finalizadas en el período.
  final double? successRate;

  /// Tiempo promedio entre la creación y la entrega. `null` si faltan fechas.
  final double? averageMinutes;
  final int averageSamples;
}

class DriverActivity {
  const DriverActivity({
    required this.driverId,
    required this.name,
    required this.delivered,
    required this.failed,
    required this.inTransit,
    required this.assigned,
  });

  final String driverId;
  final String name;
  final int delivered;
  final int failed;
  final int inTransit;
  final int assigned;

  double? get successRate {
    final finished = delivered + failed;
    if (finished == 0) return null;
    return delivered / finished * 100;
  }
}

class InventoryMetrics {
  const InventoryMetrics({
    required this.available,
    required this.outOfStock,
    required this.lowStock,
    required this.normalStock,
    required this.expiredLots,
    required this.expiredUnits,
    required this.expiring30,
    required this.expiring60,
    required this.expiring90,
    required this.expiring30Units,
    required this.expiring60Units,
    required this.expiring90Units,
    required this.hasLotData,
  });

  final bool available;
  final int outOfStock;
  final int lowStock;
  final int normalStock;
  final int expiredLots;
  final int expiredUnits;
  final int expiring30;
  final int expiring60;
  final int expiring90;
  final int expiring30Units;
  final int expiring60Units;
  final int expiring90Units;
  final bool hasLotData;

  int get expiringLots => expiring30 + expiring60 + expiring90;

  int get expiringUnits => expiring30Units + expiring60Units + expiring90Units;
}

/// Cálculos del dashboard. Es lógica pura y se prueba de forma aislada.
class DashboardMetrics {
  const DashboardMetrics({
    required this.period,
    required this.previousPeriod,
    required this.receivedToday,
    required this.receivedMonth,
    required this.registeredValueAll,
    required this.pending,
    required this.approved,
    required this.inTransit,
    required this.deliveredToday,
    required this.failedInPeriod,
    required this.totalInPeriod,
    required this.deliveredInPeriod,
    required this.deliveredValue,
    required this.previousDeliveredValue,
    required this.variationPercent,
    required this.averageTicket,
    required this.registeredValueInPeriod,
    required this.pendingValue,
    required this.approvedValue,
    required this.inTransitValue,
    required this.failedValue,
    required this.salesToday,
    required this.salesMonth,
    required this.salesQuarter,
    required this.statusCounts,
    required this.evolution,
    required this.comparison,
    required this.deliveryTimeEvolution,
    required this.topProducts,
    required this.topProductsByAmount,
    required this.categories,
    required this.delivery,
    required this.drivers,
    required this.inventory,
    required this.alerts,
    required this.attentionOrders,
    required this.deliveredOrdersWithoutDetail,
    required this.recentOrders,
  });

  final DateRange period;
  final DateRange previousPeriod;
  final int receivedToday;
  final int receivedMonth;
  final double registeredValueAll;
  final int pending;
  final int approved;
  final int inTransit;
  final int deliveredToday;
  final int failedInPeriod;
  final int totalInPeriod;
  final int deliveredInPeriod;

  /// Suma de los importes históricos de los pedidos entregados en el período.
  /// No representa ingresos cobrados: no existe gestión de pagos.
  final double deliveredValue;
  final double previousDeliveredValue;
  final double? variationPercent;
  final double averageTicket;

  /// Valor de los pedidos registrados (por `fecha_pedido`) en el período.
  final double registeredValueInPeriod;

  /// Importes históricos por estado. No son cobros ni utilidades.
  final double pendingValue;
  final double approvedValue;
  final double inTransitValue;
  final double failedValue;

  /// Ventas entregadas por fecha real de entrega, en hora de Bolivia.
  final double salesToday;
  final double salesMonth;
  final double salesQuarter;

  final Map<OrderStatus, int> statusCounts;
  final List<EvolutionPoint> evolution;

  /// Comparación de los últimos seis meses de valor entregado.
  final List<EvolutionPoint> comparison;
  final List<DeliveryTimePoint> deliveryTimeEvolution;
  final List<ProductSales> topProducts;

  /// Productos entregados ordenados por importe histórico.
  final List<ProductSales> topProductsByAmount;
  final List<CategorySales> categories;
  final DeliveryMetrics delivery;
  final List<DriverActivity> drivers;
  final InventoryMetrics inventory;
  final List<DashboardAlert> alerts;
  final int attentionOrders;
  final int deliveredOrdersWithoutDetail;
  final List<DashboardOrder> recentOrders;

  bool get hasCommercialData => deliveredInPeriod > 0;

  bool get hasOrders => totalInPeriod > 0;

  int get finishedDeliveries => delivery.delivered + delivery.failed;

  /// Número de alertas que requieren una acción del administrador.
  int get criticalAlertCount => alerts.length;

  static DashboardMetrics compute({
    required List<DashboardOrder> orders,
    required DashboardInventory inventory,
    required DateRange period,
    required DateTime now,
    int lowStockThreshold = 10,
    Map<String, String> driverNames = const {},
  }) {
    final valid = orders.where((order) => !order.cancelled).toList();
    final today = DateRange.today(now);
    final previous = period.previous();

    final receivedToday = valid
        .where((order) => _inRange(order.createdAt, today))
        .length;
    final pending = valid.where((order) => order.isPending).length;
    final approved = valid.where((order) => order.isApproved).length;
    final inTransit = valid.where((order) => order.isInTransit).length;
    final deliveredToday = valid
        .where(
          (order) => order.isDelivered && _inRange(order.deliveredAt, today),
        )
        .length;

    final periodOrders = valid
        .where((order) => _inRange(order.createdAt, period))
        .toList();
    final deliveredOrders = valid
        .where(
          (order) => order.isDelivered && _inRange(order.deliveredAt, period),
        )
        .toList();
    final allDelivered = valid.where((order) => order.isDelivered).toList();
    final failedOrders = valid
        .where(
          (order) =>
              order.isFailure &&
              _inRange(order.completionDate ?? order.createdAt, period),
        )
        .toList();

    final deliveredValue = deliveredOrders.fold(
      0.0,
      (sum, order) => sum + order.total,
    );
    final previousValue = valid
        .where(
          (order) => order.isDelivered && _inRange(order.deliveredAt, previous),
        )
        .fold(0.0, (sum, order) => sum + order.total);

    final variation = previousValue > 0
        ? (deliveredValue - previousValue) / previousValue * 100
        : null;
    final averageTicket = deliveredOrders.isEmpty
        ? 0.0
        : deliveredValue / deliveredOrders.length;

    final registeredValueInPeriod = periodOrders.fold(
      0.0,
      (sum, order) => sum + order.total,
    );
    double totalFor(bool Function(DashboardOrder) test) =>
        valid.where(test).fold(0.0, (sum, order) => sum + order.total);
    final pendingValue = totalFor((order) => order.isPending);
    final approvedValue = totalFor((order) => order.isApproved);
    final inTransitValue = totalFor((order) => order.isInTransit);
    final failedValue = totalFor((order) => order.isFailure);

    final monthRange = DateRange.ofMonth(now);
    final quarterRange = DateRange.ofQuarter(now);
    double deliveredIn(DateRange range) => allDelivered
        .where((order) => _inRange(order.deliveredAt, range))
        .fold(0.0, (sum, order) => sum + order.total);
    final salesToday = deliveredIn(today);
    final salesMonth = deliveredIn(monthRange);
    final salesQuarter = deliveredIn(quarterRange);

    final statusCounts = <OrderStatus, int>{
      for (final status in OrderStatus.values) status: 0,
    };
    for (final order in periodOrders) {
      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
    }

    final evolution = _buildEvolution(deliveredOrders, period);
    final comparison = _buildComparison(allDelivered, period.end);
    final deliveryTimeEvolution = _buildDeliveryTimeEvolution(
      deliveredOrders,
      period,
    );
    final topProducts = _buildTopProducts(deliveredOrders);
    final topProductsByAmount = _buildTopProducts(
      deliveredOrders,
      sortByAmount: true,
    );
    final categories = _buildCategories(deliveredOrders);
    final delivery = _buildDelivery(deliveredOrders, failedOrders);
    final driverActivity = _buildDrivers(valid, period, driverNames);
    final inventoryMetrics = _buildInventoryMetrics(
      inventory,
      now,
      lowStockThreshold,
    );
    final attention = valid
        .where(
          (order) =>
              (order.isPending || order.isApproved) &&
              order.createdAt != null &&
              order.createdAt!.isBefore(
                now.subtract(const Duration(hours: 24)),
              ),
        )
        .length;

    final alerts = _buildAlerts(
      inventoryMetrics: inventoryMetrics,
      inventory: inventory,
      failedInPeriod: failedOrders.length,
      attentionOrders: attention,
    );

    final recent = [...valid]
      ..sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    return DashboardMetrics(
      period: period,
      previousPeriod: previous,
      receivedToday: receivedToday,
      receivedMonth: valid
          .where((order) => _inRange(order.createdAt, DateRange.ofMonth(now)))
          .length,
      registeredValueAll: valid.fold(0.0, (sum, order) => sum + order.total),
      pending: pending,
      approved: approved,
      inTransit: inTransit,
      deliveredToday: deliveredToday,
      failedInPeriod: failedOrders.length,
      totalInPeriod: periodOrders.length,
      deliveredInPeriod: deliveredOrders.length,
      deliveredValue: deliveredValue,
      previousDeliveredValue: previousValue,
      variationPercent: variation,
      averageTicket: averageTicket,
      registeredValueInPeriod: registeredValueInPeriod,
      pendingValue: pendingValue,
      approvedValue: approvedValue,
      inTransitValue: inTransitValue,
      failedValue: failedValue,
      salesToday: salesToday,
      salesMonth: salesMonth,
      salesQuarter: salesQuarter,
      statusCounts: statusCounts,
      evolution: evolution,
      comparison: comparison,
      deliveryTimeEvolution: deliveryTimeEvolution,
      topProducts: topProducts,
      topProductsByAmount: topProductsByAmount,
      categories: categories,
      delivery: delivery,
      drivers: driverActivity,
      inventory: inventoryMetrics,
      alerts: alerts,
      attentionOrders: attention,
      deliveredOrdersWithoutDetail: deliveredOrders
          .where((order) => order.items.isEmpty)
          .length,
      recentOrders: recent.take(4).toList(),
    );
  }

  static bool _inRange(DateTime? date, DateRange range) =>
      date != null && range.contains(date);

  static List<EvolutionPoint> _buildEvolution(
    List<DashboardOrder> deliveredOrders,
    DateRange period,
  ) {
    final buckets = _buildBuckets(period);
    final points = <EvolutionPoint>[];
    for (final bucket in buckets) {
      final matching = deliveredOrders.where(
        (order) => bucket.range.contains(order.deliveredAt!),
      );
      points.add(
        EvolutionPoint(
          label: bucket.label,
          value: matching.fold(0.0, (sum, order) => sum + order.total),
          orders: matching.length,
        ),
      );
    }
    return points;
  }

  static List<_ChartBucket> _buildBuckets(DateRange period) {
    final firstDay = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );
    final lastDay = DateTime(period.end.year, period.end.month, period.end.day);
    final days = lastDay.difference(firstDay).inDays + 1;

    if (days <= 10) {
      return [
        for (var i = 0; i < days; i++)
          _ChartBucket(
            label: _dayLabel(firstDay.add(Duration(days: i))),
            range: DateRange(
              start: firstDay.add(Duration(days: i)),
              end: _endOfDay(firstDay.add(Duration(days: i))),
            ),
          ),
      ];
    }

    if (days <= 45) {
      final buckets = <_ChartBucket>[];
      var cursor = firstDay;
      while (!cursor.isAfter(lastDay)) {
        final end = cursor.add(const Duration(days: 6));
        final bucketEnd = end.isAfter(lastDay) ? lastDay : end;
        buckets.add(
          _ChartBucket(
            label: _rangeLabel(cursor, bucketEnd),
            range: DateRange(start: cursor, end: _endOfDay(bucketEnd)),
          ),
        );
        cursor = bucketEnd.add(const Duration(days: 1));
      }
      return buckets;
    }

    final buckets = <_ChartBucket>[];
    var month = DateTime(firstDay.year, firstDay.month);
    final lastMonth = DateTime(lastDay.year, lastDay.month);
    final spansYears = firstDay.year != lastDay.year;
    while (!month.isAfter(lastMonth)) {
      final nextMonth = DateTime(month.year, month.month + 1);
      final monthEnd = nextMonth.subtract(const Duration(milliseconds: 1));
      final label = spansYears
          ? '${_monthLabel(month)} '
                '${(month.year % 100).toString().padLeft(2, '0')}'
          : _monthLabel(month);
      buckets.add(
        _ChartBucket(
          label: label,
          range: DateRange(start: month, end: monthEnd),
        ),
      );
      month = nextMonth;
    }
    return buckets;
  }

  /// Comparación de los últimos [months] meses hasta [anchor], usando todos
  /// los pedidos entregados (no solo los del período seleccionado) para que la
  /// comparación tenga una base temporal útil.
  static List<EvolutionPoint> _buildComparison(
    List<DashboardOrder> deliveredOrders,
    DateTime anchor, {
    int months = 6,
  }) {
    final lastMonth = DateTime(anchor.year, anchor.month);
    final firstMonth = DateTime(anchor.year, anchor.month - months + 1);
    final spansYears = firstMonth.year != lastMonth.year;
    final points = <EvolutionPoint>[];
    var cursor = firstMonth;
    while (!cursor.isAfter(lastMonth)) {
      final next = DateTime(cursor.year, cursor.month + 1);
      final end = next.subtract(const Duration(milliseconds: 1));
      final matching = deliveredOrders.where((order) {
        final date = order.deliveredAt;
        return date != null && !date.isBefore(cursor) && !date.isAfter(end);
      });
      points.add(
        EvolutionPoint(
          label: spansYears
              ? '${_monthLabel(cursor)} '
                    '${(cursor.year % 100).toString().padLeft(2, '0')}'
              : _monthLabel(cursor),
          value: matching.fold(0.0, (sum, order) => sum + order.total),
          orders: matching.length,
        ),
      );
      cursor = next;
    }
    return points;
  }

  /// Tiempo promedio de entrega por intervalo del período. Los intervalos sin
  /// muestras válidas conservan `minutes = null` para no inventar ceros.
  static List<DeliveryTimePoint> _buildDeliveryTimeEvolution(
    List<DashboardOrder> deliveredOrders,
    DateRange period,
  ) {
    final points = <DeliveryTimePoint>[];
    for (final bucket in _buildBuckets(period)) {
      final samples = <double>[];
      for (final order in deliveredOrders) {
        final delivered = order.deliveredAt;
        final created = order.createdAt;
        if (delivered == null ||
            created == null ||
            !bucket.range.contains(delivered)) {
          continue;
        }
        final minutes = delivered.difference(created).inMinutes;
        if (minutes >= 0) samples.add(minutes.toDouble());
      }
      points.add(
        DeliveryTimePoint(
          label: bucket.label,
          minutes: samples.isEmpty
              ? null
              : samples.reduce((a, b) => a + b) / samples.length,
          samples: samples.length,
        ),
      );
    }
    return points;
  }

  static List<ProductSales> _buildTopProducts(
    List<DashboardOrder> deliveredOrders, {
    bool sortByAmount = false,
  }) {
    final byProduct = <String, ProductSales>{};
    final units = <String, int>{};
    final amount = <String, double>{};
    for (final order in deliveredOrders) {
      for (final item in order.items) {
        final key = item.productId.isEmpty ? item.name : item.productId;
        units[key] = (units[key] ?? 0) + item.quantity;
        amount[key] = (amount[key] ?? 0) + item.subtotal;
        byProduct[key] = ProductSales(
          productId: key,
          name: item.name,
          category: item.category,
          units: units[key]!,
          amount: amount[key]!,
        );
      }
    }
    final result = byProduct.values.toList()
      ..sort((a, b) {
        if (sortByAmount) {
          final byAmount = b.amount.compareTo(a.amount);
          if (byAmount != 0) return byAmount;
          return b.units.compareTo(a.units);
        }
        final byUnits = b.units.compareTo(a.units);
        if (byUnits != 0) return byUnits;
        return b.amount.compareTo(a.amount);
      });
    return result.take(5).toList();
  }

  static List<CategorySales> _buildCategories(
    List<DashboardOrder> deliveredOrders,
  ) {
    final units = <String, int>{};
    final amount = <String, double>{};
    for (final order in deliveredOrders) {
      for (final item in order.items) {
        final category = item.category.trim().isEmpty
            ? 'Sin categoría'
            : item.category;
        units[category] = (units[category] ?? 0) + item.quantity;
        amount[category] = (amount[category] ?? 0) + item.subtotal;
      }
    }
    final totalUnits = units.values.fold(0, (sum, value) => sum + value);
    final totalAmount = amount.values.fold(0.0, (sum, value) => sum + value);
    final result = [
      for (final entry in units.entries)
        CategorySales(
          category: entry.key,
          units: entry.value,
          amount: amount[entry.key] ?? 0,
          share: totalUnits == 0 ? 0 : entry.value / totalUnits,
          amountShare: totalAmount == 0
              ? 0
              : (amount[entry.key] ?? 0) / totalAmount,
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  static DeliveryMetrics _buildDelivery(
    List<DashboardOrder> deliveredOrders,
    List<DashboardOrder> failedOrders,
  ) {
    final finished = deliveredOrders.length + failedOrders.length;
    final successRate = finished == 0
        ? null
        : deliveredOrders.length / finished * 100;

    final samples = <double>[];
    for (final order in deliveredOrders) {
      final created = order.createdAt;
      final delivered = order.deliveredAt;
      if (created == null || delivered == null) continue;
      final minutes = delivered.difference(created).inMinutes;
      if (minutes >= 0) samples.add(minutes.toDouble());
    }
    final average = samples.isEmpty
        ? null
        : samples.reduce((a, b) => a + b) / samples.length;

    return DeliveryMetrics(
      delivered: deliveredOrders.length,
      failed: failedOrders.length,
      successRate: successRate,
      averageMinutes: average,
      averageSamples: samples.length,
    );
  }

  static List<DriverActivity> _buildDrivers(
    List<DashboardOrder> orders,
    DateRange period,
    Map<String, String> driverNames,
  ) {
    final delivered = <String, int>{};
    final failed = <String, int>{};
    final inTransit = <String, int>{};
    final assigned = <String, int>{};
    final names = <String, String>{};

    String keyOf(DashboardOrder order) {
      final id = order.driverId?.trim();
      if (id != null && id.isNotEmpty) return id;
      return 'sin-repartidor';
    }

    for (final order in orders) {
      final key = keyOf(order);
      final name = order.driverName?.trim();
      if (name != null && name.isNotEmpty) names[key] = name;
      if (driverNames[key] != null && driverNames[key]!.trim().isNotEmpty) {
        names[key] = driverNames[key]!;
      }
      if (order.createdAt != null && period.contains(order.createdAt!)) {
        assigned[key] = (assigned[key] ?? 0) + 1;
      }
      if (order.isInTransit) {
        inTransit[key] = (inTransit[key] ?? 0) + 1;
      }
      if (order.isDelivered && _inRange(order.deliveredAt, period)) {
        delivered[key] = (delivered[key] ?? 0) + 1;
      }
      if (order.isFailure &&
          _inRange(order.completionDate ?? order.createdAt, period)) {
        failed[key] = (failed[key] ?? 0) + 1;
      }
    }

    final keys = <String>{
      ...delivered.keys,
      ...failed.keys,
      ...inTransit.keys,
      ...assigned.keys,
    };
    final activities =
        [
          for (final key in keys)
            DriverActivity(
              driverId: key,
              name:
                  names[key] ??
                  (key == 'sin-repartidor' ? 'Sin repartidor' : key),
              delivered: delivered[key] ?? 0,
              failed: failed[key] ?? 0,
              inTransit: inTransit[key] ?? 0,
              assigned: assigned[key] ?? 0,
            ),
        ]..sort((a, b) {
          final byDelivered = b.delivered.compareTo(a.delivered);
          if (byDelivered != 0) return byDelivered;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    return activities;
  }

  static InventoryMetrics _buildInventoryMetrics(
    DashboardInventory inventory,
    DateTime now,
    int lowStockThreshold,
  ) {
    var outOfStock = 0;
    var lowStock = 0;
    var normalStock = 0;
    for (final product in inventory.products) {
      switch (product.level) {
        case StockLevel.agotado:
          outOfStock++;
        case StockLevel.bajo:
          lowStock++;
        case StockLevel.normal:
          normalStock++;
      }
    }

    final today = DateTime(now.year, now.month, now.day);
    var expiredLots = 0;
    var expiredUnits = 0;
    var expiring30 = 0;
    var expiring60 = 0;
    var expiring90 = 0;
    var expiring30Units = 0;
    var expiring60Units = 0;
    var expiring90Units = 0;
    if (inventory.hasLotData) {
      for (final lot in inventory.lots) {
        if (lot.quantity <= 0 || !lot.requiresExpiration) continue;
        final date = lot.expiresAt;
        if (date == null) continue;
        final expiry = DateTime(date.year, date.month, date.day);
        final days = expiry.difference(today).inDays;
        if (days < 0) {
          expiredLots++;
          expiredUnits += lot.quantity;
        } else if (days <= 30) {
          expiring30++;
          expiring30Units += lot.quantity;
        } else if (days <= 60) {
          expiring60++;
          expiring60Units += lot.quantity;
        } else if (days <= 90) {
          expiring90++;
          expiring90Units += lot.quantity;
        }
      }
    }

    return InventoryMetrics(
      available: inventory.hasData,
      outOfStock: outOfStock,
      lowStock: lowStock,
      normalStock: normalStock,
      expiredLots: expiredLots,
      expiredUnits: expiredUnits,
      expiring30: expiring30,
      expiring60: expiring60,
      expiring90: expiring90,
      expiring30Units: expiring30Units,
      expiring60Units: expiring60Units,
      expiring90Units: expiring90Units,
      hasLotData: inventory.hasLotData,
    );
  }

  static List<DashboardAlert> _buildAlerts({
    required InventoryMetrics inventoryMetrics,
    required DashboardInventory inventory,
    required int failedInPeriod,
    required int attentionOrders,
  }) {
    final alerts = <DashboardAlert>[];
    if (inventory.isUnavailable || inventory.error != null) {
      alerts.add(
        DashboardAlert(
          type: DashboardAlertType.inventarioNoDisponible,
          title: 'Inventario no disponible',
          detail:
              inventory.error ??
              'No se pudo consultar el inventario. Revisa la conexión o los '
                  'permisos de Firestore.',
        ),
      );
    }
    if (inventoryMetrics.expiredLots > 0) {
      alerts.add(
        DashboardAlert(
          type: DashboardAlertType.vencidos,
          title: 'Lotes vencidos',
          detail:
              '${inventoryMetrics.expiredLots} lote(s) con '
              '${inventoryMetrics.expiredUnits} unidad(es) fuera de '
              'disponibilidad.',
          count: inventoryMetrics.expiredLots,
        ),
      );
    }
    if (inventoryMetrics.outOfStock > 0) {
      alerts.add(
        DashboardAlert(
          type: DashboardAlertType.agotados,
          title: 'Productos agotados',
          detail:
              '${inventoryMetrics.outOfStock} producto(s) sin stock '
              'utilizable.',
          count: inventoryMetrics.outOfStock,
        ),
      );
    }
    if (inventoryMetrics.lowStock > 0) {
      alerts.add(
        DashboardAlert(
          type: DashboardAlertType.stockBajo,
          title: 'Stock bajo',
          detail:
              '${inventoryMetrics.lowStock} producto(s) en o por debajo del '
              'umbral de ${inventory.lowStockThreshold} unidades.',
          count: inventoryMetrics.lowStock,
        ),
      );
    }
    final expiring =
        inventoryMetrics.expiring30 +
        inventoryMetrics.expiring60 +
        inventoryMetrics.expiring90;
    if (expiring > 0) {
      alerts.add(
        DashboardAlert(
          type: DashboardAlertType.porVencer,
          title: 'Lotes por vencer',
          detail:
              '${inventoryMetrics.expiring30} en 0–30 días · '
              '${inventoryMetrics.expiring60} en 31–60 días · '
              '${inventoryMetrics.expiring90} en 61–90 días.',
          count: expiring,
        ),
      );
    }
    if (failedInPeriod > 0) {
      alerts.add(
        DashboardAlert(
          type: DashboardAlertType.entregasFallidas,
          title: 'Entregas fallidas',
          detail:
              '$failedInPeriod pedido(s) no se pudieron entregar en el '
              'período seleccionado.',
          count: failedInPeriod,
        ),
      );
    }
    if (attentionOrders > 0) {
      alerts.add(
        DashboardAlert(
          type: DashboardAlertType.pedidosAtencion,
          title: 'Pedidos con atención pendiente',
          detail:
              '$attentionOrders pedido(s) llevan más de 24 h sin avanzar en '
              'su estado.',
          count: attentionOrders,
        ),
      );
    }
    return alerts;
  }

  static DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static String _dayLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  static String _rangeLabel(DateTime start, DateTime end) =>
      '${_dayLabel(start)}–${_dayLabel(end)}';

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String _monthLabel(DateTime date) => _months[date.month - 1];
}

class _ChartBucket {
  const _ChartBucket({required this.label, required this.range});

  final String label;
  final DateRange range;
}

/// Formato compacto para los ejes de los gráficos.
String formatCompactBs(double value) {
  if (value.abs() >= 1000000) {
    return 'Bs ${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) {
    return 'Bs ${(value / 1000).toStringAsFixed(1)}k';
  }
  return 'Bs ${value.toStringAsFixed(0)}';
}

/// Porcentaje con un decimal, tolerante a valores nulos.
String formatPercent(double? value) {
  if (value == null) return 'Sin datos';
  return '${value.toStringAsFixed(1)} %';
}

/// Promedio de minutos en un texto legible.
String formatAverageTime(double? minutes) {
  if (minutes == null) return 'Sin fechas suficientes';
  final rounded = minutes.round();
  if (rounded < 60) return '$rounded min';
  final hours = rounded ~/ 60;
  final remainder = rounded % 60;
  if (hours < 24) {
    return remainder == 0 ? '$hours h' : '$hours h $remainder min';
  }
  final days = hours ~/ 24;
  final restHours = hours % 24;
  return restHours == 0 ? '$days d' : '$days d $restHours h';
}

/// Cuenta los productos por nivel para las tarjetas de inventario.
int clampInt(int value, int min, int max) =>
    math.min(math.max(value, min), max);
