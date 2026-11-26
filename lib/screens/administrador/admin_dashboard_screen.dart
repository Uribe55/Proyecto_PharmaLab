import 'package:flutter/material.dart';

import '../../models/dashboard_metrics.dart';
import '../../models/dashboard_models.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/admin_dashboard_viewmodel.dart';
import '../../widgets/app_header.dart';
import '../../widgets/admin_scroll_layout.dart';
import '../../widgets/dashboard/dashboard_alerts.dart';
import '../../widgets/dashboard/dashboard_charts.dart';
import '../../widgets/dashboard/dashboard_kpi_card.dart';
import '../../widgets/dashboard/dashboard_layout.dart';
import '../../widgets/dashboard/dashboard_lists.dart';
import '../../widgets/dashboard/dashboard_order_detail.dart';
import '../../widgets/dashboard/dashboard_period_selector.dart';
import '../../widgets/empty_state.dart';
import 'admin_inventory_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_employees_screen.dart';

/// Pestañas internas del panel administrativo.
enum AdminDashboardTab {
  resumen('Resumen', Icons.dashboard_outlined, Icons.dashboard_rounded),
  ventas('Ventas', Icons.trending_up_rounded, Icons.trending_up_rounded),
  logistica(
    'Logística',
    Icons.local_shipping_outlined,
    Icons.local_shipping_rounded,
  ),
  inventario(
    'Inventario',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded,
  ),
  empleados('Empleados', Icons.badge_outlined, Icons.badge_rounded);

  const AdminDashboardTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

typedef _OpenOrders = void Function({
  OrderStatus? status,
  DateRange? range,
  bool byDelivery,
  bool attention,
});

/// Dashboard administrativo (RF-19).
///
/// Consume [AdminDashboardViewModel], que mantiene los pedidos en tiempo real y
/// el inventario en un único origen de datos. La información se organiza en
/// cinco pestañas para evitar una única página interminable; los filtros y el
/// origen de los datos se comparten entre todas ellas.
///
/// Toda cifra mostrada proviene de pedidos o lotes reales. Cuando la consulta
/// falla se muestra un estado informativo; cuando los datos son de
/// demostración, un aviso lo indica de forma explícita.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.viewModel});

  final AdminDashboardViewModel viewModel;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminDashboardViewModel get _vm => widget.viewModel;

  AdminDashboardTab _tab = AdminDashboardTab.resumen;

  void _selectTab(AdminDashboardTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  void _openOrders({
    OrderStatus? status,
    DateRange? range,
    bool byDelivery = false,
    bool attention = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminOrdersScreen(
          viewModel: _vm,
          initialStatus: status,
          dateRange: range,
          rangeLabel: range == null ? null : _longRange(range),
          filterByDeliveryDate: byDelivery,
          attentionOnly: attention,
        ),
      ),
    );
  }

  void _openInventory([InventoryFilter filter = InventoryFilter.todos]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdminInventoryScreen(viewModel: _vm, initialFilter: filter),
      ),
    );
  }

  Future<void> _pickCustomRange(DateRange current) async {
    final now = _vm.now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      helpText: 'Rango personalizado',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    _vm.setCustomRange(
      DateRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        ),
      ),
    );
  }

  void _openAlert(DashboardAlert alert) {
    switch (alert.type) {
      case DashboardAlertType.agotados:
        _openInventory(InventoryFilter.agotados);
      case DashboardAlertType.stockBajo:
        _openInventory(InventoryFilter.bajo);
      case DashboardAlertType.vencidos:
        _openInventory(InventoryFilter.vencidos);
      case DashboardAlertType.porVencer:
        _openInventory(InventoryFilter.porVencer);
      case DashboardAlertType.entregasFallidas:
        _openOrders(
          status: OrderStatus.fallida,
          range: _vm.metrics.period,
          byDelivery: true,
        );
      case DashboardAlertType.pedidosAtencion:
        _openOrders(attention: true);
      case DashboardAlertType.inventarioNoDisponible:
        _openInventory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final metrics = _vm.metrics;
        final inventory = _vm.inventory;
        final width = MediaQuery.sizeOf(context).width;
        final horizontal = DashboardLayout.isDesktop(width) ? 24.0 : 16.0;
        final loadingFirstLoad =
            _vm.loadingOrders && _vm.orders.isEmpty && _vm.updatedAt == null;
        final ordersFailed =
            _vm.origin == DashboardOrigin.error ||
            _vm.origin == DashboardOrigin.permissionDenied;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: AdminScrollLayout(
              header: Column(
                children: [
                  const AppTabHeader(
                    title: 'Panel administrativo',
                    showLogo: true,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mostrar información general solamente
                        // cuando NO estamos en Empleados.
                        if (_tab != AdminDashboardTab.empleados) ...[
                          const Text(
                            'SUPERVISIÓN GENERAL',
                            style: AppText.eyebrow,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Todo PharmaLab, a la vista.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Pedidos, entregas e inventario para decidir con datos.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),

                          DashboardSourceBanner(
                            origin: _vm.origin,
                            updatedAt: _vm.updatedAt,
                            message: _vm.ordersError,
                            refreshing: _vm.loadingOrders,
                            onRefresh: _vm.refresh,
                          ),

                          const SizedBox(height: 8),

                          DashboardPeriodSelector(
                            value: _vm.period,
                            range: _vm.range,
                            onSelected: _vm.setPeriod,
                            onPickRange: () => _pickCustomRange(_vm.range),
                          ),

                          const SizedBox(height: 6),
                        ],

                        // Las pestañas se ocultan junto con la cabecera.
                        AdminDashboardTabBar(
                          selected: _tab,
                          onSelected: _selectTab,
                        ),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
              body: switch (_tab) {
                AdminDashboardTab.resumen => _ResumenTab(
                  metrics: metrics,
                  loading: loadingFirstLoad,
                  ordersFailed: ordersFailed,
                  rangeLabel: _longRange(metrics.period),
                  now: _vm.now,
                  onOpenOrders: _openOrders,
                  onOpenAlert: _openAlert,
                  onRefresh: _vm.refresh,
                ),
                AdminDashboardTab.ventas => _VentasTab(
                  metrics: metrics,
                  loading: loadingFirstLoad,
                  ordersFailed: ordersFailed,
                  rangeLabel: _longRange(metrics.period),
                  onRetry: _vm.refresh,
                ),
                AdminDashboardTab.logistica => _LogisticaTab(
                  metrics: metrics,
                  loading: loadingFirstLoad,
                  ordersFailed: ordersFailed,
                  rangeLabel: _longRange(metrics.period),
                  orderCaption: _orderCaption,
                  onOpenOrders: _openOrders,
                  onRetry: _vm.refresh,
                ),
                AdminDashboardTab.inventario => _InventarioTab(
                  metrics: metrics,
                  inventory: inventory,
                  viewModel: _vm,
                  onOpenInventory: _openInventory,
                ),
                AdminDashboardTab.empleados => const AdminEmployeesPanel(
                  embedded: true,
                ),
              },
            ),
          ),
        );
      },
    );
  }

  String _orderCaption(DashboardOrder order) {
    final created = order.createdAt;
    if (created == null) return 'Sin fecha registrada';
    final date = '${_day(created)} ${_month(created)}';
    if (order.driverName != null && order.driverName!.isNotEmpty) {
      return '$date · ${order.driverName}';
    }
    if (order.isDelivered && order.deliveredAt != null) {
      return '$date · entregado ${_day(order.deliveredAt!)} '
          '${_month(order.deliveredAt!)}';
    }
    return date;
  }

  String _longRange(DateRange range) {
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day) {
      return '${_day(range.start)} ${_month(range.start)} '
          '${range.start.year}';
    }
    return '${_day(range.start)} ${_month(range.start)} – '
        '${_day(range.end)} ${_month(range.end)} ${range.end.year}';
  }

  String _day(DateTime date) => date.day.toString().padLeft(2, '0');

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

  String _month(DateTime date) => _months[date.month - 1];
}

/// Barra de pestañas compacta. En pantallas anchas ocupa el ancho disponible;
/// en móvil se desplaza horizontalmente sin desbordar.
class AdminDashboardTabBar extends StatelessWidget {
  const AdminDashboardTabBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AdminDashboardTab selected;
  final ValueChanged<AdminDashboardTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = DashboardLayout.isWide(constraints.maxWidth);
        final pills = [
          for (final tab in AdminDashboardTab.values)
            _TabPill(
              key: ValueKey('admin-tab-${tab.name}'),
              tab: tab,
              selected: tab == selected,
              expanded: wide,
              onTap: () => onSelected(tab),
            ),
        ];
        if (wide) {
          return Row(
            children: [
              for (final pill in pills) ...[
                Expanded(child: pill),
                if (pill != pills.last) const SizedBox(width: 8),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              for (final pill in pills) ...[
                pill,
                if (pill != pills.last) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    super.key,
    required this.tab,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final AdminDashboardTab tab;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Pestaña ${tab.label}',
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 8 : 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (expanded) ...[
                  Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    size: 15,
                    color: selected ? Colors.white : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resumen
// ---------------------------------------------------------------------------

class _ResumenTab extends StatelessWidget {
  const _ResumenTab({
    required this.metrics,
    required this.loading,
    required this.ordersFailed,
    required this.rangeLabel,
    required this.now,
    required this.onOpenOrders,
    required this.onOpenAlert,
    required this.onRefresh,
  });

  final DashboardMetrics metrics;
  final bool loading;
  final bool ordersFailed;
  final String rangeLabel;
  final DateTime now;
  final _OpenOrders onOpenOrders;
  final ValueChanged<DashboardAlert> onOpenAlert;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final today = DateRange.today(now);
    return DashboardTabScroll(
      scrollKey: const PageStorageKey('admin-dashboard-resumen'),
      children: [
        DashboardSectionTitle(
          title: 'Resumen operativo',
          caption: rangeLabel,
          action: TextButton(
            onPressed: () => onOpenOrders(),
            child: const Text('Ver pedidos'),
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          const _LoadingBlock()
        else if (ordersFailed)
          DashboardErrorSurface(
            message: 'No se pudieron cargar los pedidos.',
            onRetry: onRefresh,
          )
        else ...[
          DashboardKpiGrid(
            children: [
              DashboardKpiCard(
                label: 'Recibidos hoy',
                value: '${metrics.receivedToday}',
                icon: Icons.inbox_outlined,
                caption: 'Ver pedidos de hoy',
                onTap: () => onOpenOrders(range: today),
              ),
              DashboardKpiCard(
                label: 'Pendientes',
                value: '${metrics.pending}',
                icon: Icons.hourglass_top_rounded,
                accent: AppColors.pendingText,
                background: AppColors.pendingBackground,
                caption: 'Requieren aprobación',
                onTap: () => onOpenOrders(status: OrderStatus.pendiente),
              ),
              DashboardKpiCard(
                label: 'Aprobados',
                value: '${metrics.approved}',
                icon: Icons.verified_outlined,
                accent: AppColors.approvedText,
                background: AppColors.approvedBackground,
                caption: 'Listos para asignar',
                onTap: () => onOpenOrders(status: OrderStatus.aprobado),
              ),
              DashboardKpiCard(
                label: 'En ruta',
                value: '${metrics.inTransit}',
                icon: Icons.local_shipping_outlined,
                caption: 'Seguimiento en curso',
                onTap: () => onOpenOrders(status: OrderStatus.enRuta),
              ),
              DashboardKpiCard(
                label: 'Entregados hoy',
                value: '${metrics.deliveredToday}',
                icon: Icons.check_circle_outline_rounded,
                accent: AppColors.successText,
                background: AppColors.successBackground,
                caption: 'Ver entregas de hoy',
                onTap: () => onOpenOrders(
                  status: OrderStatus.entregado,
                  range: today,
                  byDelivery: true,
                ),
              ),
              DashboardKpiCard(
                label: 'Fallidas del período',
                value: '${metrics.failedInPeriod}',
                icon: Icons.report_problem_outlined,
                accent: AppColors.danger,
                background: AppColors.dangerBackground,
                caption: 'Revisar incidencias',
                onTap: () => onOpenOrders(
                  status: OrderStatus.fallida,
                  range: metrics.period,
                  byDelivery: true,
                ),
              ),
            ],
          ),
          if (metrics.totalInPeriod == 0) ...[
            const SizedBox(height: 12),
            DashboardSurface(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Aún no hay pedidos registrados',
                description:
                    'Cuando las farmacias realicen pedidos, los indicadores '
                    'operativos y comerciales se actualizarán aquí.',
                action: OutlinedButton(
                  onPressed: onRefresh,
                  child: const Text('Volver a consultar'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DashboardTwoColumns(
            first: DashboardChartCard(
              title: 'Distribución por estado',
              caption: 'Pedidos del período · toca para filtrar',
              child: StatusBarsChart(
                counts: metrics.statusCounts,
                onTap: (status) => onOpenOrders(status: status),
              ),
            ),
            second: DashboardChartCard(
              title: 'Evolución comercial',
              caption: 'Valor entregado por intervalo',
              child: DeliveredValueTrendChart(
                points: metrics.evolution,
                height: 150,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AlertsCard(alerts: metrics.alerts, onOpen: onOpenAlert),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ventas
// ---------------------------------------------------------------------------

class _VentasTab extends StatelessWidget {
  const _VentasTab({
    required this.metrics,
    required this.loading,
    required this.ordersFailed,
    required this.rangeLabel,
    required this.onRetry,
  });

  final DashboardMetrics metrics;
  final bool loading;
  final bool ordersFailed;
  final String rangeLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const DashboardTabScroll(
        scrollKey: PageStorageKey('admin-dashboard-ventas'),
        children: [_LoadingBlock()],
      );
    }
    if (ordersFailed) {
      return DashboardTabScroll(
        scrollKey: const PageStorageKey('admin-dashboard-ventas'),
        children: [
          DashboardErrorSurface(
            message: 'No se pudieron cargar los pedidos.',
            onRetry: onRetry,
          ),
        ],
      );
    }

    final variation = metrics.variationPercent;
    final variationColor = variation == null
        ? AppColors.muted
        : (variation >= 0 ? AppColors.successText : AppColors.danger);
    final variationBackground = variation == null
        ? AppColors.background
        : (variation >= 0
              ? AppColors.successBackground
              : AppColors.dangerBackground);

    return DashboardTabScroll(
      scrollKey: const PageStorageKey('admin-dashboard-ventas'),
      children: [
        DashboardSectionTitle(
          title: 'Análisis comercial',
          caption: 'Pedidos entregados · $rangeLabel',
        ),
        const SizedBox(height: 10),
        DashboardKpiGrid(
          columnsBuilder: (width) => width >= 760 ? 4 : 2,
          children: [
            DashboardKpiCard(
              label: 'Valor de pedidos entregados',
              value: formatBs(metrics.deliveredValue),
              icon: Icons.payments_outlined,
              accent: AppColors.successText,
              background: AppColors.successBackground,
              caption: '${metrics.deliveredInPeriod} pedido(s)',
            ),
            DashboardKpiCard(
              label: 'Ticket promedio',
              value: formatBs(metrics.averageTicket),
              icon: Icons.receipt_long_outlined,
              caption: 'Por pedido entregado',
            ),
            DashboardKpiCard(
              label: 'Pedidos entregados',
              value: '${metrics.deliveredInPeriod}',
              icon: Icons.check_circle_outline_rounded,
              accent: AppColors.successText,
              background: AppColors.successBackground,
              caption: 'En el período',
            ),
            DashboardKpiCard(
              label: 'Variación vs. anterior',
              value: variation == null
                  ? 'Sin datos'
                  : '${variation >= 0 ? '+' : ''}'
                        '${variation.toStringAsFixed(1)} %',
              icon: variation != null && variation < 0
                  ? Icons.trending_down_rounded
                  : Icons.trending_up_rounded,
              accent: variationColor,
              background: variationBackground,
              caption: metrics.previousDeliveredValue > 0
                  ? 'Antes ${formatBs(metrics.previousDeliveredValue)}'
                  : 'Sin período comparable',
            ),
          ],
        ),
        const SizedBox(height: 12),
        DashboardSectionTitle(
          title: 'Indicadores financieros',
          caption: 'Importes históricos por estado · sin cobros registrados',
        ),
        const SizedBox(height: 10),
        DashboardKpiGrid(
          columnsBuilder: (width) => width >= 760 ? 4 : 2,
          children: [
            DashboardKpiCard(
              label: 'Pedidos registrados',
              value: '${metrics.totalInPeriod}',
              icon: Icons.receipt_long_outlined,
              caption: formatBs(metrics.registeredValueInPeriod),
            ),
            DashboardKpiCard(
              label: 'Pedidos del mes',
              value: '${metrics.receivedMonth}',
              icon: Icons.calendar_month_outlined,
              caption: 'Por fecha de pedido · Bolivia',
            ),
            DashboardKpiCard(
              label: 'Valor total registrado',
              value: formatBs(metrics.registeredValueAll),
              icon: Icons.receipt_long_outlined,
              caption: 'Historial leído, excluye cancelados',
            ),
            DashboardKpiCard(
              label: 'Importe pendiente',
              value: formatBs(metrics.pendingValue),
              icon: Icons.hourglass_empty_rounded,
              accent: AppColors.pendingText,
              background: AppColors.pendingBackground,
              caption: 'Pedidos por aprobar',
            ),
            DashboardKpiCard(
              label: 'Importe aprobado',
              value: formatBs(metrics.approvedValue),
              icon: Icons.verified_outlined,
              accent: AppColors.approvedText,
              background: AppColors.approvedBackground,
              caption: 'Listos para asignar',
            ),
            DashboardKpiCard(
              label: 'Importe en ruta',
              value: formatBs(metrics.inTransitValue),
              icon: Icons.local_shipping_outlined,
              caption: 'Pedidos en camino',
            ),
            DashboardKpiCard(
              label: 'Importe con entrega fallida',
              value: formatBs(metrics.failedValue),
              icon: Icons.report_gmailerrorred_outlined,
              accent: AppColors.danger,
              background: AppColors.dangerBackground,
              caption: 'No entregados',
            ),
          ],
        ),
        const SizedBox(height: 10),
        DashboardKpiGrid(
          columnsBuilder: (width) => width >= 760 ? 3 : 2,
          children: [
            DashboardKpiCard(
              label: 'Ventas entregadas hoy',
              value: formatBs(metrics.salesToday),
              icon: Icons.today_rounded,
              accent: AppColors.successText,
              background: AppColors.successBackground,
              caption: 'Por fecha real de entrega',
            ),
            DashboardKpiCard(
              label: 'Ventas del mes',
              value: formatBs(metrics.salesMonth),
              icon: Icons.calendar_month_outlined,
              accent: AppColors.successText,
              background: AppColors.successBackground,
              caption: 'Mes calendario en Bolivia',
            ),
            DashboardKpiCard(
              label: 'Ventas del trimestre',
              value: formatBs(metrics.salesQuarter),
              icon: Icons.date_range_outlined,
              accent: AppColors.successText,
              background: AppColors.successBackground,
              caption: 'Trimestre calendario en Bolivia',
            ),
          ],
        ),
        const SizedBox(height: 12),
        DashboardChartCard(
          title: 'Productos por importe',
          caption: 'Ranking sobre el valor histórico entregado',
          child: ProductAmountBars(products: metrics.topProductsByAmount),
        ),
        const SizedBox(height: 12),
        DashboardChartCard(
          title: 'Evolución del valor entregado',
          caption: 'Importes históricos de cada pedido entregado',
          child: DeliveredValueTrendChart(points: metrics.evolution),
        ),
        const SizedBox(height: 12),
        DashboardTwoColumns(
          first: DashboardChartCard(
            title: 'Comparación de los últimos 6 meses',
            caption: 'Valor entregado por mes',
            child: PeriodComparisonChart(points: metrics.comparison),
          ),
          second: DashboardChartCard(
            title: 'Participación por categoría',
            caption: 'Dona sobre el valor entregado',
            child: CategoryDonutChart(categories: metrics.categories),
          ),
        ),
        const SizedBox(height: 12),
        DashboardChartCard(
          title: 'Productos más vendidos',
          caption: 'Unidades entregadas e importe histórico',
          child: ProductUnitsBars(products: metrics.topProducts),
        ),
        const SizedBox(height: 14),
        DashboardInfoNote(
          text:
              'Los importes corresponden a pedidos entregados y usan los '
              'precios históricos registrados. No representan cobros: la app '
              'no gestiona pagos.',
        ),
        if (metrics.deliveredOrdersWithoutDetail > 0) ...[
          const SizedBox(height: 6),
          DashboardInfoNote(
            text:
                '${metrics.deliveredOrdersWithoutDetail} pedido(s) '
                'entregado(s) sin detalle de productos: se usa el total '
                'declarado en el pedido.',
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Logística
// ---------------------------------------------------------------------------

class _LogisticaTab extends StatelessWidget {
  const _LogisticaTab({
    required this.metrics,
    required this.loading,
    required this.ordersFailed,
    required this.rangeLabel,
    required this.orderCaption,
    required this.onOpenOrders,
    required this.onRetry,
  });

  final DashboardMetrics metrics;
  final bool loading;
  final bool ordersFailed;
  final String rangeLabel;
  final String Function(DashboardOrder) orderCaption;
  final _OpenOrders onOpenOrders;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const DashboardTabScroll(
        scrollKey: PageStorageKey('admin-dashboard-logistica'),
        children: [_LoadingBlock()],
      );
    }
    if (ordersFailed) {
      return DashboardTabScroll(
        scrollKey: const PageStorageKey('admin-dashboard-logistica'),
        children: [
          DashboardErrorSurface(
            message: 'No se pudieron cargar los pedidos.',
            onRetry: onRetry,
          ),
        ],
      );
    }

    final delivery = metrics.delivery;
    return DashboardTabScroll(
      scrollKey: const PageStorageKey('admin-dashboard-logistica'),
      children: [
        DashboardSectionTitle(
          title: 'Logística y entregas',
          caption: 'Actividad del período · $rangeLabel',
        ),
        const SizedBox(height: 10),
        DashboardKpiGrid(
          children: [
            DashboardKpiCard(
              label: 'Entregas exitosas',
              value: '${delivery.delivered}',
              icon: Icons.check_circle_outline_rounded,
              accent: AppColors.successText,
              background: AppColors.successBackground,
              caption: 'Ver entregadas',
              onTap: () => onOpenOrders(
                status: OrderStatus.entregado,
                range: metrics.period,
                byDelivery: true,
              ),
            ),
            DashboardKpiCard(
              label: 'Entregas fallidas',
              value: '${delivery.failed}',
              icon: Icons.report_problem_outlined,
              accent: AppColors.danger,
              background: AppColors.dangerBackground,
              caption: 'Revisar incidencias',
              onTap: () => onOpenOrders(
                status: OrderStatus.fallida,
                range: metrics.period,
                byDelivery: true,
              ),
            ),
            DashboardKpiCard(
              label: 'Tasa de éxito',
              value: formatPercent(delivery.successRate),
              icon: Icons.trending_up_rounded,
              accent: delivery.successRate == null
                  ? AppColors.muted
                  : AppColors.successText,
              background: delivery.successRate == null
                  ? AppColors.background
                  : AppColors.successBackground,
              caption: delivery.successRate == null
                  ? 'Sin entregas finalizadas'
                  : 'Exitosas / finalizadas',
            ),
            DashboardKpiCard(
              label: 'Tiempo promedio',
              value: formatAverageTime(delivery.averageMinutes),
              icon: Icons.timer_outlined,
              accent: AppColors.approvedText,
              background: AppColors.approvedBackground,
              caption: delivery.averageSamples == 0
                  ? 'Faltan fechas de entrega'
                  : '${delivery.averageSamples} muestra(s)',
            ),
            DashboardKpiCard(
              label: 'Pendientes de asignación',
              value: '${metrics.approved}',
              icon: Icons.pending_actions_outlined,
              accent: AppColors.approvedText,
              background: AppColors.approvedBackground,
              caption: 'Aprobados sin repartidor',
              onTap: () => onOpenOrders(status: OrderStatus.aprobado),
            ),
            DashboardKpiCard(
              label: 'En ruta ahora',
              value: '${metrics.inTransit}',
              icon: Icons.route_outlined,
              caption: 'Seguimiento activo',
              onTap: () => onOpenOrders(status: OrderStatus.enRuta),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DashboardTwoColumns(
          first: DashboardChartCard(
            title: 'Entregas por repartidor',
            caption: 'Exitosas frente a fallidas',
            child: DriverPerformanceChart(drivers: metrics.drivers),
          ),
          second: DashboardChartCard(
            title: 'Resultado de entregas',
            caption: 'Solo entregas finalizadas',
            child: DeliveryOutcomeDonut(delivery: delivery),
          ),
        ),
        const SizedBox(height: 12),
        DashboardTwoColumns(
          first: DashboardChartCard(
            title: 'Evolución del tiempo de entrega',
            caption: 'Promedio por intervalo del período',
            child: DeliveryTimeTrendChart(
              points: metrics.deliveryTimeEvolution,
            ),
          ),
          second: DashboardChartCard(
            title: 'Actividad por repartidor',
            caption: 'Asignados, en ruta y finalizados',
            child: DriverActivityList(drivers: metrics.drivers),
          ),
        ),
        const SizedBox(height: 12),
        _RecentOrdersCard(
          orders: metrics.recentOrders,
          captionOf: orderCaption,
          onOpenAll: () => onOpenOrders(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inventario
// ---------------------------------------------------------------------------

class _InventarioTab extends StatelessWidget {
  const _InventarioTab({
    required this.metrics,
    required this.inventory,
    required this.viewModel,
    required this.onOpenInventory,
  });

  final DashboardMetrics metrics;
  final DashboardInventory inventory;
  final AdminDashboardViewModel viewModel;
  final ValueChanged<InventoryFilter> onOpenInventory;

  @override
  Widget build(BuildContext context) {
    final unavailable = inventory.isUnavailable;
    final loading = inventory.isLoading;
    String valueOf(int count) => loading || unavailable ? '—' : '$count';

    return DashboardTabScroll(
      scrollKey: const PageStorageKey('admin-dashboard-inventario'),
      children: [
        DashboardInventorySourceBanner(
          inventory: inventory,
          refreshing: viewModel.loadingInventory,
          onRefresh: viewModel.loadInventory,
        ),
        const SizedBox(height: 12),
        DashboardSectionTitle(
          title: 'Inventario y vencimientos',
          caption: inventory.isRemote
              ? 'Stock útil calculado desde lotes_productos'
              : (inventory.isLocal
                    ? 'Stock de demostración del catálogo local'
                    : 'Sin datos de inventario disponibles'),
          action: TextButton(
            onPressed: () => onOpenInventory(InventoryFilter.todos),
            child: const Text('Ver inventario'),
          ),
        ),
        const SizedBox(height: 10),
        DashboardKpiGrid(
          columnsBuilder: (width) => width >= 760 ? 4 : 2,
          children: [
            DashboardKpiCard(
              label: 'Productos agotados',
              value: valueOf(metrics.inventory.outOfStock),
              icon: Icons.remove_shopping_cart_outlined,
              accent: AppColors.danger,
              background: AppColors.dangerBackground,
              caption: 'Ver agotados',
              onTap: unavailable || loading
                  ? null
                  : () => onOpenInventory(InventoryFilter.agotados),
            ),
            DashboardKpiCard(
              label: 'Stock bajo',
              value: valueOf(metrics.inventory.lowStock),
              icon: Icons.warning_amber_rounded,
              accent: AppColors.pendingText,
              background: AppColors.pendingBackground,
              caption: 'Ver stock bajo',
              onTap: unavailable || loading
                  ? null
                  : () => onOpenInventory(InventoryFilter.bajo),
            ),
            DashboardKpiCard(
              label: 'Lotes vencidos',
              value: valueOf(metrics.inventory.expiredLots),
              icon: Icons.event_busy_rounded,
              accent: AppColors.danger,
              background: AppColors.dangerBackground,
              caption: metrics.inventory.hasLotData
                  ? '${metrics.inventory.expiredUnits} u. excluidas'
                  : 'Sin datos de lotes',
              onTap: unavailable || loading
                  ? null
                  : () => onOpenInventory(InventoryFilter.vencidos),
            ),
            DashboardKpiCard(
              label: 'Por vencer (90 d)',
              value: valueOf(metrics.inventory.expiringLots),
              icon: Icons.schedule_rounded,
              accent: AppColors.pendingText,
              background: AppColors.pendingBackground,
              caption: metrics.inventory.hasLotData
                  ? '${metrics.inventory.expiring30} en ≤30 d'
                  : 'Sin datos de lotes',
              onTap: unavailable || loading
                  ? null
                  : () => onOpenInventory(InventoryFilter.porVencer),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          const _LoadingBlock()
        else if (unavailable)
          DashboardSurface(
            child: DashboardEmptyText(
              icon: Icons.cloud_off_outlined,
              text:
                  'No se muestran ceros porque la consulta de inventario no '
                  'se completó. Revisa la conexión, la sesión o las reglas de '
                  'Firestore y vuelve a intentarlo.',
            ),
          )
        else ...[
          DashboardTwoColumns(
            first: DashboardChartCard(
              title: 'Vencimientos',
              caption: 'Lotes en intervalos excluyentes',
              child: ExpiryDistributionChart(metrics: metrics.inventory),
            ),
            second: DashboardChartCard(
              title: 'Stock crítico',
              caption: 'Existencias frente al umbral',
              child: CriticalStockBars(products: inventory.products),
            ),
          ),
          const SizedBox(height: 12),
          DashboardSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardCardHeader(
                  title: 'Productos que requieren reposición',
                  caption:
                      'Máximo 5 productos · toca para ver el inventario '
                      'filtrado',
                  action: TextButton(
                    onPressed: () => onOpenInventory(InventoryFilter.todos),
                    child: const Text('Ver todos'),
                  ),
                ),
                const SizedBox(height: 8),
                CriticalStockList(
                  products: inventory.products,
                  onOpen: onOpenInventory,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        DashboardInfoNote(
          text:
              'El stock útil se calcula exclusivamente desde los lotes de '
              'lotes_productos y excluye los vencidos. Los lotes sin '
              'requiere_vencimiento no entran en los vencimientos. Umbral de '
              'stock bajo: ${viewModel.lowStockThreshold} unidades.',
        ),
        if (inventory.note != null && !unavailable) ...[
          const SizedBox(height: 6),
          DashboardInfoNote(text: inventory.note!),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas compartidas
// ---------------------------------------------------------------------------

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.alerts, required this.onOpen});

  final List<DashboardAlert> alerts;
  final ValueChanged<DashboardAlert> onOpen;

  @override
  Widget build(BuildContext context) {
    final visible = alerts.take(4).toList();
    return DashboardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DashboardCardHeader(
                  title: 'Alertas accionables',
                  caption: 'Toca una alerta para revisar el detalle',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: alerts.isEmpty
                      ? AppColors.successBackground
                      : AppColors.dangerBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  alerts.isEmpty ? 'Sin alertas' : '${alerts.length}',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: alerts.isEmpty
                        ? AppColors.successText
                        : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            const DashboardEmptyText(
              icon: Icons.verified_outlined,
              text:
                  'Sin alertas: pedidos e inventario dentro de los '
                  'parámetros configurados.',
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              DashboardAlertTile(
                alert: visible[i],
                onTap: () => onOpen(visible[i]),
              ),
              if (i < visible.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({
    required this.orders,
    required this.captionOf,
    required this.onOpenAll,
  });

  final List<DashboardOrder> orders;
  final String Function(DashboardOrder) captionOf;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return DashboardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: 'Actividad reciente',
            caption: 'Últimos pedidos registrados',
            action: TextButton(
              onPressed: onOpenAll,
              child: const Text('Ver todos'),
            ),
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            const DashboardEmptyText(
              icon: Icons.receipt_long_outlined,
              text: 'Aún no hay pedidos recientes.',
            )
          else
            for (var i = 0; i < orders.length; i++) ...[
              DashboardOrderTile(
                order: orders[i],
                caption: captionOf(orders[i]),
                onTap: () =>
                    showDashboardOrderDetail(context, order: orders[i]),
              ),
              if (i < orders.length - 1) const SizedBox(height: 11),
            ],
        ],
      ),
    );
  }
}

/// Lista compacta y navegable de productos por debajo del umbral.
class CriticalStockList extends StatelessWidget {
  const CriticalStockList({
    super.key,
    required this.products,
    required this.onOpen,
  });

  final List<DashboardProductStock> products;
  final ValueChanged<InventoryFilter> onOpen;

  @override
  Widget build(BuildContext context) {
    final critical =
        products.where((product) => product.needsAttention).toList()
          ..sort((a, b) => a.thresholdRatio.compareTo(b.thresholdRatio));
    if (critical.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.check_circle_outline_rounded,
        text: 'Sin productos por debajo del umbral de stock.',
      );
    }
    final visible = critical.take(5).toList();
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _CriticalStockRow(
            product: visible[i],
            onTap: () => onOpen(
              visible[i].level == StockLevel.agotado
                  ? InventoryFilter.agotados
                  : InventoryFilter.bajo,
            ),
          ),
          if (i < visible.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CriticalStockRow extends StatelessWidget {
  const _CriticalStockRow({required this.product, required this.onTap});

  final DashboardProductStock product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = product.level == StockLevel.agotado;
    final color = out ? AppColors.danger : AppColors.pendingText;
    final background = out
        ? AppColors.dangerBackground
        : AppColors.pendingBackground;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  out
                      ? Icons.remove_shopping_cart_outlined
                      : Icons.warning_amber_rounded,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.category} · ${product.lotCount} lote(s)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${product.usable} / ${product.threshold} u.',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
