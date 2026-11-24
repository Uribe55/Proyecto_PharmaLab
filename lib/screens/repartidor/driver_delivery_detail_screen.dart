import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../domain/order_policy.dart';
import '../../viewmodels/delivery_view_model.dart';
import '../../widgets/order_lifecycle_panel.dart';
import '../../services/pharma_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/order_detail_card.dart';
import 'driver_failure_screen.dart';

/// Detalle de una entrega asignada (RF-14) con acciones de cierre.
class DriverDeliveryDetailScreen extends StatelessWidget {
  const DriverDeliveryDetailScreen({super.key, required this.order});

  final PharmacyOrder order;

  Future<void> _confirmDelivery(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: Text(
          '¿Confirmas que entregaste el pedido ${order.number} en '
          '${order.pharmacyName}?',
          style: AppText.muted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, entregado'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final sync = SyncService.instance;
    final delivery = DeliveryViewModel.instance;
    final delivered = delivery.deliver(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delivered
              ? sync.isOffline
                    ? 'Entrega registrada sin conexión. Se sincronizará al reconectar.'
                    : 'Pedido ${order.number} entregado.'
              : delivery.error ?? 'No se pudo actualizar el pedido.',
        ),
      ),
    );
    if (!delivered) return;
    Navigator.of(context).pop();
  }

  void _reportFailure(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DriverFailureScreen(order: order)),
    );
  }

  Future<void> _discard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deshacer registro'),
        content: const Text(
          'Se eliminará la entrega guardada sin conexión. El pedido seguirá '
          'en ruta.',
          style: AppText.muted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Deshacer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    SyncService.instance.discard(order.number);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro sin conexión eliminado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PharmaService.instance,
        SyncService.instance,
      ]),
      builder: (context, _) {
        if (!OrderPolicy.canRead(order, PharmaService.instance.currentUser)) {
          return const Scaffold(
            body: Center(
              child: Text('Entrega no disponible para esta cuenta.'),
            ),
          );
        }
        final pending = SyncService.instance.pendingFor(order.number);
        final syncOffline = SyncService.instance.isOffline;

        return Scaffold(
          appBar: const AppPageAppBar(title: 'Detalle de entrega'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              const Text('DATOS DE LA ENTREGA', style: AppText.eyebrow),
              const SizedBox(height: 7),
              Text(
                order.pharmacyName,
                style: AppText.h1.copyWith(fontSize: 23),
              ),
              const SizedBox(height: 6),
              Text(
                'Verifica la dirección y el contacto antes de salir a ruta.',
                style: AppText.muted,
              ),
              const SizedBox(height: 18),
              OrderDetailCard(order: order, showPrices: false),
              const SizedBox(height: 12),
              OrderLifecyclePanel(order: order, showActions: false),
              if (pending?.conflict != null)
                Text('Conflicto: ${pending!.conflict!}', style: AppText.label),
              const SizedBox(height: 16),
              if (pending != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.approvedBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sync_rounded,
                            size: 18,
                            color: AppColors.approvedText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pending.delivered
                                  ? 'Entrega registrada sin conexión. Se '
                                        'aplicará al sincronizar.'
                                  : 'Intento fallido pendiente de sincronizar: '
                                        '${pending.reason ?? 'sin motivo'}.',
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: AppColors.approvedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _discard(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Deshacer registro',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (order.status.isFailure)
                _StatusNote(
                  icon: Icons.report_gmailerrorred_rounded,
                  background: AppColors.dangerBackground,
                  foreground: AppColors.danger,
                  text:
                      'Entrega fallida: ${order.failureReason ?? 'sin motivo'}'
                      '${(order.failureNote ?? '').trim().isEmpty ? '' : ' · ${(order.failureNote ?? '').trim()}'}',
                )
              else if (order.status.isDelivered)
                const _StatusNote(
                  icon: Icons.check_circle_rounded,
                  background: AppColors.successBackground,
                  foreground: AppColors.successText,
                  text: 'Pedido entregado y cerrado correctamente.',
                )
              else if (syncOffline)
                const _StatusNote(
                  icon: Icons.cloud_off_rounded,
                  background: AppColors.pendingBackground,
                  foreground: AppColors.pendingText,
                  text:
                      'Sin conexión: puedes registrar la entrega o la '
                      'incidencia y se sincronizará después.',
                ),
            ],
          ),
          bottomNavigationBar:
              order.isApproved &&
                  OrderPolicy.driver(order, PharmaService.instance.currentUser!)
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () {
                        final delivery = DeliveryViewModel.instance;
                        final ok = delivery.start(order);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Ruta iniciada.'
                                  : delivery.error ??
                                        'No se pudo iniciar ruta.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Iniciar ruta'),
                    ),
                  ),
                )
              : order.canDeliver &&
                    pending == null &&
                    OrderPolicy.driver(
                      order,
                      PharmaService.instance.currentUser!,
                    )
              ? SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _confirmDelivery(context),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Confirmar entrega'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => SafeArea(
                              child: SingleChildScrollView(
                                child: OrderLifecyclePanel(order: order),
                              ),
                            ),
                          ),
                          child: const Text('Reportar incidencia temporal'),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _reportFailure(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(
                                color: AppColors.danger,
                                width: 0.8,
                              ),
                            ),
                            icon: const Icon(
                              Icons.report_gmailerrorred_rounded,
                              size: 18,
                            ),
                            label: const Text('No se pudo entregar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _StatusNote extends StatelessWidget {
  const _StatusNote({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.text,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, height: 1.4, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
