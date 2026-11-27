import '../../widgets/admin_scroll_layout.dart';
import '../../widgets/remote_cancellation_panel.dart';
import '../../widgets/staff_filter_chip.dart';
import '../shared/remote_logistics_screen.dart';

import 'package:flutter/material.dart';

import '../../data/repositories/staff_order_repository.dart';
import '../../domain/spark_approval.dart';
import '../../domain/seller_order_list.dart';
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
  OrderStatus? _status;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final orders = sellerOrderList(vm.orders, status: _status);
      return Scaffold(
        body: SafeArea(
          child: AdminScrollLayout(
            header: AppTabHeader(title: 'Pedidos reales', showLogo: true),
            body: AdminScrollList(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('GESTIÓN DE PEDIDOS', style: AppText.eyebrow),
                const SizedBox(height: 7),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final status in <OrderStatus?>[
                        null,
                        ...OrderStatus.values,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: StaffFilterChip(
                            label: orderFilterLabel(status),
                            selected: _status == status,
                            onTap: () => setState(() => _status = status),
                          ),
                        ),
                    ],
                  ),
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
                        : order.createdAtKnown
                        ? 'Registrado en Firestore'
                        : 'Fecha no disponible',
                  ),
                ],
              ],
            ),
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
  bool _busy = false, _approved = false;
  String? _error;
  Future<void> _approve() async {
    if (_busy || _approved || !widget.repository.approvalEnabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.approve(widget.order.documentId!);
      if (!mounted) return;
      setState(() => _approved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido aprobado y registrado en Firestore.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo aprobar. Revisa los permisos y el estado actual. Actualiza el seguimiento antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                  RemoteCancellationPanel(order: order),
                  if (order.isApproved && order.deliveryId == null)
                    OutlinedButton(
                      onPressed: order.fromCache
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    RemoteLogisticsScreen(order: order),
                              ),
                            ),
                      child: const Text('ASIGNAR REPARTIDOR'),
                    ),
                  const SizedBox(height: 16),
                  OrderLifecyclePanel(order: order, showActions: false),
                  const SizedBox(height: 16),
                  if (!widget.repository.approvalEnabled)
                    const Text(SparkApproval.blockedReason),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                        widget.repository.approvalEnabled &&
                            order.isPending &&
                            !order.fromCache &&
                            !_busy &&
                            !_approved &&
                            !snapshot.hasError
                        ? _approve
                        : null,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _approved || order.isApproved
                                ? 'Pedido aprobado'
                                : 'Aprobar pedido',
                          ),
                  ),
                ],
              ),
      );
    },
  );
}
