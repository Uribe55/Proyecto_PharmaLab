import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final String label;

    if (!product.isAvailable) {
      background = AppColors.dangerBackground;
      foreground = AppColors.danger;
      label = 'Agotado';
    } else if (product.isLowStock) {
      background = AppColors.pendingBackground;
      foreground = AppColors.pendingText;
      label = 'Últimas ${product.stock}';
    } else {
      background = AppColors.successBackground;
      foreground = AppColors.successText;
      label = 'Disponible';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              height: 1,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
