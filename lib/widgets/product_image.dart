import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'category_visuals.dart';

/// Representación visual del producto. Sustituye temporalmente a las
/// fotografías del catálogo real.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.height = 96,
    this.iconSize = 30,
    this.showBrand = true,
  });

  final Product product;
  final double height;
  final double iconSize;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final tint = categoryTint(product.category);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            categoryBackground(product.category).withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tint.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize * 1.4,
                height: 3,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Icon(categoryIcon(product.category), size: iconSize, color: tint),
              if (showBrand) ...[
                const SizedBox(height: 4),
                Text(
                  product.brand.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 6.5,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
