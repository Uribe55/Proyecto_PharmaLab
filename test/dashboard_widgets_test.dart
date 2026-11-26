import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/models/dashboard_metrics.dart';
import 'package:proyecto_final_movil/models/dashboard_models.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/screens/administrador/admin_dashboard_screen.dart';
import 'package:proyecto_final_movil/services/dashboard_repository.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';
import 'package:proyecto_final_movil/viewmodels/admin_dashboard_viewmodel.dart';
import 'package:proyecto_final_movil/widgets/dashboard/dashboard_alerts.dart';
import 'package:proyecto_final_movil/widgets/dashboard/dashboard_charts.dart';
import 'package:proyecto_final_movil/widgets/dashboard/dashboard_kpi_card.dart';
import 'package:proyecto_final_movil/widgets/dashboard/dashboard_period_selector.dart';

class _EmptyRepository extends DashboardRepository {
  @override
  Stream<DashboardFeed> watchOrders() async* {
    yield DashboardFeed(
      orders: const [],
      origin: DashboardOrigin.local,
      updatedAt: DateTime(2026, 6, 18, 12),
    );
  }

  @override
  Future<DashboardInventory> loadInventory() async {
    return const DashboardInventory(
      products: [
        DashboardProductStock(
          productId: 'p1',
          name: 'Producto agotado',
          category: 'Genéricos',
          usable: 0,
          expired: 0,
          threshold: 10,
          level: StockLevel.agotado,
        ),
      ],
      lots: [],
      origin: InventoryOrigin.local,
      hasLotData: false,
      lowStockThreshold: 10,
    );
  }
}

class _DeniedInventoryRepository extends DashboardRepository {
  @override
  Stream<DashboardFeed> watchOrders() async* {
    yield DashboardFeed(
      orders: const [],
      origin: DashboardOrigin.local,
      updatedAt: DateTime(2026, 6, 18, 12),
    );
  }

  @override
  Future<DashboardInventory> loadInventory() async {
    return const DashboardInventory(
      products: [],
      lots: [],
      origin: InventoryOrigin.permissionDenied,
      error: 'Missing or insufficient permissions.',
    );
  }
}

class _DeniedOrdersRepository extends _DeniedInventoryRepository {
  @override
  Stream<DashboardFeed> watchOrders() => Stream.value(
    DashboardFeed(
      orders: const [],
      origin: DashboardOrigin.permissionDenied,
      updatedAt: DateTime(2026, 6, 18),
      message: 'Permisos insuficientes.',
    ),
  );
}

class _FailingOrdersRepository extends DashboardRepository {
  @override
  Stream<DashboardFeed> watchOrders() async* {
    throw StateError('sin conexión');
  }

  @override
  Future<DashboardInventory> loadInventory() async {
    return const DashboardInventory(
      products: [],
      lots: [],
      origin: InventoryOrigin.unavailable,
    );
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 350, child: child)),
      ),
    ),
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required Size size,
  DashboardRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final viewModel = AdminDashboardViewModel(
    repository: repository ?? _EmptyRepository(),
    clock: () => DateTime(2026, 6, 18, 12),
  )..init();
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: AdminDashboardScreen(viewModel: viewModel),
    ),
  );
  await tester.pumpAndSettle();
}

/// Las pestañas se desplazan horizontalmente en pantallas estrechas, así que
/// primero se asegura que la pestaña solicitada quede visible.
Future<void> _openTab(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Permisos denegados no presentan pedidos demo ni indicadores en cero',
    (tester) async {
      await _pumpDashboard(
        tester,
        size: const Size(390, 844),
        repository: _DeniedOrdersRepository(),
      );
      expect(
        find.text('Permisos denegados · pedidos no disponibles'),
        findsOneWidget,
      );
      expect(find.text('No se pudieron cargar los pedidos.'), findsOneWidget);
      expect(find.text('Recibidos hoy'), findsNothing);
      expect(find.textContaining('pedidos de demostración'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('la tarjeta KPI muestra el valor y navega', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        DashboardKpiCard(
          label: 'Pendientes',
          value: '12',
          icon: Icons.hourglass_top_rounded,
          caption: 'Requieren aprobación',
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Requieren aprobación'), findsOneWidget);

    await tester.tap(find.text('12'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('la distribución por estado navega al estado tocado', (
    tester,
  ) async {
    final tapped = <OrderStatus>[];
    await tester.pumpWidget(
      _wrap(
        StatusBarsChart(
          counts: const {
            OrderStatus.pendiente: 2,
            OrderStatus.aprobado: 1,
            OrderStatus.enRuta: 1,
            OrderStatus.entregado: 5,
            OrderStatus.fallida: 1,
          },
          onTap: tapped.add,
        ),
      ),
    );

    expect(find.text('Entregado'), findsOneWidget);
    await tester.tap(find.text('Entregado'));
    await tester.pump();
    expect(tapped, [OrderStatus.entregado]);
  });

  testWidgets('los gráficos no desbordan en ancho móvil', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            DeliveredValueTrendChart(
              points: const [
                EvolutionPoint(label: '01/06', value: 120, orders: 2),
                EvolutionPoint(label: '02/06', value: 0, orders: 0),
                EvolutionPoint(label: '03/06', value: 3400, orders: 7),
              ],
            ),
            const SizedBox(height: 16),
            CategoryDonutChart(
              categories: const [
                CategorySales(
                  category: 'Genéricos',
                  units: 12,
                  amount: 240,
                  share: 0.6,
                  amountShare: 0.6,
                ),
                CategorySales(
                  category: 'Vitaminas',
                  units: 8,
                  amount: 160,
                  share: 0.4,
                  amountShare: 0.4,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Genéricos'), findsOneWidget);
    expect(find.text('60.0 %'), findsOneWidget);
  });

  testWidgets('el selector de período informa la selección', (tester) async {
    var selected = DashboardPeriod.anio;
    var picked = false;
    await tester.pumpWidget(
      _wrap(
        DashboardPeriodSelector(
          value: DashboardPeriod.mes,
          range: DateRange(
            start: DateTime(2026, 6, 1),
            end: DateTime(2026, 6, 18),
          ),
          onSelected: (value) => selected = value,
          onPickRange: () => picked = true,
        ),
      ),
    );

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('7 días'), findsOneWidget);
    expect(find.textContaining('01 jun 2026'), findsOneWidget);

    await tester.tap(find.text('7 días'));
    await tester.pump();
    expect(selected, DashboardPeriod.sieteDias);

    await tester.scrollUntilVisible(
      find.text('Rango'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(DashboardPeriodSelector),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rango'));
    await tester.pump();
    expect(picked, isTrue);
  });

  testWidgets('la alerta es accionable y muestra su detalle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        DashboardAlertTile(
          alert: const DashboardAlert(
            type: DashboardAlertType.stockBajo,
            title: 'Stock bajo',
            detail: '3 producto(s) en o por debajo del umbral.',
            count: 3,
          ),
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Stock bajo'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Stock bajo'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('el gráfico vacío no inventa cifras', (tester) async {
    await tester.pumpWidget(_wrap(const DeliveredValueTrendChart(points: [])));
    expect(
      find.text('Sin datos suficientes para graficar la evolución.'),
      findsOneWidget,
    );
  });

  testWidgets('las pestañas cambian de apartado sin recargar la pantalla', (
    tester,
  ) async {
    await _pumpDashboard(tester, size: const Size(390, 844));

    expect(find.text('Todo PharmaLab, a la vista.'), findsOneWidget);
    expect(find.text('Aún no hay pedidos registrados'), findsOneWidget);
    expect(find.text('Resumen operativo'), findsOneWidget);

    await _openTab(tester, 'Ventas');
    expect(find.text('Análisis comercial'), findsOneWidget);
    expect(find.text('Valor de pedidos entregados'), findsOneWidget);
    expect(find.text('Resumen operativo'), findsNothing);

    await _openTab(tester, 'Logística');
    expect(find.text('Logística y entregas'), findsOneWidget);
    expect(find.text('Tasa de éxito'), findsOneWidget);
    expect(find.text('Sin entregas finalizadas'), findsOneWidget);

    await _openTab(tester, 'Inventario');
    expect(find.text('Inventario y vencimientos'), findsOneWidget);
    expect(find.text('Producto agotado'), findsWidgets);
    expect(find.text('Ver inventario'), findsOneWidget);

    await _openTab(tester, 'Resumen');
    expect(find.text('Resumen operativo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el panel no desborda en escritorio y en móvil', (tester) async {
    await _pumpDashboard(tester, size: const Size(1180, 820));
    expect(find.text('Todo PharmaLab, a la vista.'), findsOneWidget);

    await _openTab(tester, 'Ventas');
    expect(find.text('Análisis comercial'), findsOneWidget);

    await _openTab(tester, 'Logística');
    expect(find.text('Logística y entregas'), findsOneWidget);

    await _openTab(tester, 'Inventario');
    expect(find.text('Inventario y vencimientos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el inventario denegado muestra guiones en lugar de ceros', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      size: const Size(390, 844),
      repository: _DeniedInventoryRepository(),
    );

    await _openTab(tester, 'Inventario');
    expect(find.text('Productos agotados'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(4));
    expect(
      find.textContaining('No se muestran ceros porque la consulta'),
      findsOneWidget,
    );
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si fallan los pedidos no se muestran ceros en las pestañas', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      size: const Size(390, 844),
      repository: _FailingOrdersRepository(),
    );

    expect(find.text('No se pudieron cargar los pedidos.'), findsOneWidget);
    expect(find.text('Recibidos hoy'), findsNothing);

    await _openTab(tester, 'Ventas');
    expect(find.text('No se pudieron cargar los pedidos.'), findsOneWidget);
    expect(find.text('Valor de pedidos entregados'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
