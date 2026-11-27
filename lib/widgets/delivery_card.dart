import 'package:flutter/material.dart';

import '../data/repositories/logistics_repository.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Resumen operativo compartido; los detalles secundarios quedan en un modal.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    this.actions = const [],
    this.onTap,
    this.showDriver = false,
    this.amount,
    this.caption,
  });
  final DeliveryRecord delivery;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool showDriver;
  final double? amount;
  final String? caption;
  @override
  Widget build(BuildContext context) {
    final d = delivery.data;
    final state = delivery.state;
    final attention = [
      'asignada',
      'aprobado',
      'en_ruta',
      'enruta',
    ].contains(state);
    final color = delivery.delivered
        ? AppColors.successText
        : state.contains('fall')
        ? AppColors.danger
        : AppColors.primary;
    final background = delivery.delivered
        ? AppColors.successBackground
        : state.contains('fall')
        ? AppColors.dangerBackground
        : AppColors.mint;
    final label = switch (state) {
      'asignada' => 'Asignada',
      'aprobado' => 'Por asignar',
      'en_ruta' || 'enruta' => 'En ruta',
      'entregado' => 'Entregada',
      'fallida' || 'entrega_fallida' => 'Fallida',
      _ => (d['estado'] ?? 'Sin estado').toString(),
    };
    final pharmacy = (d['farmacia'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: attention
              ? AppColors.primary.withValues(alpha: .35)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      color: color,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (d['pedido_numero'] ??
                                  d['id_pedido'] ??
                                  'Pedido sin número')
                              .toString(),
                          style: AppText.h3,
                        ),
                        if (delivery.id.isNotEmpty)
                          Text(
                            (d['numero_comercial'] ?? delivery.id).toString(),
                            style: AppText.meta,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (pharmacy.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(pharmacy, style: AppText.label),
              ],
              const SizedBox(height: 8),
              _DeliveryInfo(
                icon: Icons.location_on_outlined,
                text: (d['direccion'] ?? 'Dirección no registrada').toString(),
              ),
              if ((d['telefono'] ?? '').toString().isNotEmpty)
                _DeliveryInfo(
                  icon: Icons.phone_outlined,
                  text: d['telefono'].toString(),
                ),
              if (showDriver)
                _DeliveryInfo(
                  icon: Icons.person_outline,
                  text: (d['repartidor_nombre'] ?? '').toString().isNotEmpty
                      ? d['repartidor_nombre'].toString()
                      : (d['id_repartidor'] ?? 'Sin repartidor asignado')
                            .toString(),
                ),
              if (delivery.assignedAt != null)
                _DeliveryInfo(
                  icon: Icons.event_outlined,
                  text: 'Asignación: ${formatOrderDate(delivery.assignedAt!)}',
                ),
              if (delivery.delivered && delivery.completedAt != null)
                _DeliveryInfo(
                  icon: Icons.check_circle_outline,
                  text: 'Entrega: ${formatOrderDate(delivery.completedAt!)}',
                ),
              if (caption != null) Text(caption!, style: AppText.meta),
              if (amount != null) Text(formatBs(amount!), style: AppText.h3),
              if (d['from_cache'] == true)
                const Text(
                  'Información guardada · acciones pendientes de conexión',
                  style: AppText.meta,
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        onTap ??
                        () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (d['pedido_numero'] ?? delivery.id)
                                        .toString(),
                                    style: AppText.h2,
                                  ),
                                  for (final key in [
                                    'contacto',
                                    'referencia',
                                    'producto_nombre',
                                    'cantidad',
                                    'motivo',
                                    'observacion',
                                  ])
                                    if ((d[key] ?? '').toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          '$key: ${d[key]}',
                                          style: AppText.muted,
                                        ),
                                      ),
                                  for (final line
                                      in d['productos'] as List? ?? [])
                                    Text(
                                      '${line['nombre']} · ${line['presentacion']} · ${line['cantidad']} ${line['unidad_medida']}',
                                      style: AppText.muted,
                                    ),
                                  for (final line
                                      in d['detalles_historicos'] as List? ??
                                          [])
                                    Text(
                                      '${line['cantidad_programada']} programadas · ${line['cantidad_entregada']} entregadas',
                                      style: AppText.muted,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Ver detalle'),
                  ),
                  ...actions,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryInfo extends StatelessWidget {
  const _DeliveryInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.meta)),
      ],
    ),
  );
}

class OrderDeliveryCard extends StatelessWidget {
  const OrderDeliveryCard({
    super.key,
    required this.order,
    this.showTotal = true,
    this.caption,
    this.onTap,
  });
  final PharmacyOrder order;
  final bool showTotal;
  final String? caption;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DeliveryCard(
    delivery: DeliveryRecord(order.deliveryId ?? '', {
      'pedido_numero': order.number,
      'farmacia': order.pharmacyName,
      'direccion': order.address,
      'telefono': order.contactPhone,
      'repartidor_nombre': order.driverName,
      'estado': order.status == OrderStatus.enRuta
          ? 'en_ruta'
          : order.status.name,
      'fecha_creacion': order.assignedAt,
      'fecha_estado': order.deliveredAt,
    }),
    amount: showTotal ? order.total : null,
    caption: caption,
    showDriver: showTotal,
    onTap: onTap,
  );
}
