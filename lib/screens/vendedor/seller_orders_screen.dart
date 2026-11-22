import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_detail_sheet.dart';
import '../../widgets/order_list_tile.dart';
import '../../widgets/stat_card.dart';
import 'seller_assign_screen.dart';
import 'seller_review_screen.dart';

/// Panel de pedidos del vendedor (RF-10).
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

enum _SellerFilter {
  todos('Todos'),
  pendientes('Pendientes'),
  porAsignar('Por asignar'),
  enRuta('En ruta'),
  finalizados('Finalizados');

  const _SellerFilter(this.label);

  final String label;

  bool matches(PharmacyOrder order) {
    return switch (this) {
      _SellerFilter.todos => true,
      _SellerFilter.pendientes => order.isPending,
      _SellerFilter.porAsignar => order.isApproved,
      _SellerFilter.enRuta => order.isInTransit,
      _SellerFilter.finalizados => order.status.isFinal,
    };
  }
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  _SellerFilter _filter = _SellerFilter.todos;

  void _openOrder(PharmacyOrder order) {
    if (order.isPending) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SellerReviewScreen(order: order)),
      );
      return;
    }
    if (order.canAssignDriver) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SellerAssignScreen(order: order)),
      );
      return;
    }
    showOrderDetailSheet(context, order: order);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final service = PharmaService.instance;
        final orders = service.orders.where(_filter.matches).toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const AppTabHeader(title: 'Panel de pedidos'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const Text('GESTIÓN DE PEDIDOS', style: AppText.eyebrow),
                      const SizedBox(height: 7),
                      const Text('Pedidos de farmacias.', style: AppText.h1),
                      const SizedBox(height: 6),
                      const Text(
                        'Revisa, aprueba y asigna cada pedido al repartidor '
                        'adecuado.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Pendientes de revisión',
                              value: '${service.pendingOrdersCount}',
                              icon: Icons.hourglass_top_rounded,
                              accent: AppColors.pendingText,
                              background: AppColors.pendingBackground,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: StatCard(
                              label: 'Por asignar',
                              value: '${service.approvedOrders.length}',
                              icon: Icons.assignment_outlined,
                              accent: AppColors.approvedText,
                              background: AppColors.approvedBackground,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: StatCard(
                              label: 'En ruta',
                              value: '${service.inTransitOrders}',
                              icon: Icons.local_shipping_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in _SellerFilter.values) ...[
                              _FilterChip(
                                label: filter.label,
                                selected: _filter == filter,
                                onTap: () => setState(() => _filter = filter),
                              ),
                              if (filter != _SellerFilter.values.last)
                                const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Text('Pedidos', style: AppText.h3)),
                          Text(
                            '${orders.length} '
                            '${orders.length == 1 ? 'resultado' : 'resultados'}',
                            style: AppText.meta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (orders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 26),
                          child: EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Sin pedidos en esta vista',
                            description:
                                'No hay pedidos con el filtro seleccionado. '
                                'Prueba con “Todos” para ver el resto.',
                            action: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _filter = _SellerFilter.todos),
                              child: const Text('Ver todos los pedidos'),
                            ),
                          ),
                        )
                      else
                        for (final order in orders) ...[
                          OrderListTile(
                            order: order,
                            onTap: () => _openOrder(order),
                            caption: _captionFor(order),
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

  String _captionFor(PharmacyOrder order) {
    if (order.isPending) return 'Esperando revisión y aprobación';
    if (order.isApproved) return 'Aprobado · pendiente de asignación';
    if (order.isInTransit) {
      return 'En ruta · ${order.driverName ?? 'sin repartidor'}';
    }
    if (order.status.isFailure) {
      return 'Entrega fallida · ${order.failureReason ?? 'sin detalle'}';
    }
    return 'Entregado ${order.deliveredAt != null ? 'el ${_shortDate(order.deliveredAt!)}' : ''}'
        .trim();
  }

  String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
