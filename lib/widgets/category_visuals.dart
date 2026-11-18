import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

IconData categoryIcon(ProductCategory category) {
  return switch (category) {
    ProductCategory.genericos => Icons.medication_outlined,
    ProductCategory.insumos => Icons.medical_services_outlined,
    ProductCategory.vitaminas => Icons.eco_outlined,
  };
}

Color categoryTint(ProductCategory category) {
  return switch (category) {
    ProductCategory.genericos => AppColors.primary,
    ProductCategory.insumos => AppColors.lavenderInk,
    ProductCategory.vitaminas => AppColors.peachInk,
  };
}

Color categoryBackground(ProductCategory category) {
  return switch (category) {
    ProductCategory.genericos => AppColors.mint,
    ProductCategory.insumos => AppColors.lavender,
    ProductCategory.vitaminas => AppColors.peach,
  };
}
