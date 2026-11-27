import '../../widgets/admin_scroll_layout.dart';
import '../../widgets/staff_filter_chip.dart';

import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/delivery_card.dart';
import '../../widgets/stat_card.dart';
import 'driver_delivery_detail_screen.dart';

/// Entregas asignadas al repartidor en sesión (RF-13).
class DriverDeliveriesScreen extends StatefulWidget {
  const DriverDeliveriesScreen({super.key});

  @override
  State<DriverDeliveriesScreen> createState() => _DriverDeliveriesScreenState();
}

class _DriverDeliveriesScreenState extends State<DriverDeliveriesScreen> {
  OrderStatus? _filter;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PharmaService.instance,
        SyncService.instance,
      ]),
      builder: (context, _) {
        final service = PharmaService.instance;
        final driver = service.currentUser;
        final orders = driver == null
            ? <PharmacyOrder>[]
            : service.ordersForDriver(driver.id);

        final filtered = orders
            .where(
              (o) =>
                  o.driverId == driver?.id &&
                  (_filter == null ||
                      (_filter == OrderStatus.reprogramado
                          ? o.needsReschedule
                          : o.status == _filter)),
            )
            .toList();
        final active = orders
            .where(
              (order) =>
                  order.driverId == driver?.id &&
                  (order.isInTransit || order.isApproved),
            )
            .toList();
        final delivered = orders
            .where((order) => order.status.isDelivered)
            .length;
        final failed = orders.where((order) => order.needsReschedule).length;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: AdminScrollLayout(
              header: AppTabHeader(title: 'Mis entregas', showLogo: true),
              body: AdminScrollList(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const Text('RUTA DEL DÍA', style: AppText.eyebrow),
                  const SizedBox(height: 7),
                  Text(
                    'Hola, ${driver?.firstName ?? 'repartidor'}.',
                    style: AppText.h1,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Estas son las entregas que tienes asignadas. Solo tú '
                    'puedes verlas y actualizarlas.',
                    style: AppText.muted,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'En ruta',
                          value: '${active.length}',
                          icon: Icons.local_shipping_outlined,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: StatCard(
                          label: 'Entregadas',
                          value: '$delivered',
                          icon: Icons.check_circle_outline_rounded,
                          accent: AppColors.successText,
                          background: AppColors.successBackground,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: StatCard(
                          label: 'Incidencias',
                          value: '$failed',
                          icon: Icons.report_gmailerrorred_rounded,
                          accent: AppColors.danger,
                          background: AppColors.dangerBackground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const OfflineBanner(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in const <OrderStatus?, String>{
                          null: 'Todas',
                          OrderStatus.aprobado: 'Asignadas',
                          OrderStatus.enRuta: 'En ruta',
                          OrderStatus.entregado: 'Entregadas',
                          OrderStatus.reprogramado: 'Fallidas',
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: StaffFilterChip(
                              label: entry.value,
                              selected: _filter == entry.key,
                              onTap: () => setState(() => _filter = entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Tus entregas', style: AppText.h3),
                      ),
                      Text('${filtered.length}', style: AppText.meta),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: EmptyState(
                        icon: Icons.route_outlined,
                        title: 'Sin entregas en esta categoría',
                        description:
                            'Cuando el vendedor te asigne un pedido '
                            'aparecerá aquí con la dirección de la farmacia.',
                      ),
                    )
                  else
                    for (final order in filtered) ...[
                      OrderDeliveryCard(
                        order: order,
                        showTotal: false,
                        caption: _captionFor(order),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DriverDeliveryDetailScreen(order: order),
                            ),
                          );
                        },
                      ),
                      if (order != filtered.last) const SizedBox(height: 11),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _captionFor(PharmacyOrder order) {
    if (SyncService.instance.isQueued(order.number)) {
      return 'Registro sin conexión · pendiente de sincronizar';
    }
    return '${order.pharmacyName} · ${order.totalUnits} unidades';
  }
}
