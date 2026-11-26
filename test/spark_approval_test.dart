import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/domain/spark_approval.dart';

class ApprovalFake implements ApprovalTransaction {
  ApprovalFake({
    this.role = 'vendedor',
    this.active = true,
    this.state = 'pendiente',
    this.eventExists = false,
  });
  final String role;
  final bool active, eventExists;
  final String? state;
  final actions = <String>[];
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String path) async {
    actions.add('read:$path');
    if (path.startsWith('usuarios/')) return {'rol': role, 'estado': active};
    if (path.endsWith('APROBACION')) {
      return eventExists ? {'id_usuario': 'anterior'} : null;
    }
    return state == null
        ? null
        : {'estado': state, 'total': 385, 'id_cliente': 'FARM001'};
  }

  @override
  void update(String path, Map<String, dynamic> values) {
    actions.add('update:$path');
    writes[path] = values;
  }

  @override
  void create(String path, Map<String, dynamic> values) {
    actions.add('create:$path');
    writes[path] = values;
  }
}

Future<void> prepare(ApprovalFake tx, {String id = 'nuevo'}) =>
    SparkApproval.prepare(
      tx,
      uid: 'staff',
      orderId: id,
      serverTimestamp: 'sentinela-del-servidor',
    );

void main() {
  test('el protocolo verificado de aprobación está habilitado', () {
    expect(SparkApproval.enabled, isTrue);
    expect(SparkApproval.blockedReason, contains('habilitada'));
  });

  for (final role in ['vendedor', 'administrador']) {
    test(
      '$role: protocolo de dos escrituras y lecturas antes de escribir',
      () async {
        final tx = ApprovalFake(role: role);
        await prepare(tx);
        expect(tx.actions, [
          'read:usuarios/staff',
          'read:pedidos/nuevo',
          'read:pedidos/nuevo/historial_estado/APROBACION',
          'update:pedidos/nuevo',
          'create:pedidos/nuevo/historial_estado/APROBACION',
        ]);
        expect(tx.writes['pedidos/nuevo'], {
          'estado': 'aprobado',
          'aprobado_por': 'staff',
          'fecha_aprobacion': 'sentinela-del-servidor',
        });
        expect(tx.writes.values.last, {
          'estado_anterior': 'pendiente',
          'estado_nuevo': 'aprobado',
          'fecha_cambio': 'sentinela-del-servidor',
          'id_usuario': 'staff',
        });
        expect(
          tx.writes.keys.any((path) => path.contains('lotes_productos')),
          isFalse,
        );
      },
    );
  }

  for (final role in ['cliente', 'repartidor', 'inventado']) {
    test('$role no prepara una aprobación', () async {
      final tx = ApprovalFake(role: role);
      await expectLater(prepare(tx), throwsStateError);
      expect(tx.writes, isEmpty);
    });
  }

  test('personal inactivo no escribe', () async {
    final tx = ApprovalFake(active: false);
    await expectLater(prepare(tx), throwsStateError);
    expect(tx.writes, isEmpty);
  });

  for (final state in [null, 'aprobado', 'entregado', 'cancelado']) {
    test('estado $state rechaza transición y no toca PED001', () async {
      final tx = ApprovalFake(state: state);
      await expectLater(prepare(tx, id: 'PED001'), throwsStateError);
      expect(tx.writes, isEmpty);
    });
  }

  test('evento existente rechaza aprobación repetida', () async {
    final tx = ApprovalFake(eventExists: true);
    await expectLater(prepare(tx), throwsStateError);
    expect(tx.writes, isEmpty);
  });

  test(
    'identificadores con segmentos arbitrarios no se leen ni escriben',
    () async {
      final tx = ApprovalFake();
      await expectLater(prepare(tx, id: 'otro/documento'), throwsStateError);
      expect(tx.actions, isEmpty);
    },
  );
}
