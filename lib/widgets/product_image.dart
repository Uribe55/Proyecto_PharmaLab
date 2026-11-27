import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

/// Fotografía local para los productos que tienen una imagen disponible.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.product, this.height = 96});

  final Product product;
  final double height;

  @override
  Widget build(BuildContext context) {
    final photo = _photoName(product);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: photo == null
            ? _missingPhoto
            : Image.asset(
                'assets/images/products/$photo.png',
                excludeFromSemantics: true,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _missingPhoto,
              ),
      ),
    );
  }

  static const _missingPhoto = Center(
    child: Text('Sin foto', style: AppText.meta),
  );
}

String? _photoName(Product product) {
  final name = product.name.toLowerCase();
  final description = '$name ${product.presentation.toLowerCase()}';
  return switch (name) {
    _ when name.contains('ibuprofeno') && _hasAmount(description, 400, 'mg') =>
      'ibuprofeno',
    _ when name.contains('loratadina') && _hasAmount(description, 10, 'mg') =>
      'loratadina',
    _ when name.contains('paracetamol') && _hasAmount(description, 500, 'mg') =>
      'paracetamol',
    _ when name.contains('gel') && name.contains('antibacterial') => 'gel',
    _ when name.contains('jabón') || name.contains('jabon') => 'jabon',
    _ when name.contains('centrífuga') || name.contains('centrifuga') =>
      'centrifuga',
    _ when name.contains('ecógrafo') || name.contains('ecografo') => 'equipo',
    _
        when name.contains('guante') &&
            (name.contains('nitrilo') ||
                product.material.toLowerCase().contains('nitrilo')) =>
      'guantes',
    _ when name.contains('mascarilla') => 'mascarilla',
    _ when RegExp(r'\bbatas?\b').hasMatch(name) => 'batas',
    _ when name.contains('gasa') => 'gasa',
    _ when name.contains('jeringa') && _hasAmount(description, 10, 'ml') =>
      'jeringa',
    _ => null,
  };
}

bool _hasAmount(String description, int amount, String unit) {
  return RegExp('\\b$amount\\s*$unit\\b').hasMatch(description);
}
