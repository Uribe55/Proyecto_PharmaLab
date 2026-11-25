import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/mappers/firestore_order_mapper.dart';
import 'package:proyecto_final_movil/models/order.dart';

void main() {
  test(
    'Lee el historial existente sin migrarlo ni inventar el rol del actor',
    () {
      final stamp = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
      final order = FirestoreOrderMapper.fromMaps(
        documentId: 'PED001',
        ownerUid: 'cliente',
        data: {
          'estado': 'aprobado',
          'fecha_pedido': stamp,
          'id_cliente': 'FARM001',
          'id_direccion': 'DIR001',
          'total': 235,
        },
        details: [
          {
            'id_producto': 'PROD001',
            'cantidad': 1,
            'precio_unitario': 150,
            'subtotal': 150,
          },
          {
            'id_producto': 'PROD002',
            'cantidad': 1,
            'precio_unitario': 85,
            'subtotal': 85,
          },
        ],
        history: {
          'HIST001': {
            'estado_anterior': 'pendiente',
            'estado_nuevo': 'aprobado',
            'fecha_cambio': stamp,
            'id_usuario': 'vendedor-existente',
          },
        },
      );
      expect(order.number, 'PED001');
      expect(order.total, 235);
      expect(order.history.single.at, stamp.toDate());
      expect(order.history.single.actorId, 'vendedor-existente');
      expect(order.history.single.role, isNull);
      expect(order.history.single.after, OrderStatus.aprobado);
      expect(order.history.single.toMap()['rol'], isNull);
    },
  );
}
