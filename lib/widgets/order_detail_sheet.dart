import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/pharma_service.dart';
import '../domain/order_policy.dart';
import 'order_lifecycle_panel.dart';
import '../theme/app_theme.dart';
import 'order_detail_card.dart';

/// Abre el detalle completo de un pedido en una hoja modal.
Future<void> showOrderDetailSheet(
  BuildContext context, {
  required PharmacyOrder order,
  bool showPrices = true,
}) {
  if (!OrderPolicy.canRead(order, PharmaService.instance.currentUser)) {
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Detalle del pedido',
                              style: AppText.h3,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      OrderDetailCard(order: order, showPrices: showPrices),
                      const SizedBox(height: 12),
                      OrderLifecyclePanel(order: order),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
