import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/remote_cancellation_panel.dart';

import '../../models/order.dart';
import '../../data/datasources/firestore_order_data_source.dart';
import '../../data/repositories/remote_order_repository.dart';
import '../../services/pharma_service.dart';
import '../../domain/order_policy.dart';
import '../../widgets/order_lifecycle_panel.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/client_header.dart';
import '../../widgets/status_chip.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.order,
    this.showConfirmation = false,
    this.repository,
  });

  final PharmacyOrder order;
  final bool showConfirmation;
  final RemoteOrderRepository? repository;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  PharmacyOrder get order => _latest ?? widget.order;
  PharmacyOrder? _latest;
  bool get showConfirmation => widget.showConfirmation;
  late final Stream<PharmacyOrder>? _stream = widget.order.remote
      ? (widget.repository ?? FirestoreOrderDataSource()).watchOrder(
          widget.order.documentId!,
        )
      : null;

  void _openSummary(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SummarySheet(summary: buildOrderSummary(order)),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PharmacyOrder>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        if (_latest != null) return _buildPage(context, error: true);
        return Scaffold(
          appBar: const ClientPageAppBar(title: 'Seguimiento'),
          body: const Center(
            child: Text(
              'No se pudo actualizar el pedido. Revisa tu conexión y permisos.',
            ),
          ),
        );
      }
      if (snapshot.hasData) _latest = snapshot.data;
      return ListenableBuilder(
        listenable: PharmaService.instance,
        builder: (context, _) => _buildPage(context),
      );
    },
  );

  Widget _buildPage(BuildContext context, {bool error = false}) {
    if (!OrderPolicy.canRead(order, PharmaService.instance.currentUser)) {
      return const Scaffold(
        body: Center(child: Text('Pedido no disponible para esta cuenta.')),
      );
    }
    if (order.remote &&
        PharmaService.instance.usesFirebase &&
        order.pharmacyId != PharmaService.instance.pharmacyId) {
      return const Scaffold(
        body: Center(child: Text('Pedido no disponible para esta farmacia.')),
      );
    }
    return Scaffold(
      appBar: ClientPageAppBar(
        title: 'Seguimiento',
        actions: [
          IconButton(
            tooltip: 'Compartir resumen',
            onPressed: () => _openSummary(context),
            icon: const Icon(Icons.ios_share_rounded, size: 21),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          if (error)
            const Text(
              'No se pudo sincronizar. Se muestra la última información recibida; puede estar desactualizada.',
              style: AppText.muted,
            ),
          if (order.fromCache)
            const Text(
              'Información guardada; pendiente de actualizar con el servidor.',
              style: AppText.muted,
            ),
          if (showConfirmation) ...[
            const _ConfirmationBanner(),
            const SizedBox(height: 14),
          ],
          _OrderSummaryCard(order: order),
          RemoteCancellationPanel(order: order),
          const SizedBox(height: 14),
          if (!order.remote) OrderLifecyclePanel(order: order),
          const SizedBox(height: 22),
          const Text('Progreso de entrega', style: AppText.h3),
          const SizedBox(height: 14),
          _Timeline(order: order),
          const SizedBox(height: 22),
          const Text('Productos', style: AppText.h3),
          if (order.items.isEmpty)
            const Text(
              'No hay detalles de productos registrados para este pedido.',
              style: AppText.meta,
            ),
          const SizedBox(height: 12),
          _ProductsCard(order: order),
          const SizedBox(height: 22),
          const Text('Datos de entrega', style: AppText.h3),
          const SizedBox(height: 12),
          _DeliveryCard(order: order),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openSummary(context),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Compartir resumen'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Genera un resumen con productos, cantidades y total para '
            'enviarlo por WhatsApp o correo.',
            textAlign: TextAlign.center,
            style: AppText.meta,
          ),
        ],
      ),
    );
  }
}

class _ConfirmationBanner extends StatelessWidget {
  const _ConfirmationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Pedido confirmado!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Registramos tu pedido y el stock ya fue descontado. '
                  'Queda pendiente de aprobación por el vendedor.',
                  style: AppText.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final PharmacyOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                  style: AppText.h3.copyWith(fontSize: 16),
                ),
              ),
              StatusChip(status: order.status, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.createdAtKnown
                ? formatOrderDate(order.createdAt)
                : 'Fecha no registrada',
            style: AppText.meta,
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.items.map((line) => line.productId).toSet().length} productos · '
                  '${order.totalUnits} unidades',
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
              ),
              Text(
                formatBs(order.total),
                style: AppText.h3.copyWith(fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final PharmacyOrder order;
  @override
  Widget build(BuildContext context) {
    DateTime? eventDate(OrderStatus status) {
      for (final event in order.history) {
        if (event.after == status && event.atKnown) return event.at;
      }
      return null;
    }

    bool recorded(OrderStatus status) =>
        order.history.any((event) => event.after == status);
    final stages =
        <({String title, bool observed, DateTime? at, bool current})>[
          (
            title: 'Pedido confirmado',
            observed:
                order.createdAtKnown ||
                recorded(OrderStatus.pendiente) ||
                order.status == OrderStatus.pendiente,
            at:
                eventDate(OrderStatus.pendiente) ??
                (order.createdAtKnown ? order.createdAt : null),
            current: order.status == OrderStatus.pendiente,
          ),
          (
            title: 'Pedido aprobado',
            observed:
                order.approvedAt != null ||
                recorded(OrderStatus.aprobado) ||
                order.status == OrderStatus.aprobado,
            at: order.approvedAt ?? eventDate(OrderStatus.aprobado),
            current:
                order.status == OrderStatus.aprobado &&
                order.deliveryId == null,
          ),
          (
            title: 'Repartidor asignado',
            observed: order.deliveryId != null || order.assignedAt != null,
            at: order.assignedAt,
            current:
                order.status == OrderStatus.aprobado &&
                order.deliveryId != null,
          ),
          (
            title: 'Pedido en ruta',
            observed:
                order.dispatchedAt != null ||
                recorded(OrderStatus.enRuta) ||
                order.status == OrderStatus.enRuta,
            at: order.dispatchedAt ?? eventDate(OrderStatus.enRuta),
            current: order.status == OrderStatus.enRuta,
          ),
          (
            title: 'Pedido entregado',
            observed:
                order.deliveredAt != null ||
                recorded(OrderStatus.entregado) ||
                order.status == OrderStatus.entregado,
            at: order.deliveredAt ?? eventDate(OrderStatus.entregado),
            current: order.status == OrderStatus.entregado,
          ),
        ];
    final history = [...order.history]
      ..sort(
        (a, b) => a.atKnown == b.atKnown
            ? a.at.compareTo(b.at)
            : a.atKnown
            ? -1
            : 1,
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stage in stages)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              stage.current
                  ? Icons.radio_button_checked
                  : stage.observed
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              color: stage.observed ? AppColors.primary : AppColors.muted,
            ),
            title: Text(
              stage.title,
              style: stage.current ? AppText.label : AppText.meta,
            ),
            subtitle: Text(
              stage.at != null
                  ? formatOrderDate(stage.at!)
                  : stage.observed
                  ? 'Fecha no registrada'
                  : 'Sin evidencia registrada',
              style: AppText.meta,
            ),
          ),
        if (order.status == OrderStatus.fallida ||
            order.status == OrderStatus.cancelado ||
            order.status == OrderStatus.reprogramado)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline, color: AppColors.danger),
            title: Text(order.status.label),
            subtitle: Text(
              order.cancellationReason ??
                  order.failureReason ??
                  order.status.description,
            ),
          ),
        const SizedBox(height: 14),
        const Text('Historial de estados', style: AppText.h3),
        if (history.isEmpty)
          const Text(
            'No hay eventos históricos registrados.',
            style: AppText.meta,
          ),
        for (final event in history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(
              '${event.before.label} → ${event.after.label}',
              style: AppText.label,
            ),
            subtitle: Text(
              '${event.atKnown ? formatOrderDate(event.at) : 'Fecha no registrada'}\n${event.note.isEmpty ? event.after.description : event.note}',
              style: AppText.meta,
            ),
          ),
      ],
    );
  }
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({required this.order});

  final PharmacyOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < order.items.length; index++) ...[
            if (index > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.items[index].name,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.items[index].quantity} × '
                          '${formatBs(order.items[index].unitPrice)} · '
                          '${order.items[index].presentation}',
                          style: AppText.meta.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatBs(order.items[index].subtotal),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Text('Total', style: AppText.label),
                const Spacer(),
                Text(
                  formatBs(order.total),
                  style: AppText.h3.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order});

  final PharmacyOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.location_on_outlined,
            title: order.pharmacyName,
            subtitle: order.address,
          ),
          if (order.deliveryReference.isNotEmpty)
            Text('Referencia: ${order.deliveryReference}', style: AppText.meta),
          if (order.deliveryId != null) ...[
            const Divider(height: 22),
            _DetailRow(
              icon: Icons.local_shipping_outlined,
              title: order.driverName ?? 'Repartidor asignado',
              subtitle: order.deliveryState == null
                  ? 'Información de entrega no disponible'
                  : 'Estado de entrega: ${order.deliveryState}',
            ),
          ],
          if (order.scheduledFor != null)
            Text(
              'Entrega programada: ${formatOrderDate(order.scheduledFor!)}',
              style: AppText.meta,
            ),
          if (order.dispatchedAt != null)
            Text(
              'Inicio de recorrido: ${formatOrderDate(order.dispatchedAt!)}',
              style: AppText.meta,
            ),
          if (order.deliveredAt != null)
            Text(
              'Entrega efectiva: ${formatOrderDate(order.deliveredAt!)}',
              style: AppText.meta,
            ),
          if (order.failureReason?.isNotEmpty == true)
            Text(
              'Incidencia: ${order.failureReason} ${order.failureNote ?? ''}',
              style: AppText.meta,
            ),
          if (order.rescheduledFor != null)
            Text(
              'Reprogramación: ${formatOrderDate(order.rescheduledFor!)}',
              style: AppText.meta,
            ),
          const Divider(height: 22),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            title: order.contactName,
            subtitle: order.contactPhone,
          ),
          if (order.notes.trim().isNotEmpty) ...[
            const Divider(height: 22),
            _DetailRow(
              icon: Icons.sticky_note_2_outlined,
              title: 'Observaciones',
              subtitle: order.notes.trim(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.meta.copyWith(fontSize: 10.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummarySheet extends StatelessWidget {
  const _SummarySheet({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Resumen para compartir', style: AppText.h3),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 320),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  summary,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.55,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: summary));
                if (context.mounted) Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Resumen copiado. Ya puedes compartirlo.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar resumen'),
            ),
          ],
        ),
      ),
    );
  }
}
