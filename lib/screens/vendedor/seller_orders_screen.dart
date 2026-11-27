import '../../widgets/admin_scroll_layout.dart';
import '../../widgets/staff_filter_chip.dart';

import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../domain/seller_order_list.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_detail_sheet.dart';
import '../../widgets/order_list_tile.dart';
import '../../widgets/stat_card.dart';
import 'seller_assign_screen.dart';
import 'seller_reschedule_screen.dart';
import 'seller_review_screen.dart';

/// Panel de pedidos del vendedor (RF-10).
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  OrderStatus? _filter;

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
    if (order.needsReschedule) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SellerRescheduleScreen(order: order)),
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
        final orders = sellerOrderList(service.orders, status: _filter);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: AdminScrollLayout(
              header: AppTabHeader(title: 'Panel de pedidos', showLogo: true),
              body: AdminScrollList(
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
                        for (final filter in <OrderStatus?>[
                          null,
                          ...OrderStatus.values,
                        ]) ...[
                          StaffFilterChip(
                            label: orderFilterLabel(filter),
                            selected: _filter == filter,
                            onTap: () => setState(() => _filter = filter),
                          ),
                          if (filter != OrderStatus.values.last)
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
                          onPressed: () => setState(() => _filter = null),
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
          ),
        );
      },
    );
  }

  String _captionFor(PharmacyOrder order) {
    if (order.status == OrderStatus.cancelado) {
      return 'Cancelado · ${order.cancellationReason ?? ''}';
    }
    if (order.isPending) return 'Esperando revisión y aprobación';
    if (order.isApproved) return 'Aprobado · pendiente de asignación';
    if (order.isInTransit) {
      return 'En ruta · ${order.driverName ?? 'sin repartidor'}';
    }
    if (order.needsReschedule) {
      return 'Reprogramado · ${order.failureReason ?? 'asignar nueva fecha'}';
    }
    if (order.isApproved && order.scheduledFor != null) {
      return 'Aprobado · entrega ${_shortDate(order.scheduledFor!)}';
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
