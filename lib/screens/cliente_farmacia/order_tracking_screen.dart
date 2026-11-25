import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../domain/order_policy.dart';
import '../../widgets/order_lifecycle_panel.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/client_header.dart';
import '../../widgets/status_chip.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({
    super.key,
    required this.order,
    this.showConfirmation = false,
  });

  final PharmacyOrder order;
  final bool showConfirmation;

  void _openSummary(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SummarySheet(summary: buildOrderSummary(order)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PharmaService.instance,
    builder: (context, _) => _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    if (!OrderPolicy.canRead(order, PharmaService.instance.currentUser)) {
      return const Scaffold(
        body: Center(child: Text('Pedido no disponible para esta cuenta.')),
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
          if (showConfirmation) ...[
            const _ConfirmationBanner(),
            const SizedBox(height: 14),
          ],
          _OrderSummaryCard(order: order),
          const SizedBox(height: 14),
          OrderLifecyclePanel(order: order),
          const SizedBox(height: 22),
          const Text('Progreso de entrega', style: AppText.h3),
          const SizedBox(height: 14),
          if (order.status != OrderStatus.cancelado) _Timeline(order: order),
          const SizedBox(height: 22),
          const Text('Productos', style: AppText.h3),
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
          Text(formatOrderDate(order.createdAt), style: AppText.meta),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.items.length} productos · '
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < OrderStatus.deliverySteps.length; index++)
            _TimelineStep(
              status: OrderStatus.deliverySteps[index],
              index: index,
              currentIndex: order.statusIndex,
              isLast: index == OrderStatus.deliverySteps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.status,
    required this.index,
    required this.currentIndex,
    required this.isLast,
  });

  final OrderStatus status;
  final int index;
  final int currentIndex;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDone = index < currentIndex;
    final isActive = index == currentIndex;
    final isFuture = index > currentIndex;
    final lineColor = index < currentIndex
        ? AppColors.primary.withValues(alpha: 0.45)
        : AppColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.primary
                      : isDone
                      ? AppColors.mint
                      : AppColors.surface,
                  border: Border.all(
                    color: isFuture ? AppColors.border : AppColors.primary,
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.primary,
                      )
                    : isActive
                    ? Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              if (!isLast) Container(width: 2, height: 38, color: lineColor),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 3, bottom: isLast ? 18 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isFuture
                        ? AppColors.muted
                        : isActive
                        ? AppColors.primary
                        : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status.description,
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
              ],
            ),
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
