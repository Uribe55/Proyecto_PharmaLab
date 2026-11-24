import 'package:flutter/material.dart';

import '../../models/dashboard_models.dart';
import '../../theme/app_theme.dart';

/// Tarjeta compacta con el origen de los datos y el botón de actualización.
class DashboardSourceBanner extends StatelessWidget {
  const DashboardSourceBanner({
    super.key,
    required this.origin,
    required this.updatedAt,
    required this.onRefresh,
    this.message,
    this.refreshing = false,
  });

  final DashboardOrigin origin;
  final DateTime? updatedAt;
  final VoidCallback onRefresh;
  final String? message;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (origin) {
      DashboardOrigin.firestore => (
        'Firestore · pedidos en tiempo real',
        AppColors.successText,
        AppColors.successBackground,
      ),
      DashboardOrigin.local => (
        'Modo local de demostración',
        AppColors.pendingText,
        AppColors.pendingBackground,
      ),
      DashboardOrigin.localFallback => (
        'Pedidos locales · Firestore sin registros',
        AppColors.pendingText,
        AppColors.pendingBackground,
      ),
      DashboardOrigin.permissionDenied => (
        'Permisos denegados · pedidos de demostración',
        AppColors.danger,
        AppColors.dangerBackground,
      ),
      DashboardOrigin.loading => (
        'Cargando pedidos…',
        AppColors.muted,
        AppColors.background,
      ),
      DashboardOrigin.error => (
        'Sin conexión con pedidos',
        AppColors.danger,
        AppColors.dangerBackground,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    if (updatedAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        _timeLabel(updatedAt!),
                        style: AppText.meta.copyWith(fontSize: 9),
                      ),
                    ],
                  ],
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: AppText.meta.copyWith(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar dashboard',
            visualDensity: VisualDensity.compact,
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Distingue el inventario real de Firestore del stock de demostración o de
/// un error de permisos. No muestra ceros cuando la consulta falló.
class DashboardInventorySourceBanner extends StatelessWidget {
  const DashboardInventorySourceBanner({
    super.key,
    required this.inventory,
    required this.onRefresh,
    this.refreshing = false,
  });

  final DashboardInventory inventory;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final (label, color, background, icon) = switch (inventory.origin) {
      InventoryOrigin.firestore => (
        'Inventario real · lotes_productos',
        AppColors.successText,
        AppColors.successBackground,
        Icons.cloud_done_outlined,
      ),
      InventoryOrigin.local => (
        'Stock de demostración · sin lotes reales',
        AppColors.pendingText,
        AppColors.pendingBackground,
        Icons.science_outlined,
      ),
      InventoryOrigin.permissionDenied => (
        'Permisos denegados para el inventario',
        AppColors.danger,
        AppColors.dangerBackground,
        Icons.lock_outline_rounded,
      ),
      InventoryOrigin.unavailable => (
        'Inventario no disponible',
        AppColors.danger,
        AppColors.dangerBackground,
        Icons.cloud_off_outlined,
      ),
      InventoryOrigin.loading => (
        'Consultando inventario…',
        AppColors.muted,
        AppColors.background,
        Icons.sync_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (inventory.note != null || inventory.error != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    inventory.error ?? inventory.note!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar inventario',
            visualDensity: VisualDensity.compact,
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Alerta administrativa discreta y navegable.
class DashboardAlertTile extends StatelessWidget {
  const DashboardAlertTile({
    super.key,
    required this.alert,
    required this.onTap,
  });

  final DashboardAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = _visuals(alert.type);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (alert.count > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${alert.count}',
                              style: TextStyle(
                                fontSize: 9,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _visuals(DashboardAlertType type) {
    return switch (type) {
      DashboardAlertType.vencidos => (
        Icons.event_busy_rounded,
        AppColors.danger,
        AppColors.dangerBackground,
      ),
      DashboardAlertType.agotados => (
        Icons.inventory_2_outlined,
        AppColors.danger,
        AppColors.dangerBackground,
      ),
      DashboardAlertType.stockBajo => (
        Icons.warning_amber_rounded,
        AppColors.pendingText,
        AppColors.pendingBackground,
      ),
      DashboardAlertType.porVencer => (
        Icons.schedule_rounded,
        AppColors.pendingText,
        AppColors.pendingBackground,
      ),
      DashboardAlertType.entregasFallidas => (
        Icons.report_problem_outlined,
        AppColors.danger,
        AppColors.dangerBackground,
      ),
      DashboardAlertType.pedidosAtencion => (
        Icons.hourglass_bottom_rounded,
        AppColors.approvedText,
        AppColors.approvedBackground,
      ),
      DashboardAlertType.inventarioNoDisponible => (
        Icons.cloud_off_outlined,
        AppColors.muted,
        AppColors.background,
      ),
    };
  }
}

/// Envoltorio visual consistente para las secciones del dashboard.
class DashboardSurface extends StatelessWidget {
  const DashboardSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Estado de error con reintento, usado por pedidos e inventario.
class DashboardErrorSurface extends StatelessWidget {
  const DashboardErrorSurface({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DashboardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No se pudo cargar la información', style: AppText.h3),
          const SizedBox(height: 6),
          Text(message, style: AppText.muted),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
