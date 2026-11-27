import 'order.dart';

/// Períodos de consulta del dashboard administrativo.
enum DashboardPeriod {
  hoy('Hoy'),
  sieteDias('7 días'),
  mes('Mes'),
  trimestre('Trimestre'),
  anio('Año'),
  personalizado('Rango');

  const DashboardPeriod(this.label);

  final String label;
}

/// Rango de fechas inclusivo utilizado por los filtros del dashboard.
class DateRange {
  const DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

  int get days => end.difference(start).inDays + 1;

  /// Rango inmediatamente anterior de igual duración, para comparaciones.
  DateRange previous() {
    final duration = end.difference(start);
    final previousEnd = start.subtract(const Duration(milliseconds: 1));
    return DateRange(start: previousEnd.subtract(duration), end: previousEnd);
  }

  DateTime get startOfDay => DateTime(start.year, start.month, start.day);

  DateTime get endOfDay =>
      DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

  static DateRange today(DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    return DateRange(start: start, end: now);
  }

  static DateRange ofDays(DateTime now, int days) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    return DateRange(start: start, end: now);
  }

  static DateRange ofMonth(DateTime now) =>
      DateRange(start: DateTime(now.year, now.month), end: now);

  static DateRange ofQuarter(DateTime now) {
    final firstMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    return DateRange(start: DateTime(now.year, firstMonth), end: now);
  }

  static DateRange ofYear(DateTime now) =>
      DateRange(start: DateTime(now.year), end: now);

  /// Rango resuelto según el período seleccionado. Para [DashboardPeriod.
  /// personalizado] se usa [custom] o, si falta, el día actual.
  static DateRange resolve(
    DashboardPeriod period,
    DateTime now, {
    DateRange? custom,
  }) {
    return switch (period) {
      DashboardPeriod.hoy => today(now),
      DashboardPeriod.sieteDias => ofDays(now, 7),
      DashboardPeriod.mes => ofMonth(now),
      DashboardPeriod.trimestre => ofQuarter(now),
      DashboardPeriod.anio => ofYear(now),
      DashboardPeriod.personalizado => custom ?? today(now),
    };
  }
}

/// Origen de los datos de pedidos mostrados en el dashboard.
///
/// [local] se usa cuando la app no tiene Firebase (modo demostración),
/// [localFallback] se conserva por compatibilidad con fuentes anteriores y
/// [permissionDenied] cuando las reglas impidieron leer los datos reales.
enum DashboardOrigin {
  loading,
  firestore,
  local,
  localFallback,
  permissionDenied,
  error,
}

/// Origen de los datos de inventario.
enum InventoryOrigin {
  loading,
  firestore,
  local,
  permissionDenied,
  unavailable,
}

/// Línea de pedido normalizada desde el modelo local o Firestore.
class DashboardOrderLine {
  const DashboardOrderLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.category = 'Sin categoría',
    this.brand = '',
    this.presentation = '',
  });

  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String category;
  final String brand;
  final String presentation;

  double get subtotal => unitPrice * quantity;
}

/// Pedido normalizado para los cálculos del dashboard.
///
/// Se conservan los importes históricos de cada línea; no se consultan los
/// precios actuales del catálogo.
class DashboardOrder {
  const DashboardOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.items,
    required this.pharmacyName,
    this.createdAt,
    this.deliveredAt,
    this.driverId,
    this.driverName,
    this.failureReason,
    this.declaredTotal,
    this.address = '',
    this.contactName = '',
    this.contactPhone = '',
    this.notes = '',
    this.cancelled = false,
    this.rawStatus = '',
  });

  final String id;
  final String number;
  final OrderStatus status;
  final List<DashboardOrderLine> items;
  final String pharmacyName;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final String? driverId;
  final String? driverName;
  final String? failureReason;
  final String address;
  final String contactName;
  final String contactPhone;
  final String notes;
  final double? declaredTotal;
  final bool cancelled;
  final String rawStatus;

  double get total {
    if (items.isNotEmpty) {
      final computed = items.fold(0.0, (sum, item) => sum + item.subtotal);
      if (computed > 0) return computed;
    }
    return declaredTotal ?? 0;
  }

  int get totalUnits => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isDelivered => !cancelled && status == OrderStatus.entregado;

  bool get isFailure =>
      !cancelled &&
      (status == OrderStatus.fallida || status == OrderStatus.reprogramado);

  bool get isRescheduled => !cancelled && status == OrderStatus.reprogramado;

  bool get isPending => !cancelled && status == OrderStatus.pendiente;

  bool get isApproved => !cancelled && status == OrderStatus.aprobado;

  bool get isInTransit => !cancelled && status == OrderStatus.enRuta;

  /// Fecha efectiva para métricas comerciales y logísticas.
  DateTime? get completionDate => deliveredAt;

  DashboardOrder copyWith({
    OrderStatus? status,
    DateTime? deliveredAt,
    String? driverId,
    String? driverName,
    String? failureReason,
    bool? cancelled,
    String? pharmacyName,
    List<DashboardOrderLine>? items,
  }) {
    return DashboardOrder(
      id: id,
      number: number,
      status: status ?? this.status,
      items: items ?? this.items,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      failureReason: failureReason ?? this.failureReason,
      declaredTotal: declaredTotal,
      address: address,
      contactName: contactName,
      contactPhone: contactPhone,
      notes: notes,
      cancelled: cancelled ?? this.cancelled,
      rawStatus: rawStatus,
    );
  }
}

/// Emisión del repositorio con los pedidos y el origen de los datos.
class DashboardFeed {
  const DashboardFeed({
    required this.orders,
    required this.origin,
    required this.updatedAt,
    this.message,
  });

  final List<DashboardOrder> orders;
  final DashboardOrigin origin;
  final DateTime updatedAt;
  final String? message;

  bool get isFirestore => origin == DashboardOrigin.firestore;

  bool get isFallback => origin == DashboardOrigin.localFallback;

  /// Datos de demostración que no provienen de Firestore.
  bool get isDemo =>
      origin == DashboardOrigin.local ||
      origin == DashboardOrigin.localFallback;

  bool get hasPermissionIssue => origin == DashboardOrigin.permissionDenied;
}

/// Producto del catálogo, tal como se necesita para el inventario.
class DashboardProduct {
  const DashboardProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.requiresExpiration,
    this.lowStockThreshold,
    this.price = 0,
  });

  final String id;
  final String name;
  final String category;
  final bool requiresExpiration;
  final int? lowStockThreshold;
  final double price;
}

/// Lote de inventario proveniente de `lotes_productos`.
class DashboardLot {
  const DashboardLot({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.requiresExpiration,
    this.category = 'Sin categoría',
    this.lotCode = '',
    this.expiresAt,
    this.receivedAt,
    this.active = true,
    this.invalidExpiry = false,
  });

  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final bool requiresExpiration;
  final String category;
  final String lotCode;
  final DateTime? expiresAt;
  final DateTime? receivedAt;
  final bool active, invalidExpiry;

  bool isExpiredAt(DateTime now) {
    if (expiresAt == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return expiresAt!.isBefore(today);
  }

  int? daysToExpire(DateTime now) {
    if (!requiresExpiration || expiresAt == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day);
    return expiry.difference(today).inDays;
  }
}

enum StockLevel { agotado, bajo, normal }

/// Existencias utilizables por producto. Los lotes vencidos se excluyen.
class DashboardProductStock {
  const DashboardProductStock({
    required this.productId,
    required this.name,
    required this.category,
    required this.usable,
    required this.expired,
    required this.threshold,
    required this.level,
    this.lotCount = 0,
    this.nextExpiration,
  });

  final String productId;
  final String name;
  final String category;
  final int usable;
  final int expired;
  final int threshold;
  final StockLevel level;
  final int lotCount;
  final DateTime? nextExpiration;

  /// Proporción de existencias respecto al umbral de stock bajo. Se usa para
  /// ordenar y dibujar las barras de stock crítico.
  double get thresholdRatio {
    if (threshold <= 0) return usable <= 0 ? 0 : 1;
    return (usable / threshold).clamp(0.0, 2.0);
  }

  bool get needsAttention => level != StockLevel.normal;
}

/// Inventario consolidado del dashboard.
class DashboardInventory {
  const DashboardInventory({
    required this.products,
    required this.lots,
    required this.origin,
    this.hasLotData = false,
    this.productsWithoutLots = 0,
    this.error,
    this.note,
    this.lowStockThreshold = 10,
  });

  const DashboardInventory.loading()
    : products = const [],
      lots = const [],
      origin = InventoryOrigin.loading,
      hasLotData = false,
      productsWithoutLots = 0,
      error = null,
      note = null,
      lowStockThreshold = 10;

  final List<DashboardProductStock> products;
  final List<DashboardLot> lots;
  final InventoryOrigin origin;
  final bool hasLotData;
  final int productsWithoutLots;
  final String? error;
  final String? note;
  final int lowStockThreshold;

  bool get hasData => products.isNotEmpty || lots.isNotEmpty;

  bool get isLoading => origin == InventoryOrigin.loading;

  bool get isLocal => origin == InventoryOrigin.local;

  bool get isRemote => origin == InventoryOrigin.firestore;

  bool get isPermissionDenied => origin == InventoryOrigin.permissionDenied;

  bool get isUnavailable =>
      origin == InventoryOrigin.unavailable ||
      origin == InventoryOrigin.permissionDenied;
}

/// Tipo de alerta accionable del dashboard.
enum DashboardAlertType {
  agotados,
  stockBajo,
  vencidos,
  porVencer,
  entregasFallidas,
  pedidosAtencion,
  inventarioNoDisponible,
}

class DashboardAlert {
  const DashboardAlert({
    required this.type,
    required this.title,
    required this.detail,
    this.count = 0,
  });

  final DashboardAlertType type;
  final String title;
  final String detail;
  final int count;
}
