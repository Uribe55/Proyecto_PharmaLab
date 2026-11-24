import 'package:flutter/material.dart';

import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../shared/employee_account_screen.dart';

/// Cuenta del repartidor con el control de trabajo sin conexión (RF-18).
class DriverAccountScreen extends StatelessWidget {
  const DriverAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeAccountScreen(
      title: 'Mi cuenta',
      extraSections: [_OfflineSection()],
    );
  }
}

class _OfflineSection extends StatelessWidget {
  const _OfflineSection();

  void _syncNow(BuildContext context) {
    final synced = SyncService.instance.syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced == 0
              ? 'No había entregas pendientes de sincronizar.'
              : synced == 1
              ? 'Se sincronizó 1 entrega con el sistema.'
              : 'Se sincronizaron $synced entregas con el sistema.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, _) {
        final sync = SyncService.instance;

        return AccountSection(
          title: 'Trabajo sin conexión',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: sync.isOffline,
                onChanged: sync.setOffline,
                activeThumbColor: AppColors.surface,
                activeTrackColor: AppColors.primary,
                secondary: const Icon(Icons.cloud_off_outlined, size: 20),
                title: const Text(
                  'Modo sin conexión',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Guarda entregas e incidencias en el teléfono',
                  style: AppText.meta,
                ),
              ),
              if (sync.pendingCount > 0) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Pendientes de sincronizar',
                              style: AppText.label,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.pendingBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${sync.pendingCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pendingText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final item in sync.pending) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              Icon(
                                item.delivered
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.report_gmailerrorred_rounded,
                                size: 14,
                                color: item.delivered
                                    ? AppColors.successText
                                    : AppColors.danger,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  item.orderNumber,
                                  style: AppText.meta.copyWith(fontSize: 10.5),
                                ),
                              ),
                              Text(
                                item.delivered ? 'Entregado' : 'Fallida',
                                style: AppText.meta.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: sync.isOffline
                              ? null
                              : () => _syncNow(context),
                          icon: const Icon(Icons.sync_rounded, size: 17),
                          label: Text(
                            sync.isOffline
                                ? 'Conéctate para sincronizar'
                                : 'Sincronizar ahora',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las entregas registradas sin conexión se aplican '
                        'sobre los pedidos cuando vuelve la señal.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
