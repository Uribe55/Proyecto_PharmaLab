import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/remote_order_repository.dart';
import 'package:proyecto_final_movil/domain/spark_approval.dart';
import 'package:proyecto_final_movil/domain/spark_checkout.dart';

const operationId = 'ABCDEFGHIJKLMNOPQRST';
final now = DateTime.utc(2026, 11, 25);
Map<String, dynamic> request({int quantity = 2, int price = 15000}) => {
  'operationId': operationId,
  'addressId': 'DIR001',
  'notes': '',
  'items': [
    {'productId': 'PROD001', 'quantity': quantity, 'expectedPriceCents': price},
  ],
};
Map<String, Map<String, dynamic>> fixtures() => {
  'configuracion/contadores_pedidos': {
    'ultimo_numero': 2,
    'ultimo_id': 'PED002',
    'ultimo_documento_id': 'existingOrder',
  },
  'usuarios/client': {'rol': 'cliente', 'estado': true},
  'farmacia_cliente/FARM001': {'usuario_id': 'client', 'estado': true},
  'direcciones/DIR001': {'id_cliente': 'FARM001', 'estado': true},
  'productos/PROD001': {
    'precio': 150,
    'estado': true,
    'requiere_vencimiento': true,
  },
  'lotes_productos/LOTE001': {
    'producto_id': 'PROD001',
    'cantidad_disponible': 100,
    'fecha_vencimiento': DateTime.utc(2099),
  },
};

class CheckoutTransactionFake implements ApprovalTransaction {
  CheckoutTransactionFake(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  final writes = <String, Map<String, dynamic>>{};
  final updates = <String>{};
  bool writing = false;
  int reads = 0;
  @override
  Future<Map<String, dynamic>?> read(String path) async {
    expect(
      writing,
      isFalse,
      reason: 'Todas las lecturas deben preceder a las escrituras',
    );
    reads++;
    return documents[path];
  }

  @override
  void create(String path, Map<String, dynamic> values) {
    writing = true;
    writes[path] = values;
  }

  @override
  void update(String path, Map<String, dynamic> values) {
    writing = true;
    updates.add(path);
    writes[path] = values;
  }

  void commit() {
    for (final entry in writes.entries) {
      documents[entry.key] = {
        ...?updates.contains(entry.key) ? documents[entry.key] : null,
        ...entry.value,
      };
    }
  }
}

Future<void> prepare(
  CheckoutTransactionFake tx, [
  Map<String, dynamic>? data,
]) => SparkCheckout.prepare(
  tx,
  uid: 'client',
  farmId: 'FARM001',
  lotId: 'LOTE001',
  request: data ?? request(),
  serverTimestamp: 'SERVER',
  now: now,
);

void main() {
  test(
    'seis escrituras atómicas y dos cajas descuentan 2, no 40 tabletas',
    () async {
      final tx = CheckoutTransactionFake(fixtures());
      await prepare(tx);
      expect(tx.reads, 8);
      expect(tx.writes.length, 6);
      final order = tx.writes['pedidos/$operationId']!;
      expect(order['estado'], 'pendiente');
      expect(order['fecha_pedido'], 'SERVER');
      expect(order['total'], 300);
      expect(
        order['linea'],
        tx.writes['pedidos/$operationId/detalle_pedido/DET001'],
      );
      expect(tx.writes['lotes_productos/LOTE001']!['cantidad_disponible'], 98);
      expect(tx.writes.containsKey('pedidos/PED001'), isFalse);
      expect(
        tx.writes.containsKey('configuracion/contadores_farmacia'),
        isFalse,
      );
    },
  );

  test(
    'reintento idempotente no descuenta otra vez aunque cambie el stock',
    () async {
      final data = fixtures();
      final first = CheckoutTransactionFake(data);
      await prepare(first);
      first.commit();
      final retry = CheckoutTransactionFake(data);
      await prepare(retry);
      expect(retry.writes, isEmpty);
      expect(data['lotes_productos/LOTE001']!['cantidad_disponible'], 98);
    },
  );

  test(
    'mismo ID con cantidades diferentes no reemplaza la operación',
    () async {
      final data = fixtures(), first = CheckoutTransactionFake(fixtures());
      await prepare(first);
      first.commit();
      data.addAll(first.documents);
      final retry = CheckoutTransactionFake(data);
      await expectLater(
        prepare(retry, request(quantity: 3)),
        throwsA(isA<RemoteOrderException>()),
      );
      expect(retry.writes, isEmpty);
    },
  );

  final invalid = <String, void Function(Map<String, Map<String, dynamic>>)>{
    'cliente inactivo': (d) => d['usuarios/client']!['estado'] = false,
    'rol vendedor': (d) => d['usuarios/client']!['rol'] = 'vendedor',
    'farmacia ajena': (d) =>
        d['farmacia_cliente/FARM001']!['usuario_id'] = 'other',
    'farmacia inactiva': (d) =>
        d['farmacia_cliente/FARM001']!['estado'] = false,
    'dirección ajena': (d) =>
        d['direcciones/DIR001']!['id_cliente'] = 'FARM002',
    'dirección inactiva': (d) => d['direcciones/DIR001']!['estado'] = false,
    'producto ausente': (d) => d.remove('productos/PROD001'),
    'producto inactivo': (d) => d['productos/PROD001']!['estado'] = false,
    'stock insuficiente': (d) =>
        d['lotes_productos/LOTE001']!['cantidad_disponible'] = 1,
    'stock no entero': (d) =>
        d['lotes_productos/LOTE001']!['cantidad_disponible'] = 2.5,
    'lote de otro producto': (d) =>
        d['lotes_productos/LOTE001']!['producto_id'] = 'PROD002',
    'lote vencido': (d) =>
        d['lotes_productos/LOTE001']!['fecha_vencimiento'] = DateTime.utc(2000),
    'lote sin vencimiento requerido': (d) =>
        d['lotes_productos/LOTE001']!.remove('fecha_vencimiento'),
  };
  for (final entry in invalid.entries) {
    test('${entry.key}: cero escrituras', () async {
      final data = fixtures();
      entry.value(data);
      final tx = CheckoutTransactionFake(data);
      await expectLater(prepare(tx), throwsA(isA<RemoteOrderException>()));
      expect(tx.writes, isEmpty);
    });
  }

  test('precio vigente distinto exige revisión antes de comprar', () async {
    final data = fixtures();
    data['productos/PROD001']!['precio'] = 170;
    final tx = CheckoutTransactionFake(data);
    try {
      await prepare(tx);
      fail('Debía exigir revisión');
    } on RemoteOrderException catch (e) {
      expect(e.definitive, isTrue);
      expect(e.prices, {'PROD001': 17000});
      expect(tx.writes, isEmpty);
    }
  });

  for (final quantity in [0, -1, 1001]) {
    test('cantidad $quantity no permitida', () async {
      final tx = CheckoutTransactionFake(fixtures());
      await expectLater(
        prepare(tx, request(quantity: quantity)),
        throwsA(isA<RemoteOrderException>()),
      );
      expect(tx.reads, 0);
    });
  }

  test('dos productos no se descartan ni se compran parcialmente', () async {
    final input = request();
    (input['items'] as List).add({
      'productId': 'PROD002',
      'quantity': 1,
      'expectedPriceCents': 8500,
    });
    final tx = CheckoutTransactionFake(fixtures());
    await expectLater(prepare(tx, input), throwsA(isA<RemoteOrderException>()));
    expect((input['items'] as List).length, 2);
    expect(tx.reads, 0);
    expect(tx.writes, isEmpty);
  });
}
