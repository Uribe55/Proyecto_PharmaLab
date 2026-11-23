import 'package:flutter/material.dart';

import '../../models/dashboard_models.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/admin_dashboard_viewmodel.dart';
import '../../widgets/app_header.dart';
import '../../widgets/dashboard/dashboard_alerts.dart';
import '../../widgets/dashboard/dashboard_order_detail.dart';
import '../../widgets/empty_state.dart';

/// Listado administrativo de pedidos con filtros por estado y período.
///
/// Es una vista de supervisión de solo lectura: no duplica las acciones de
/// aprobación del vendedor ni las de entrega del repartidor.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({
    super.key,
    required this.viewModel,
    this.embedded = false,
    this.initialStatus,
    this.dateRange,
    this.rangeLabel,
    this.filterByDeliveryDate = false,
    this.attentionOnly = false,
  });

  final AdminDashboardViewModel viewModel;
  final bool embedded;
  final OrderStatus? initialStatus;
  final DateRange? dateRange;
  final String? rangeLabel;
  final bool filterByDeliveryDate;
  final bool attentionOnly;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late OrderStatus? _status = widget.initialStatus;
  late DateRange? _range = widget.dateRange;
  late bool _byDelivery = widget.filterByDeliveryDate;
  late bool _attentionOnly = widget.attentionOnly;

  void _clearFilters() {
    setState(() {
      _status = null;
      _range = null;
      _byDelivery = false;
      _attentionOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        final orders = vm.orders.where((order) {
          if (order.cancelled) return false;
          if (_status != null && order.status != _status) return false;
          if (_attentionOnly) {
            final stalled =
                (order.isPending || order.isApproved) &&
                order.createdAt != null &&
                order.createdAt!.isBefore(cutoff);
            if (!stalled) return false;
          }
          if (_range != null) {
            final date = _byDelivery
                ? (order.completionDate ?? order.createdAt)
                : order.createdAt;
            if (date == null || !_range!.contains(date)) return false;
          }
          return true;
        }).toList();

        return Scaffold(
          appBar: widget.embedded ? null : AppPageAppBar(title: 'Pedidos'),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (widget.embedded) const AppTabHeader(title: 'Pedidos'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const Text(
                        'SUPERVISIÓN DE PEDIDOS',
                        style: AppText.eyebrow,
                      ),
                      const SizedBox(height: 7),
                      const Text('Pedidos de farmacias.', style: AppText.h1),
                      const SizedBox(height: 6),
                      const Text(
                        'Consulta el estado de todos los pedidos y los '
                        'importes históricos registrados.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 16),
                      if (vm.ordersError != null)
                        DashboardErrorSurface(
                          message: vm.ordersError!,
                          onRetry: vm.refresh,
                        ),
                      if (vm.ordersError != null) const SizedBox(height: 12),
                      if (_range != null || _attentionOnly) ...[
                        _FilterBanner(
                          label: _attentionOnly
                              ? 'Pedidos con más de 24 h sin avanzar'
                              : '${_byDelivery ? 'Entrega' : 'Creación'}: '
                                    '${widget.rangeLabel ?? 'rango seleccionado'}',
                          onClear: _clearFilters,
                        ),
                        const SizedBox(height: 12),
                      ],
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StatusChip(
                              label: 'Todos',
                              selected: _status == null,
                              onTap: () => setState(() => _status = null),
                            ),
                            for (final status in OrderStatus.values) ...[
                              const SizedBox(width: 8),
                              _StatusChip(
                                label: status.label,
                                selected: _status == status,
                                onTap: () => setState(() => _status = status),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Resultados', style: AppText.h3),
                          ),
                          Text(
                            '${orders.length} '
                            '${orders.length == 1 ? 'pedido' : 'pedidos'}',
                            style: AppText.meta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (vm.loadingOrders)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (orders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Sin pedidos en esta vista',
                            description:
                                'No hay pedidos que coincidan con el estado o '
                                'el período seleccionado.',
                            action: OutlinedButton(
                              onPressed: _clearFilters,
                              child: const Text('Limpiar filtros'),
                            ),
                          ),
                        )
                      else
                        for (final order in orders) ...[
                          DashboardOrderTile(
                            order: order,
                            caption: _caption(order),
                            onTap: () =>
                                showDashboardOrderDetail(context, order: order),
                          ),
                          if (order != orders.last) const SizedBox(height: 11),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _caption(DashboardOrder order) {
    if (order.createdAt == null) return 'Sin fecha registrada';
    final created = _shortDate(order.createdAt!);
    if (order.isDelivered && order.deliveredAt != null) {
      return 'Creado $created · entregado ${_shortDate(order.deliveredAt!)}';
    }
    if (order.isFailure) {
      return 'Creado $created · entrega fallida';
    }
    if (order.driverName != null && order.driverName!.isNotEmpty) {
      return 'Creado $created · ${order.driverName}';
    }
    return 'Creado $created';
  }

  String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }
}

class _FilterBanner extends StatelessWidget {
  const _FilterBanner({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_alt_outlined,
            size: 17,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
