import 'package:flutter/material.dart';

import '../domain/order_policy.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../models/order_lifecycle.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/order_view_model.dart';

String orderActionLabel(OrderAction action) => switch (action) {
  OrderAction.confirm => 'Confirmación local',
  OrderAction.approve => 'Aprobar pedido',
  OrderAction.assign => 'Asignar o reasignar repartidor',
  OrderAction.dispatch => 'Iniciar ruta',
  OrderAction.cancel => 'Cancelar pedido',
  OrderAction.requestCancellation => 'Solicitar cancelación',
  OrderAction.acceptCancellation => 'Aprobar cancelación',
  OrderAction.rejectCancellation => 'Rechazar cancelación',
  OrderAction.incident => 'Reportar incidencia',
  OrderAction.fail => 'Registrar intento fallido',
  OrderAction.reschedule => 'Reprogramar entrega',
  OrderAction.deliver => 'Confirmar entrega',
  OrderAction.coordinate => 'Mantener en coordinación',
  OrderAction.escalate => 'Escalar incidencia',
};

/// Acciones compartidas con política central y trazabilidad, sin reglas en widgets.
class OrderLifecyclePanel extends StatefulWidget {
  const OrderLifecyclePanel({
    super.key,
    required this.order,
    this.showActions = true,
  });
  final PharmacyOrder order;
  final bool showActions;
  @override
  State<OrderLifecyclePanel> createState() => _OrderLifecyclePanelState();
}

class _OrderLifecyclePanelState extends State<OrderLifecyclePanel> {
  final vm = OrderViewModel();
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Future<void> _run(OrderAction action) async {
    final reason = TextEditingController();
    final note = TextEditingController();
    AppUser? driver;
    final requiresReason = {
      OrderAction.cancel,
      OrderAction.requestCancellation,
      OrderAction.acceptCancellation,
      OrderAction.rejectCancellation,
      OrderAction.incident,
      OrderAction.fail,
      OrderAction.reschedule,
      OrderAction.coordinate,
      OrderAction.escalate,
    }.contains(action);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(orderActionLabel(action)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pedido ${widget.order.number}', style: AppText.muted),
              if (action == OrderAction.assign)
                DropdownButtonFormField<AppUser>(
                  isExpanded: true,
                  items: [
                    for (final user in vm.service.drivers)
                      DropdownMenuItem(value: user, child: Text(user.name)),
                  ],
                  onChanged: (value) => driver = value,
                  decoration: const InputDecoration(labelText: 'Repartidor'),
                ),
              if (requiresReason)
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    hintText: 'Indica el motivo de esta acción',
                  ),
                ),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                ),
                maxLines: 2,
              ),
              if (action == OrderAction.incident)
                const Text(
                  'Reportar un problema no cancela el pedido ni cierra el intento.',
                  style: AppText.meta,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    final reasonText = reason.text;
    final noteText = note.text;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    reason.dispose();
    note.dispose();
    if (confirmed != true || !mounted) return;
    DateTime? scheduled;
    if (action == OrderAction.reschedule) {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          now.add(const Duration(minutes: 5)),
        ),
      );
      if (time == null || !mounted) return;
      scheduled = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }
    final sync = SyncService.instance;
    final offlineEvent =
        sync.isOffline &&
        {
          OrderAction.incident,
          OrderAction.fail,
          OrderAction.deliver,
        }.contains(action) &&
        vm.service.role == UserRole.repartidor;
    final ok = offlineEvent
        ? sync.queueAction(
            widget.order,
            action,
            reason: reasonText,
            note: noteText,
          )
        : vm.act(
            widget.order,
            action,
            reason: reasonText,
            note: noteText,
            driver: driver,
            scheduledFor: scheduled,
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (offlineEvent
                    ? 'Evento guardado en memoria; pendiente de sincronización local.'
                    : 'Operación registrada en el historial.')
              : (offlineEvent ? sync.lastError : vm.error) ??
                    'No se pudo realizar la acción.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm.service, vm, SyncService.instance]),
    builder: (context, _) {
      final order = widget.order;
      if (!OrderPolicy.canRead(order, vm.service.currentUser)) {
        return const SizedBox.shrink();
      }
      final pending = order.pendingCancellation;
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Operaciones e historial', style: AppText.h3),
              Text('Estado: ${order.status.label}', style: AppText.label),
              if (vm.service.usesFirebase || order.remote)
                const Text(
                  'Operaciones comerciales Firebase pendientes de integración. Solo consulta.',
                  style: AppText.muted,
                ),
              if (order.status == OrderStatus.cancelado)
                Text(
                  'Cancelado: ${order.cancellationReason ?? ''}',
                  style: AppText.muted,
                ),
              if (order.driverId != null)
                Text(
                  'Asignado a ${order.driverName ?? order.driverId} · ${order.assignedAt == null ? 'Asignación histórica' : formatOrderDate(order.assignedAt!)}',
                  style: AppText.meta,
                ),
              if (order.isApproved && order.driverId != null)
                const Text(
                  'Asignado; todavía no despachado.',
                  style: AppText.label,
                ),
              if (order.rescheduledFor != null)
                Text(
                  'Reprogramado: ${formatOrderDate(order.rescheduledFor!)}',
                  style: AppText.muted,
                ),
              if (pending != null)
                Text(
                  'Solicitud de cancelación pendiente: ${pending.reason}',
                  style: AppText.label,
                ),
              for (final request in order.cancellationRequests.where(
                (r) => r.status != CancellationStatus.pending,
              ))
                Text(
                  'Cancelación ${request.status == CancellationStatus.accepted ? 'aprobada' : 'rechazada'}: ${request.resolution ?? ''}',
                  style: AppText.muted,
                ),
              if (widget.showActions)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final action in OrderAction.values.where(
                      (a) => a != OrderAction.confirm && vm.can(order, a),
                    ))
                      OutlinedButton(
                        onPressed: vm.busy ? null : () => _run(action),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        child: Text(orderActionLabel(action)),
                      ),
                  ],
                ),
              for (final incident in order.incidents)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${incident.reason} · ${incident.note}\n${incident.outcome} · ${formatOrderDate(incident.at)}',
                    style: AppText.muted,
                  ),
                ),
              for (final attempt in order.attempts)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Intento ${attempt.number} · ${switch (attempt.result) {
                      AttemptResult.prepared => 'Preparado',
                      AttemptResult.inProgress => 'En curso',
                      AttemptResult.failed => 'Fallido',
                      AttemptResult.delivered => 'Entregado',
                    }}\nRepartidor: ${attempt.driverId} · ${attempt.reason ?? ''} ${attempt.note}\nInicio: ${attempt.startedAt == null ? 'Pendiente' : formatOrderDate(attempt.startedAt!)} · Cierre: ${attempt.closedAt == null ? 'Pendiente' : formatOrderDate(attempt.closedAt!)}',
                    style: AppText.meta,
                  ),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Historial de decisiones',
                  style: AppText.label,
                ),
                children: [
                  if (order.history.isEmpty)
                    const Text(
                      'Pedido histórico: no hay registro detallado de operaciones previas.',
                      style: AppText.meta,
                    ),
                  for (final event in order.history)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${event.operation} · ${event.before.label} → ${event.after.label}',
                        style: AppText.label,
                      ),
                      subtitle: Text(
                        '${formatOrderDate(event.at)} · ${event.actorId} (${event.role.label})\n${event.note}',
                        style: AppText.meta,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
