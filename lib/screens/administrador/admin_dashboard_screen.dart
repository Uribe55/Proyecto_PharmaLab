import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/order_detail_sheet.dart';
import '../../widgets/order_list_tile.dart';
import '../../widgets/stat_card.dart';

/// Panel administrativo con indicadores generales (RF-19).
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.onOpenUsers});

  final VoidCallback onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final service = PharmaService.instance;
        final users = service.users;
        final recent = service.orders.take(4).toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const AppTabHeader(title: 'Panel administrativo'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const Text('SUPERVISIÓN GENERAL', style: AppText.eyebrow),
                      const SizedBox(height: 7),
                      const Text(
                        'Todo PharmaLab, a la vista.',
                        style: AppText.h1,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Usuarios, pedidos y entregas del sistema en tiempo '
                        'real.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Usuarios activos',
                              value: '${service.activeUsers}',
                              icon: Icons.people_alt_outlined,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: StatCard(
                              label: 'Pedidos totales',
                              value: '${service.totalOrders}',
                              icon: Icons.receipt_long_outlined,
                              accent: AppColors.lavenderInk,
                              background: AppColors.lavender,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Pendientes',
                              value: '${service.pendingOrdersCount}',
                              icon: Icons.hourglass_top_rounded,
                              accent: AppColors.pendingText,
                              background: AppColors.pendingBackground,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: StatCard(
                              label: 'En ruta',
                              value: '${service.inTransitOrders}',
                              icon: Icons.local_shipping_outlined,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: StatCard(
                              label: 'Entregados',
                              value: '${service.completedDeliveries}',
                              icon: Icons.check_circle_outline_rounded,
                              accent: AppColors.successText,
                              background: AppColors.successBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Usuarios por rol', style: AppText.h3),
                          ),
                          TextButton(
                            onPressed: onOpenUsers,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Gestionar',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _RoleDistribution(users: users),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Actividad reciente',
                              style: AppText.h3,
                            ),
                          ),
                          Text(
                            '${service.orders.length} pedidos',
                            style: AppText.meta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (recent.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Todavía no hay pedidos registrados.',
                            style: AppText.muted,
                          ),
                        )
                      else
                        for (final order in recent) ...[
                          OrderListTile(
                            order: order,
                            onTap: () =>
                                showOrderDetailSheet(context, order: order),
                          ),
                          if (order != recent.last) const SizedBox(height: 11),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleDistribution extends StatelessWidget {
  const _RoleDistribution({required this.users});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < UserRole.values.length; i++) ...[
            _RoleBar(
              role: UserRole.values[i],
              count: users
                  .where((user) => user.role == UserRole.values[i])
                  .length,
              total: users.isEmpty ? 1 : users.length,
            ),
            if (i < UserRole.values.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RoleBar extends StatelessWidget {
  const _RoleBar({
    required this.role,
    required this.count,
    required this.total,
  });

  final UserRole role;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                role.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
