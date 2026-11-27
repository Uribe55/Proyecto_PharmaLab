import 'package:flutter/material.dart';

import '../data/datasources/order_gateway.dart';
import '../models/order.dart';
import '../services/firebase_environment.dart';
import '../services/pharma_service.dart';

class RemoteCancellationPanel extends StatefulWidget {
  const RemoteCancellationPanel({super.key, required this.order});
  final PharmacyOrder order;
  @override
  State<RemoteCancellationPanel> createState() =>
      _RemoteCancellationPanelState();
}

class _RemoteCancellationPanelState extends State<RemoteCancellationPanel> {
  bool busy = false;
  String? error;
  Future<void> _act(String action) async {
    if (busy) return;
    final controller = TextEditingController();
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelación del pedido'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    final accepted = await Navigator.of(context).push(route);
    final reason = controller.text.trim();
    await route.completed;
    controller.dispose();
    if (!mounted || accepted != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await OrderGateway().call('cancelOrder', {
        'orderId': widget.order.documentId,
        'action': action,
        'reason': reason,
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order, user = PharmaService.instance.currentUser;
    if (!FirebaseEnvironment.multiOrdersEnabled ||
        order.schemaVersion != 'transactional_multi_v1' ||
        user == null) {
      return const SizedBox.shrink();
    }
    final own = user.role.name == 'cliente' && order.customerId == user.id;
    final staff = ['vendedor', 'administrador'].contains(user.role.name);
    final pending = order.pendingCancellation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pending != null)
          Text('Solicitud de cancelación: ${pending.reason}'),
        if (own && (order.isPending || (order.isApproved && pending == null)))
          TextButton(
            onPressed: busy || order.fromCache
                ? null
                : () =>
                      _act(order.isPending ? 'cancel' : 'requestCancellation'),
            child: Text(
              order.isPending ? 'Cancelar pedido' : 'Solicitar cancelación',
            ),
          ),
        if (staff && order.isApproved && pending != null)
          Wrap(
            children: [
              TextButton(
                onPressed: busy || order.fromCache
                    ? null
                    : () => _act('acceptCancellation'),
                child: const Text('Aceptar cancelación'),
              ),
              TextButton(
                onPressed: busy || order.fromCache
                    ? null
                    : () => _act('rejectCancellation'),
                child: const Text('Rechazar cancelación'),
              ),
            ],
          ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
      ],
    );
  }
}
