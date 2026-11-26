import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

IconData categoryIcon(ProductCategory category) {
  return switch (category) {
    ProductCategory.reactivosQuimicaSanguinea => Icons.science_outlined,
    ProductCategory.reactivosInmunologia => Icons.coronavirus_outlined,
    ProductCategory.equiposLaboratorio => Icons.precision_manufacturing_outlined,
    ProductCategory.insumosClinicos => Icons.medical_services_outlined,
  };
}

Color categoryTint(ProductCategory category) {
  return switch (category) {
    ProductCategory.reactivosQuimicaSanguinea => AppColors.primary,
    ProductCategory.reactivosInmunologia => AppColors.lavenderInk,
    ProductCategory.equiposLaboratorio => AppColors.approvedText,
    ProductCategory.insumosClinicos => AppColors.peachInk,
  };
}

Color categoryBackground(ProductCategory category) {
  return switch (category) {
    ProductCategory.reactivosQuimicaSanguinea => AppColors.mint,
    ProductCategory.reactivosInmunologia => AppColors.lavender,
    ProductCategory.equiposLaboratorio => AppColors.approvedBackground,
    ProductCategory.insumosClinicos => AppColors.peach,
  };
}
