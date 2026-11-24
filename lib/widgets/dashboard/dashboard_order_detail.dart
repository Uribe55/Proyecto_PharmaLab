import 'package:flutter/material.dart';

import '../../models/dashboard_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../status_chip.dart';

/// Abre el detalle de un pedido normalizado del dashboard.
Future<void> showDashboardOrderDetail(
  BuildContext context, {
  required DashboardOrder order,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Detalle del pedido',
                              style: AppText.h3,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _DashboardOrderDetailCard(order: order),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Tarjeta compacta para listados de pedidos administrativos.
class DashboardOrderTile extends StatelessWidget {
  const DashboardOrderTile({
    super.key,
    required this.order,
    this.caption,
    this.onTap,
  });

  final DashboardOrder order;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(15),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: order.status, compact: true),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            order.pharmacyName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption ??
                (order.createdAt == null
                    ? 'Sin fecha registrada'
                    : formatOrderDate(order.createdAt!)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.meta.copyWith(fontSize: 10.5),
          ),
          const SizedBox(height: 11),
          const Divider(),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.items.isEmpty
                      ? 'Sin detalle de productos'
                      : '${order.items.length} '
                            '${order.items.length == 1 ? 'producto' : 'productos'} · '
                            '${order.totalUnits} u.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatBs(order.total),
                style: AppText.h3.copyWith(fontSize: 13),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppColors.muted,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _DashboardOrderDetailCard extends StatelessWidget {
  const _DashboardOrderDetailCard({required this.order});

  final DashboardOrder order;

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h3.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: order.status, compact: true),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            order.createdAt == null
                ? 'Fecha de creación no registrada'
                : formatOrderDate(order.createdAt!),
            style: AppText.meta,
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: 'Farmacia',
            value: order.pharmacyName,
          ),
          if (order.address.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Dirección de entrega',
              value: order.address,
            ),
          if (order.contactName.isNotEmpty || order.contactPhone.isNotEmpty)
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Contacto',
              value: [
                if (order.contactName.isNotEmpty) order.contactName,
                if (order.contactPhone.isNotEmpty) order.contactPhone,
              ].join(' · '),
            ),
          if (order.driverName != null || order.driverId != null)
            _InfoRow(
              icon: Icons.local_shipping_outlined,
              label: 'Repartidor',
              value: order.driverName ?? order.driverId!,
            ),
          if (order.deliveredAt != null)
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: order.isFailure ? 'Fecha del intento' : 'Fecha de entrega',
              value: formatOrderDate(order.deliveredAt!),
            ),
          if (order.failureReason != null &&
              order.failureReason!.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.report_problem_outlined,
              label: 'Motivo de la falla',
              value: order.failureReason!.trim(),
            ),
          if (order.notes.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.notes_rounded,
              label: 'Observaciones',
              value: order.notes.trim(),
            ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Productos',
                  style: AppText.h3.copyWith(fontSize: 14),
                ),
              ),
              if (order.items.isNotEmpty)
                Text(
                  '${order.items.length} '
                  '${order.items.length == 1 ? 'ítem' : 'ítems'} · '
                  '${order.totalUnits} u.',
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (order.items.isEmpty)
            Text(
              'El pedido no incluye el detalle de productos en su documento. '
              'El importe total se toma del campo del pedido.',
              style: AppText.muted.copyWith(fontSize: 11),
            )
          else
            for (final item in order.items) ...[
              _ItemRow(item: item),
              if (item != order.items.last) const SizedBox(height: 10),
            ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Valor del pedido', style: AppText.label),
              ),
              Text(formatBs(order.total), style: AppText.price),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Importe histórico: usa los precios y cantidades registrados en el '
            'pedido.',
            style: AppText.meta.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final DashboardOrderLine item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${item.quantity}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (item.brand.isNotEmpty) item.brand,
                  if (item.presentation.isNotEmpty) item.presentation,
                  item.category,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatBs(item.subtotal),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.meta.copyWith(fontSize: 10)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
