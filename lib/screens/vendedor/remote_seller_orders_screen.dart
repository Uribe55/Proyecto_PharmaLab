import 'package:flutter/material.dart';

import '../../data/repositories/staff_order_repository.dart';
import '../../domain/spark_approval.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/seller_orders_view_model.dart';
import '../../widgets/app_header.dart';
import '../../widgets/order_detail_card.dart';
import '../../widgets/order_lifecycle_panel.dart';
import '../../widgets/order_list_tile.dart';

class RemoteSellerOrdersScreen extends StatefulWidget {
  const RemoteSellerOrdersScreen({super.key, required this.viewModel});
  final SellerOrdersViewModel viewModel;
  @override
  State<RemoteSellerOrdersScreen> createState() =>
      _RemoteSellerOrdersScreenState();
}

class _RemoteSellerOrdersScreenState extends State<RemoteSellerOrdersScreen> {
  bool _pendingOnly = true;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final orders = vm.orders
          .where((order) => !_pendingOnly || order.isPending)
          .toList();
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const AppTabHeader(title: 'Pedidos reales', showLogo: true),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Pendientes: ${vm.loading || vm.error != null ? '—' : vm.pendingCount}',
                      style: AppText.h1,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Los pedidos se actualizan mientras la aplicación está abierta.',
                      style: AppText.muted,
                    ),
                    if (vm.fromCache)
                      const Text(
                        'Datos guardados. Esperando confirmación del servidor.',
                      ),
                    if (vm.loading) const LinearProgressIndicator(),
                    if (vm.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        vm.error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        ChoiceChip(
                          label: const Text('Pendientes'),
                          selected: _pendingOnly,
                          onSelected: (_) =>
                              setState(() => _pendingOnly = true),
                        ),
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: !_pendingOnly,
                          onSelected: (_) =>
                              setState(() => _pendingOnly = false),
                        ),
                      ],
                    ),
                    if (!vm.loading && vm.error == null && orders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No hay pedidos en esta vista.'),
                      ),
                    for (final order in orders) ...[
                      const SizedBox(height: 12),
                      OrderListTile(
                        order: order,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RemoteSellerOrderDetailScreen(
                              order: order,
                              repository: vm.repository,
                            ),
                          ),
                        ),
                        caption: order.fromCache
                            ? 'Información guardada'
                            : 'Registrado en Firestore',
                      ),
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

class RemoteSellerOrderDetailScreen extends StatefulWidget {
  const RemoteSellerOrderDetailScreen({
    super.key,
    required this.order,
    required this.repository,
  });
  final PharmacyOrder order;
  final StaffOrderRepository repository;
  @override
  State<RemoteSellerOrderDetailScreen> createState() =>
      _RemoteSellerOrderDetailScreenState();
}

class _RemoteSellerOrderDetailScreenState
    extends State<RemoteSellerOrderDetailScreen> {
  late final Stream<PharmacyOrder> _stream = widget.repository.watchOrder(
    widget.order.documentId!,
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<PharmacyOrder>(
    stream: _stream,
    builder: (context, snapshot) {
      final order = snapshot.data ?? widget.order;
      return Scaffold(
        appBar: const AppPageAppBar(title: 'Revisar pedido real'),
        body: snapshot.hasError
            ? const Center(
                child: Text(
                  'No se puede consultar este pedido. Revisa tu sesión y permisos.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(order.number, style: AppText.h1),
                  Text(order.status.label, style: AppText.h3),
                  if (order.fromCache)
                    const Text(
                      'Información guardada; pendiente de actualizar.',
                    ),
                  const SizedBox(height: 16),
                  OrderDetailCard(order: order),
                  const SizedBox(height: 16),
                  OrderLifecyclePanel(order: order, showActions: false),
                  const SizedBox(height: 16),
                  const Text(SparkApproval.blockedReason),
                  const SizedBox(height: 12),
                  const ElevatedButton(
                    onPressed: null,
                    child: Text('Aprobación real no habilitada'),
                  ),
                ],
              ),
      );
    },
  );
}
