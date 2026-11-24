import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../models/order_lifecycle.dart';
import '../../viewmodels/order_view_model.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/user_avatar.dart';

/// Asignación de un pedido aprobado a un repartidor (RF-12).
class SellerAssignScreen extends StatefulWidget {
  const SellerAssignScreen({super.key, required this.order});

  final PharmacyOrder order;

  @override
  State<SellerAssignScreen> createState() => _SellerAssignScreenState();
}

class _SellerAssignScreenState extends State<SellerAssignScreen> {
  String? _selectedDriverId;

  Future<void> _assign(AppUser driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asignar entrega'),
        content: Text(
          'El pedido ${widget.order.number} quedará asignado, sin iniciar ruta, a cargo de '
          '${driver.name}.',
          style: AppText.muted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Asignar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final assigned = OrderViewModel.instance.act(
      widget.order,
      OrderAction.assign,
      driver: driver,
    );
    if (!assigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo asignar. Verifica el estado del pedido.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Entrega asignada a ${driver.name}.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final service = PharmaService.instance;
        final drivers = service.drivers;
        final selected = _findDriver(drivers);
        final canAssign = widget.order.canAssignDriver;

        return Scaffold(
          appBar: const AppPageAppBar(title: 'Asignación de entrega'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              const Text('ASIGNAR REPARTIDOR', style: AppText.eyebrow),
              const SizedBox(height: 7),
              const Text('¿Quién lleva el pedido?', style: AppText.h1),
              const SizedBox(height: 6),
              const Text(
                'Elige un repartidor activo. Solo verá sus propias entregas.',
                style: AppText.muted,
              ),
              const SizedBox(height: 18),
              _OrderSummary(order: widget.order),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text('Repartidores disponibles', style: AppText.h3),
                  ),
                  Text('${drivers.length}', style: AppText.meta),
                ],
              ),
              const SizedBox(height: 12),
              if (drivers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 22),
                  child: EmptyState(
                    icon: Icons.no_transfer_outlined,
                    title: 'Sin repartidores activos',
                    description:
                        'El administrador debe crear o activar una cuenta de '
                        'repartidor para continuar.',
                  ),
                )
              else
                for (final driver in drivers) ...[
                  _DriverCard(
                    driver: driver,
                    deliveries: service.activeDeliveriesFor(driver.id),
                    selected: driver.id == _selectedDriverId,
                    onTap: canAssign
                        ? () => setState(() => _selectedDriverId = driver.id)
                        : null,
                  ),
                  if (driver != drivers.last) const SizedBox(height: 10),
                ],
              if (!canAssign) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.pendingBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.pendingText,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este pedido ya no está pendiente de asignación.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: AppColors.pendingText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ElevatedButton.icon(
                onPressed: selected == null || !canAssign
                    ? null
                    : () => _assign(selected),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(
                  selected == null
                      ? 'Selecciona un repartidor'
                      : 'Asignar a ${selected.firstName}',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  AppUser? _findDriver(List<AppUser> drivers) {
    for (final driver in drivers) {
      if (driver.id == _selectedDriverId) return driver;
    }
    return null;
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final PharmacyOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h3.copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: order.status, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.pharmacyName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  order.address,
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.items.length} productos · ${order.totalUnits} unidades',
            style: AppText.meta.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.deliveries,
    required this.selected,
    required this.onTap,
  });

  final AppUser driver;
  final int deliveries;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.mint.withValues(alpha: 0.6)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              UserAvatar(size: 40, user: driver),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driver.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deliveries == 1
                          ? '1 entrega en ruta'
                          : '$deliveries entregas en ruta',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : AppColors.surface,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
