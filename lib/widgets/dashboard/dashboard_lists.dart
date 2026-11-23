import 'package:flutter/material.dart';

import '../../models/dashboard_metrics.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'dashboard_charts.dart';

/// Ranking de productos entregados en el período.
class ProductSalesList extends StatelessWidget {
  const ProductSalesList({super.key, required this.products});

  final List<ProductSales> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.shopping_bag_outlined,
        text: 'Aún no hay productos vendidos en el período seleccionado.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          _ProductRow(index: i + 1, product: products[i]),
          if (i < products.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.index, required this.product});

  final int index;
  final ProductSales product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index <= 3 ? AppColors.mint : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: index <= 3 ? AppColors.primary : AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${product.category} · ${product.units} u.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatBs(product.amount),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Actividad de entregas por repartidor.
class DriverActivityList extends StatelessWidget {
  const DriverActivityList({super.key, required this.drivers});

  final List<DriverActivity> drivers;

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.local_shipping_outlined,
        text: 'Sin actividad de repartidores en el período seleccionado.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < drivers.length; i++) ...[
          _DriverRow(driver: drivers[i]),
          if (i < drivers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.driver});

  final DriverActivity driver;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(driver.name);
    final rate = driver.successRate;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${driver.delivered} entregadas · ${driver.failed} fallidas · '
                '${driver.inTransit} en ruta',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatPercent(rate),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: rate == null ? AppColors.muted : AppColors.successText,
              ),
            ),
            Text('éxito', style: AppText.meta.copyWith(fontSize: 8.5)),
          ],
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'SR';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
