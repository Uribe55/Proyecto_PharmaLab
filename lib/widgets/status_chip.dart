import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      OrderStatus.pendiente => (
        AppColors.pendingBackground,
        AppColors.pendingText,
      ),
      OrderStatus.aprobado => (
        AppColors.approvedBackground,
        AppColors.approvedText,
      ),
      OrderStatus.enRuta => (AppColors.mint, AppColors.primary),
      OrderStatus.entregado => (
        AppColors.successBackground,
        AppColors.successText,
      ),
      OrderStatus.cancelado ||
      OrderStatus.fallida => (AppColors.dangerBackground, AppColors.danger),
      OrderStatus.reprogramado => (
        AppColors.lavender,
        AppColors.lavenderInk,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
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
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
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
