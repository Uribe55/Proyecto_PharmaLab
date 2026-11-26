import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/domain/commercial_number.dart';
import 'package:proyecto_final_movil/domain/spark_address.dart';
import 'package:proyecto_final_movil/models/delivery_address.dart';

import 'spark_checkout_test.dart'
    show CheckoutTransactionFake, fixtures, prepare;

void main() {
  test(
    'contador sin referencia interna o código incorrecto no escribe',
    () async {
      for (final field in ['ultimo_documento_id', 'ultimo_id']) {
        final data = fixtures();
        data['configuracion/contadores_pedidos']!.remove(field);
        final tx = CheckoutTransactionFake(data);
        await expectLater(prepare(tx), throwsException);
        expect(tx.writes, isEmpty);
      }
    },
  );
  test(
    'reintento histórico v1 conserva idempotencia sin consumir número',
    () async {
      final tx = CheckoutTransactionFake(fixtures());
      await prepare(tx);
      tx.commit();
      final order = tx.documents.entries.firstWhere(
        (entry) =>
            entry.key.startsWith('pedidos/') &&
            !entry.key.substring(8).contains('/'),
      );
      order.value['schema_version'] = 'spark_single_v1';
      order.value['numero_comercial'] = 'PED002';
      tx.documents.remove('configuracion/contadores_pedidos');
      final retry = CheckoutTransactionFake(tx.documents);
      await prepare(retry);
      expect(retry.writes, isEmpty);
    },
  );
  test('códigos 003, 010, 100 y 1000 sin truncar', () {
    for (final n in [3, 10, 100, 1000]) {
      expect(
        CommercialNumber.code('PED', n),
        'PED${n.toString().padLeft(3, '0')}',
      );
    }
  });
  for (final value in [null, '2', 2.0, -1, 0, 999999999]) {
    test('contador mal tipado o fuera de rango $value se bloquea', () async {
      final data = fixtures();
      data['configuracion/contadores_pedidos']!['ultimo_numero'] = value;
      final tx = CheckoutTransactionFake(data);
      await expectLater(prepare(tx), throwsException);
      expect(tx.writes, isEmpty);
    });
  }
  test(
    'pedido PED003 y contador se escriben juntos; reintento no consume número',
    () async {
      final tx = CheckoutTransactionFake(fixtures());
      await prepare(tx);
      expect(tx.writes.values.first['numero_comercial'], 'PED003');
      expect(
        tx.writes['configuracion/contadores_pedidos']!['ultimo_numero'],
        3,
      );
      tx.commit();
      final retry = CheckoutTransactionFake(tx.documents);
      await prepare(retry);
      expect(retry.writes, isEmpty);
    },
  );
  test('no muestra ID aleatorio ni schema al cliente', () {
    expect(
      CommercialNumber.orderLabel('PED-technical', 'technical'),
      'Pedido sin número comercial',
    );
    expect(CommercialNumber.orderLabel(null, 'PED001'), 'PED001');
    expect(CommercialNumber.orderLabel('PED002', 'technical'), 'PED002');
    expect(
      const DeliveryAddress(
        id: 'technical',
        name: 'Casa',
        address: 'Av',
        commercialNumber: 'DIR002',
      ).label,
      'DIR002 · Casa',
    );
  });
  test('dirección DIR003 y contador atómicos con reintento', () async {
    final data = fixtures();
    data['configuracion/contadores_direcciones'] = CommercialNumber.counter(
      'DIR',
      2,
      'existing',
    );
    Future<void> run(CheckoutTransactionFake tx) => SparkAddress.prepare(
      tx,
      uid: 'client',
      farmId: 'FARM001',
      documentId: 'ABCDEFGHIJKLMNOPQRST',
      name: 'Casa',
      address: 'Av',
      reference: '',
    );
    final tx = CheckoutTransactionFake(data);
    await run(tx);
    expect(tx.writes.length, 2);
    expect(
      tx.writes['direcciones/ABCDEFGHIJKLMNOPQRST']!['numero_comercial'],
      'DIR003',
    );
    tx.commit();
    final retry = CheckoutTransactionFake(data);
    await run(retry);
    expect(retry.writes, isEmpty);
  });
}
