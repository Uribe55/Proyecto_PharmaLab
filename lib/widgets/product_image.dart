import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'category_visuals.dart';

/// Ilustración local del producto o de su categoría.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.product, this.height = 96});

  final Product product;
  final double height;

  @override
  Widget build(BuildContext context) {
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
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SvgPicture.asset(
          'assets/images/products/${_illustrationName(product)}.svg',
          excludeFromSemantics: true,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

String _illustrationName(Product product) {
  final name = product.name.toLowerCase();
  return switch (name) {
    _ when name.contains('ibuprofeno') => 'ibuprofeno',
    _ when name.contains('gel') && name.contains('antibacterial') => 'gel',
    _ when name.contains('microscopio') => 'microscopio',
    _ when name.contains('centrífuga') || name.contains('centrifuga') =>
      'centrifuga',
    _ when name.contains('guante') => 'guantes',
    _ when name.contains('mascarilla') => 'mascarilla',
    _
        when name.contains('tubo de ensayo') ||
            name.contains('tubos de ensayo') =>
      'tubos',
    _ when name.contains('punta') && name.contains('pipeta') => 'puntas',
    _ => switch (product.category) {
      ProductCategory.reactivosQuimicaSanguinea => 'reactivo',
      ProductCategory.reactivosInmunologia => 'inmunologia',
      ProductCategory.equiposLaboratorio => 'equipo',
      ProductCategory.insumosClinicos => 'insumos',
    },
  };
}
