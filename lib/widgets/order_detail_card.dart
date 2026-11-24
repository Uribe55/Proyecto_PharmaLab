import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'status_chip.dart';

/// Detalle de pedido reutilizable por vendedor, repartidor y administrador.
///
/// El repartidor no debe ver precios de compra, por eso [showPrices] permite
/// ocultar importes y totales (tabla de actores del informe).
class OrderDetailCard extends StatelessWidget {
  const OrderDetailCard({
    super.key,
    required this.order,
    this.showPrices = true,
    this.footer,
  });

  final PharmacyOrder order;
  final bool showPrices;
  final Widget? footer;

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
          Text(formatOrderDate(order.createdAt), style: AppText.meta),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: 'Farmacia',
            value: order.pharmacyName,
          ),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Dirección de entrega',
            value: order.address,
          ),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Contacto',
            value: '${order.contactName} · ${order.contactPhone}',
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
              Text(
                '${order.items.length} '
                '${order.items.length == 1 ? 'ítem' : 'ítems'} · '
                '${order.totalUnits} u.',
                style: AppText.meta.copyWith(fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in order.items) ...[
            _ItemRow(item: item, showPrices: showPrices),
            if (item != order.items.last) const SizedBox(height: 10),
          ],
          if (showPrices) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text('Total del pedido', style: AppText.label),
                ),
                Text(formatBs(order.total), style: AppText.price),
              ],
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.showPrices});

  final OrderLine item;
  final bool showPrices;

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
                '${item.brand} · ${item.presentation}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        if (showPrices) ...[
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
