import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'status_chip.dart';

/// Tarjeta compacta para listados de pedidos de los módulos internos.
class OrderListTile extends StatelessWidget {
  const OrderListTile({
    super.key,
    required this.order,
    this.showTotal = true,
    this.caption,
    this.trailing,
    this.onTap,
  });

  final PharmacyOrder order;
  final bool showTotal;
  final String? caption;
  final Widget? trailing;
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
                (order.createdAtKnown
                    ? formatOrderDate(order.createdAt)
                    : 'Fecha no disponible'),
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
                  '${order.items.length} '
                  '${order.items.length == 1 ? 'producto' : 'productos'} · '
                  '${order.totalUnits} u.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
              ),
              if (showTotal) ...[
                const SizedBox(width: 8),
                Text(
                  formatBs(order.total),
                  style: AppText.h3.copyWith(fontSize: 13),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ] else if (onTap != null) ...[
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
