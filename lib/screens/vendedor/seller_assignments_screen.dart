import 'package:flutter/material.dart';

import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/order_detail_sheet.dart';
import '../../widgets/order_list_tile.dart';
import 'seller_assign_screen.dart';

/// Seguimiento de entregas del vendedor: pedidos por asignar y en ruta.
class SellerAssignmentsScreen extends StatelessWidget {
  const SellerAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final service = PharmaService.instance;
        final toAssign = service.approvedOrders;
        final inTransit = service.orders
            .where((order) => order.isInTransit)
            .toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const AppTabHeader(title: 'Entregas'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const Text('LOGÍSTICA', style: AppText.eyebrow),
                      const SizedBox(height: 7),
                      const Text(
                        'Del almacén a la farmacia.',
                        style: AppText.h1,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Asigna los pedidos aprobados y sigue las entregas que '
                        'ya están en ruta.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 22),
                      _GroupHeader(
                        title: 'Por asignar',
                        count: toAssign.length,
                      ),
                      const SizedBox(height: 12),
                      if (toAssign.isEmpty)
                        const _EmptyGroup(
                          icon: Icons.assignment_turned_in_outlined,
                          text:
                              'No hay pedidos aprobados esperando repartidor.',
                        )
                      else
                        for (final order in toAssign) ...[
                          OrderListTile(
                            order: order,
                            caption: 'Aprobado · listo para asignar',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SellerAssignScreen(order: order),
                                ),
                              );
                            },
                          ),
                          if (order != toAssign.last)
                            const SizedBox(height: 11),
                        ],
                      const SizedBox(height: 24),
                      _GroupHeader(title: 'En ruta', count: inTransit.length),
                      const SizedBox(height: 12),
                      if (inTransit.isEmpty)
                        const _EmptyGroup(
                          icon: Icons.local_shipping_outlined,
                          text: 'Todavía no hay entregas en camino.',
                        )
                      else
                        for (final order in inTransit) ...[
                          OrderListTile(
                            order: order,
                            caption:
                                'Repartidor: ${order.driverName ?? 'sin asignar'}',
                            onTap: () =>
                                showOrderDetailSheet(context, order: order),
                          ),
                          if (order != inTransit.last)
                            const SizedBox(height: 11),
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.h3)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.muted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text, style: AppText.muted.copyWith(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
