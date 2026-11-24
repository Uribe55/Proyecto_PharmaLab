import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../viewmodels/order_history_view_model.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/client_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  OrderStatus? _filter;
  late final _history = OrderHistoryViewModel();

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _history,
      builder: (context, _) {
        final allOrders = _history.orders;
        final orders = _filter == null
            ? allOrders
            : allOrders.where((order) => order.status == _filter).toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const ClientTabHeader(title: 'Historial de pedidos'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    children: [
                      const Text(
                        'TUS COMPRAS, EN UN LUGAR',
                        style: AppText.eyebrow,
                      ),
                      const SizedBox(height: 8),
                      const Text('Cada pedido, a la vista.', style: AppText.h1),
                      const SizedBox(height: 6),
                      const Text(
                        'Consulta el estado y los detalles de cada pedido.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _HistoryFilter(
                              label: 'Todos',
                              selected: _filter == null,
                              onTap: () => setState(() => _filter = null),
                            ),
                            for (final status in OrderStatus.values) ...[
                              const SizedBox(width: 8),
                              _HistoryFilter(
                                label: status.label,
                                selected: _filter == status,
                                onTap: () => setState(() => _filter = status),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pedidos recientes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.h3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${orders.length} '
                            '${orders.length == 1 ? 'resultado' : 'resultados'}',
                            style: AppText.meta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_history.loading)
                        const Center(child: CircularProgressIndicator()),
                      if (_history.error != null)
                        Text(_history.error!, style: AppText.muted),
                      if (PharmaService.instance.usesFirebase)
                        const Text(
                          'Últimos 50 pedidos de tu farmacia.',
                          style: AppText.meta,
                        ),
                      if (orders.any((order) => order.fromCache))
                        const Text(
                          'Datos guardados en este dispositivo; pueden estar desactualizados.',
                          style: AppText.meta,
                        ),
                      if (orders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Sin pedidos por aquí',
                            description: _filter == null
                                ? 'Todavía no realizaste ningún pedido. '
                                      'Explora el catálogo para comenzar.'
                                : 'No tienes pedidos con el estado '
                                      '“${_filter!.label}”.',
                            action: OutlinedButton(
                              onPressed: widget.onBrowse,
                              child: const Text('Explorar catálogo'),
                            ),
                          ),
                        )
                      else
                        for (final order in orders) ...[
                          _OrderCard(
                            order: order,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderTrackingScreen(order: order),
                                ),
                              );
                            },
                          ),
                          if (order != orders.last) const SizedBox(height: 12),
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
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final PharmacyOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.number,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  StatusChip(status: order.status, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.pharmacyName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatOrderDate(order.createdAt),
                style: AppText.meta.copyWith(fontSize: 10.5),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${order.items.length} '
                    '${order.items.length == 1 ? 'producto' : 'productos'}',
                    style: AppText.meta.copyWith(fontSize: 10.5),
                  ),
                  const Spacer(),
                  Text(
                    formatBs(order.total),
                    style: AppText.h3.copyWith(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter({
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
