import '../../widgets/admin_scroll_layout.dart';

import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/delivery_card.dart';
import 'driver_delivery_detail_screen.dart';

/// Historial de entregas del repartidor (RF-13).
class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final service = PharmaService.instance;
        final driver = service.currentUser;
        final all = driver == null
            ? <PharmacyOrder>[]
            : service.ordersForDriver(driver.id);
        final orders =
            all
                .where(
                  (order) =>
                      order.driverId == driver?.id && order.status.isDelivered,
                )
                .toList()
              ..sort(
                (a, b) => (b.deliveredAt ?? b.createdAt).compareTo(
                  a.deliveredAt ?? a.createdAt,
                ),
              );

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: AdminScrollLayout(
              header: AppTabHeader(title: 'Historial', showLogo: true),
              body: AdminScrollList(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const Text('ENTREGAS CERRADAS', style: AppText.eyebrow),
                  const SizedBox(height: 7),
                  const Text('Tu historial de ruta.', style: AppText.h1),
                  const SizedBox(height: 6),
                  const Text(
                    'Consulta únicamente tus entregas completadas correctamente.',
                    style: AppText.muted,
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Registros', style: AppText.h3),
                      ),
                      Text(
                        '${orders.length} '
                        '${orders.length == 1 ? 'resultado' : 'resultados'}',
                        style: AppText.meta,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (orders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Sin entregas en esta vista',
                        description: 'Aquí aparecerán tus entregas exitosas.',
                      ),
                    )
                  else
                    for (final order in orders) ...[
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
                      if (order != orders.last) const SizedBox(height: 11),
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
    if (order.needsReschedule) {
      return 'Reprogramado · ${order.failureReason ?? 'sin motivo'}';
    }
    final date = order.deliveredAt;
    if (date == null) return 'Entregado';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Entregado el $day/$month · $hour:$minute';
  }
}
