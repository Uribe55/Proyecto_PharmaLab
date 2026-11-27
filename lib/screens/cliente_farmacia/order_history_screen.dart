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
  const OrderHistoryScreen({super.key, required this.onBrowse, this.viewModel});

  final VoidCallback onBrowse;
  final OrderHistoryViewModel? viewModel;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _filter = 'all';
  late final _history = widget.viewModel ?? OrderHistoryViewModel();

  @override
  void dispose() {
    if (widget.viewModel == null) _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _history,
      builder: (context, _) {
        final allOrders = _history.orders;
        final orders = OrderHistoryViewModel.selectOrders(allOrders, _filter);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const ClientTabHeader(title: 'Mis pedidos'),
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
                            for (final entry in const {
                              'all': 'Todos',
                              'active': 'Activos',
                              'history': 'Historial',
                              'pendiente': 'Pendientes',
                              'aprobado': 'Aprobados',
                              'enRuta': 'En ruta',
                              'entregado': 'Entregados',
                              'fallida': 'Fallidos',
                              'cancelado': 'Cancelados',
                              'reprogramado': 'Reprogramados',
                            }.entries)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _HistoryFilter(
                                  label: entry.value,
                                  selected: _filter == entry.key,
                                  onTap: () =>
                                      setState(() => _filter = entry.key),
                                ),
                              ),
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
                      if (_history.error != null && orders.isNotEmpty)
                        const Text(
                          'Se muestra la última información recibida; puede estar desactualizada.',
                          style: AppText.meta,
                        ),
                      if (_history.error != null)
                        TextButton(
                          onPressed: _history.retry,
                          child: const Text('Reintentar consulta'),
                        ),
                      if (PharmaService.instance.usesFirebase)
                        Text(
                          'Pedidos de tu farmacia cargados: ${allOrders.length}.',
                          style: AppText.meta,
                        ),
                      if (orders.any((order) => order.fromCache))
                        const Text(
                          'Datos guardados en este dispositivo; pueden estar desactualizados.',
                          style: AppText.meta,
                        ),
                      if (orders.isEmpty &&
                          !_history.loading &&
                          _history.error == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Sin pedidos por aquí',
                            description: _filter == 'all'
                                ? 'Todavía no realizaste ningún pedido. '
                                      'Explora el catálogo para comenzar.'
                                : _history.canLoadMore
                                ? 'No hay coincidencias en los pedidos cargados. Carga más para buscar pedidos anteriores.'
                                : 'No hay pedidos en la categoría seleccionada.',
                            action: OutlinedButton(
                              onPressed: widget.onBrowse,
                              child: const Text('Explorar catálogo'),
                            ),
                          ),
                        ),
                      if (orders.isNotEmpty)
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
                      if (_history.canLoadMore)
                        OutlinedButton(
                          onPressed: _history.loading
                              ? null
                              : _history.loadMore,
                          child: const Text('Cargar más pedidos'),
                        ),
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
                order.createdAtKnown
                    ? formatOrderDate(order.createdAt)
                    : 'Fecha no registrada',
                style: AppText.meta.copyWith(fontSize: 10.5),
              ),
              const SizedBox(height: 8),
              Text(order.status.description, style: AppText.meta),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.items.isEmpty
                          ? 'Productos: ver detalle'
                          : '${order.items.map((line) => line.productId).toSet().length} productos diferentes',
                      style: AppText.meta.copyWith(fontSize: 10.5),
                    ),
                  ),
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onTap,
                  child: Text(
                    order.status.isFinal ? 'Ver detalle' : 'Seguir pedido',
                  ),
                ),
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
