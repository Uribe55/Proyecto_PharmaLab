import 'package:flutter/material.dart';

import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Aviso de trabajo sin conexión y sincronización pendiente (RF-18).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  void _sync(BuildContext context) {
    final synced = SyncService.instance.syncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced == 0
              ? 'No había entregas por sincronizar.'
              : synced == 1
              ? 'Se sincronizó 1 entrega.'
              : 'Se sincronizaron $synced entregas.',
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
        if (!sync.isOffline && sync.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final offline = sync.isOffline;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: offline
                ? AppColors.pendingBackground
                : AppColors.approvedBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                offline ? Icons.cloud_off_rounded : Icons.sync_rounded,
                size: 18,
                color: offline ? AppColors.pendingText : AppColors.approvedText,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offline
                          ? 'Trabajando sin conexión'
                          : 'Sincronización pendiente',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: offline
                            ? AppColors.pendingText
                            : AppColors.approvedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offline
                          ? 'Tus entregas se guardarán en el teléfono y se '
                                'sincronizarán al volver la señal.'
                          : 'Tienes ${sync.pendingCount} '
                                '${sync.pendingCount == 1 ? 'entrega' : 'entregas'} '
                                'registradas sin conexión.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: offline
                            ? AppColors.pendingText
                            : AppColors.approvedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (!offline && sync.pendingCount > 0)
                TextButton(
                  onPressed: () => _sync(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Sincronizar',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
