import 'app_user.dart';
import 'order.dart';

enum OrderAction {
  confirm,
  approve,
  assign,
  dispatch,
  cancel,
  requestCancellation,
  acceptCancellation,
  rejectCancellation,
  incident,
  fail,
  reschedule,
  deliver,
  coordinate,
  escalate,
}

enum CancellationStatus { pending, accepted, rejected }

enum AttemptResult { prepared, inProgress, failed, delivered }

class CancellationRequest {
  CancellationRequest({
    required this.id,
    required this.requestedBy,
    required this.reason,
    required this.requestedAt,
  });
  final String id, requestedBy, reason;
  final DateTime requestedAt;
  CancellationStatus status = CancellationStatus.pending;
  String? resolvedBy, resolution;
  DateTime? resolvedAt;
}

class DeliveryAttempt {
  DeliveryAttempt({
    required this.id,
    required this.orderNumber,
    required this.number,
    required this.driverId,
    this.startedAt,
    this.closedAt,
    this.result = AttemptResult.prepared,
    this.reason,
    this.note = '',
  });
  final String id, orderNumber;
  final int number;
  String driverId;
  DateTime? startedAt, closedAt;
  AttemptResult result;
  String? reason;
  String note;
}

class DeliveryIncident {
  const DeliveryIncident({
    required this.id,
    required this.orderNumber,
    required this.actorId,
    required this.reason,
    required this.note,
    required this.at,
    required this.attemptId,
    required this.outcome,
  });
  final String id, orderNumber, actorId, reason, note, outcome;
  final DateTime at;
  final String? attemptId;
}

/// Registro listo para serializar en pedidos/{id}/historial_estado. Solo memoria.
class OrderHistoryEvent {
  const OrderHistoryEvent({
    required this.id,
    required this.orderNumber,
    required this.before,
    required this.after,
    required this.operation,
    required this.at,
    required this.actorId,
    required this.role,
    this.note = '',
    this.atKnown = true,
  });
  final String id, orderNumber, actorId, note;
  final OrderStatus before, after;
  final String operation;
  final DateTime at;
  final bool atKnown;
  final UserRole? role;
  Map<String, Object?> toMap() => {
    'id': id,
    'pedido_id': orderNumber,
    'estado_anterior': before.name,
    'estado_nuevo': after.name,
    'operacion': operation,
    'fecha': at.toUtc().toIso8601String(),
    'usuario_id': actorId,
    'rol': role?.name,
    'observaciones': note,
  };
}

/// Preparación para la futura transacción por lote; no realiza escrituras.
class LotStockAllocation {
  const LotStockAllocation({
    required this.productId,
    required this.batchId,
    required this.quantity,
  });
  final String productId, batchId;
  final int quantity;
}
