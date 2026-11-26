import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/logistics_repository.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/viewmodels/logistics_view_model.dart';

class _Repository implements LogisticsRepository {
  final completion = Completer<void>();
  int calls = 0;
  String? reason, note;
  @override
  Future<void> transition(
    DeliveryRecord delivery,
    String state, {
    String reason = '',
    String note = '',
  }) {
    calls++;
    this.reason = reason;
    this.note = note;
    return completion.future;
  }

  @override
  Future<void> assign(PharmacyOrder order, String employeeId) =>
      completion.future;
  @override
  Stream<List<DeliveryRecord>> watchDeliveries() => const Stream.empty();
  @override
  Stream<List<LogisticsDriver>> watchDrivers() => const Stream.empty();
}

void main() {
  const delivery = DeliveryRecord('delivery', {});
  test('doble pulsación no envía dos transiciones', () async {
    final repository = _Repository();
    final vm = LogisticsViewModel(repository);
    final first = vm.transition(delivery, 'en_ruta');
    expect(vm.busy, true);
    expect(await vm.transition(delivery, 'en_ruta'), false);
    expect(repository.calls, 1);
    repository.completion.complete();
    expect(await first, true);
    expect(vm.busy, false);
    vm.dispose();
  });
  test('rechazo remoto conserva error y libera la acción', () async {
    final repository = _Repository();
    final vm = LogisticsViewModel(repository);
    final pending = vm.transition(
      delivery,
      'fallida',
      reason: 'Cerrada',
      note: 'Sin atención',
    );
    repository.completion.completeError(StateError('permission-denied'));
    expect(await pending, false);
    expect(vm.error, contains('permission-denied'));
    expect(vm.busy, false);
    expect(repository.reason, 'Cerrada');
    expect(repository.note, 'Sin atención');
    vm.dispose();
  });
  test(
    'salir de pantalla durante escritura no notifica un modelo eliminado',
    () async {
      final repository = _Repository();
      final vm = LogisticsViewModel(repository);
      final pending = vm.transition(delivery, 'entregado');
      vm.dispose();
      repository.completion.complete();
      expect(await pending, true);
    },
  );
}
