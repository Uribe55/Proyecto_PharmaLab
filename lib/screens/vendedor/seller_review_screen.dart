import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/order_detail_card.dart';
import 'seller_assign_screen.dart';

/// Revisión y aprobación de un pedido pendiente (RF-11).
class SellerReviewScreen extends StatelessWidget {
  const SellerReviewScreen({super.key, required this.order});

  final PharmacyOrder order;

  bool get _allAvailable {
    for (final item in order.items) {
      if (PharmaService.instance.productById(item.productId) == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _approve(BuildContext context) async {
    if (!_allAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hay productos que ya no están en el catálogo. Revisa el pedido '
            'con el administrador.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aprobar pedido'),
        content: Text(
          '¿Confirmas la disponibilidad del pedido ${order.number} para '
          '${order.pharmacyName}? Después podrás asignarle un repartidor.',
          style: AppText.muted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Revisar de nuevo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final approved = PharmaService.instance.approveOrder(order);
    if (!approved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El pedido ya no está pendiente.')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Pedido ${order.number} aprobado.')));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SellerAssignScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: const AppPageAppBar(title: 'Revisión y aprobación'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              const Text('VERIFICACIÓN DEL PEDIDO', style: AppText.eyebrow),
              const SizedBox(height: 7),
              Text(
                order.pharmacyName,
                style: AppText.h1.copyWith(fontSize: 23),
              ),
              const SizedBox(height: 6),
              Text(
                'Comprueba los datos de entrega y la disponibilidad antes de '
                'aprobar.',
                style: AppText.muted,
              ),
              const SizedBox(height: 18),
              OrderDetailCard(order: order),
              const SizedBox(height: 16),
              _StockCard(order: order, allAvailable: _allAvailable),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Al aprobar, el pedido queda listo para asignación. '
                        'Las unidades ya fueron reservadas del inventario al '
                        'momento de la compra.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _ActionBar(
            order: order,
            onApprove: () => _approve(context),
          ),
        );
      },
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.order, required this.allAvailable});

  final PharmacyOrder order;
  final bool allAvailable;

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
              const Expanded(
                child: Text('Verificación de stock', style: AppText.h3),
              ),
              Icon(
                allAvailable
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 19,
                color: allAvailable ? AppColors.successText : AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in order.items) ...[
            _StockRow(item: item),
            if (item != order.items.last) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item});

  final OrderLine item;

  @override
  Widget build(BuildContext context) {
    final product = PharmaService.instance.productById(item.productId);
    final found = product != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Solicitado: ${item.quantity} u.',
                style: AppText.meta.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          found ? 'Stock: ${product.stock} u.' : 'No disponible',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: found ? AppColors.successText : AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.order, required this.onApprove});

  final PharmacyOrder order;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final label = switch (order.status) {
      OrderStatus.pendiente => 'Aprobar pedido',
      OrderStatus.aprobado => 'Asignar entrega',
      _ => null,
    };

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: ElevatedButton.icon(
          onPressed: switch (order.status) {
            OrderStatus.pendiente => onApprove,
            OrderStatus.aprobado => () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => SellerAssignScreen(order: order),
                ),
              );
            },
            _ => null,
          },
          icon: Icon(
            order.status == OrderStatus.aprobado
                ? Icons.local_shipping_outlined
                : Icons.check_rounded,
            size: 18,
          ),
          label: Text(label ?? 'Pedido ${order.status.label.toLowerCase()}'),
        ),
      ),
    );
  }
}
