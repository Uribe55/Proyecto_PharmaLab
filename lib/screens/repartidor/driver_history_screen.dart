import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_list_tile.dart';
import 'driver_delivery_detail_screen.dart';

/// Historial de entregas del repartidor (RF-13).
class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  bool? _deliveredOnly;

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
        final finished =
            all
                .where(
                  (order) =>
                      order.status.isFinal ||
                      order.status.isFailure ||
                      order.attempts.any((attempt) => attempt.closedAt != null),
                )
                .toList()
              ..sort((a, b) {
                final dateA = a.deliveredAt ?? a.failedAt ?? a.createdAt;
                final dateB = b.deliveredAt ?? b.failedAt ?? b.createdAt;
                return dateB.compareTo(dateA);
              });
        final orders = _deliveredOnly == null
            ? finished
            : finished
                  .where((order) => order.status.isDelivered == _deliveredOnly)
                  .toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const AppTabHeader(title: 'Historial'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const Text('ENTREGAS CERRADAS', style: AppText.eyebrow),
                      const SizedBox(height: 7),
                      const Text('Tu historial de ruta.', style: AppText.h1),
                      const SizedBox(height: 6),
                      const Text(
                        'Consulta las entregas completadas y las incidencias '
                        'que registraste.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _HistoryFilter(
                              label: 'Todas',
                              selected: _deliveredOnly == null,
                              onTap: () =>
                                  setState(() => _deliveredOnly = null),
                            ),
                            const SizedBox(width: 8),
                            _HistoryFilter(
                              label: 'Entregadas',
                              selected: _deliveredOnly == true,
                              onTap: () =>
                                  setState(() => _deliveredOnly = true),
                            ),
                            const SizedBox(width: 8),
                            _HistoryFilter(
                              label: 'Fallidas',
                              selected: _deliveredOnly == false,
                              onTap: () =>
                                  setState(() => _deliveredOnly = false),
                            ),
                          ],
                        ),
                      ),
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
                            description: _deliveredOnly == null
                                ? 'Cuando cierres una entrega o registres una '
                                      'incidencia aparecerá en tu historial.'
                                : 'No tienes registros con el filtro '
                                      'seleccionado.',
                          ),
                        )
                      else
                        for (final order in orders) ...[
                          OrderListTile(
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
              ],
            ),
          ),
        );
      },
    );
  }

  String _captionFor(PharmacyOrder order) {
    if (order.status.isFailure) {
      return 'Entrega fallida · ${order.failureReason ?? 'sin motivo'}';
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

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
