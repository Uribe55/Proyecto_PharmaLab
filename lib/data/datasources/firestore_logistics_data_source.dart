import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_gateway.dart';

import '../../models/order.dart';
import '../../services/firebase_environment.dart';
import '../../services/pharma_service.dart';
import '../repositories/logistics_repository.dart';

class FirestoreLogisticsDataSource implements LogisticsRepository {
  FirestoreLogisticsDataSource({FirebaseFirestore? db, PharmaService? session})
    : db = db ?? FirebaseEnvironment.firestore,
      session = session ?? PharmaService.instance;
  final FirebaseFirestore db;
  final PharmaService session;
  String get uid {
    if (!session.usesFirebase ||
        session.uid == null ||
        session.currentUser?.active != true) {
      throw StateError('Sesión no válida.');
    }
    return session.uid!;
  }

  @override
  Stream<List<LogisticsDriver>> watchDrivers() => db
      .collection('empleado')
      .where('cargo', isEqualTo: 'Repartidor')
      .where('estado', isEqualTo: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) =>
                  LogisticsDriver(d.id, d.data()['nombre'] as String? ?? d.id),
            )
            .toList(),
      );
  @override
  Stream<List<DeliveryRecord>> watchDeliveries() async* {
    final actor = uid;
    String? employeeId;
    Query<Map<String, dynamic>> query = db.collection('entregas');
    if (session.role.name == 'repartidor') {
      final employees = await db
          .collection('empleado')
          .where('usuario_id', isEqualTo: actor)
          .get();
      final active = employees.docs
          .where(
            (d) =>
                d.data()['estado'] == true && d.data()['cargo'] == 'Repartidor',
          )
          .toList();
      if (active.length != 1) {
        throw StateError('Empleado activo no identificado de forma única.');
      }
      employeeId = active.single.id;
      query = query.where('id_repartidor', isEqualTo: employeeId);
    }
    await for (final snapshot in query.snapshots(
      includeMetadataChanges: true,
    )) {
      if (uid != actor) throw StateError('La sesión cambió.');
      final names = <String, Future<String>>{};
      final records = await Future.wait(
        snapshot.docs.map((d) async {
          final data = d.data();
          data['from_cache'] =
              snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites;
          if (employeeId == null && data['id_repartidor'] is String) {
            final id = data['id_repartidor'] as String;
            data['repartidor_nombre'] = await names.putIfAbsent(id, () async {
              try {
                final employee = (await db.doc('empleado/$id').get()).data();
                return [employee?['nombre'], employee?['apellido']]
                    .whereType<String>()
                    .where((s) => s.trim().isNotEmpty)
                    .join(' ');
              } catch (_) {
                return '';
              }
            });
          }
          if (data['schema_version'] != 'spark_logistics_v1') {
            final details = await d.reference
                .collection('detalle_entrega')
                .get();
            data['detalles_historicos'] = details.docs
                .map((line) => line.data())
                .toList();
          }
          return DeliveryRecord(d.id, data);
        }),
      );
      if (uid != actor) throw StateError('La sesión cambió.');
      yield records
          .where(
            (record) =>
                employeeId == null ||
                (record.data['id_repartidor'] == employeeId &&
                    (record.data['repartidor_uid'] == null ||
                        record.data['repartidor_uid'] == actor)),
          )
          .toList();
    }
  }

  @override
  Future<void> assign(PharmacyOrder order, String employeeId) async {
    if (order.schemaVersion == 'transactional_multi_v1') {
      await OrderGateway().call('assignMultiOrder', {
        'orderId': order.documentId,
        'employeeId': employeeId,
      });
      return;
    }
    final actor = uid;
    final orderRef = db.collection('pedidos').doc(order.documentId!);
    final delivery = db.collection('entregas').doc();
    await db.runTransaction((tx) async {
      final o = (await tx.get(orderRef)).data()!;
      final emp = (await tx.get(db.doc('empleado/$employeeId'))).data()!;
      final farm = (await tx.get(db.doc('farmacia_cliente/${o['id_cliente']}')))
          .data()!;
      final address = (await tx.get(db.doc('direcciones/${o['id_direccion']}')))
          .data()!;
      final line = (await tx.get(
        orderRef.collection('detalle_pedido').doc('DET001'),
      )).data();
      final product = line == null
          ? null
          : (await tx.get(db.doc('productos/${line['id_producto']}'))).data();
      if (uid != actor ||
          o['estado'] != 'aprobado' ||
          o['id_entrega'] != null ||
          o['schema_version'] != 'spark_single_v2' ||
          line == null ||
          emp['estado'] != true ||
          emp['cargo'] != 'Repartidor') {
        throw StateError(
          'Pedido o repartidor no disponible. Solo pedidos Spark actuales sin entrega previa.',
        );
      }
      tx.set(delivery, {
        'schema_version': 'spark_logistics_v1',
        'estado': 'asignada',
        'fecha_creacion': FieldValue.serverTimestamp(),
        'fecha_programada': null,
        'id_pedido': orderRef.id,
        'id_repartidor': employeeId,
        'repartidor_uid': emp['usuario_id'],
        'asignado_por': actor,
        'numero_comercial': 'ENT-${o['numero_comercial']}',
        'pedido_numero': o['numero_comercial'],
        'farmacia': farm['nombre_farmacia'],
        'contacto': farm['responsable'],
        'telefono': farm['telefono'],
        'direccion': address['direccion'],
        'referencia': address['referencia'] ?? '',
        'producto': line['id_producto'],
        'cantidad': line['cantidad'],
        'producto_nombre': product?['nombre'] ?? line['id_producto'],
      });
      tx.set(delivery.collection('detalle_entrega').doc('DENT001'), {
        'id_detalle_pedido': 'DET001',
        'cantidad_programada': line['cantidad'],
        'cantidad_entregada': 0,
      });
      tx.update(orderRef, {'id_entrega': delivery.id});
    });
  }

  @override
  Future<void> transition(
    DeliveryRecord delivery,
    String state, {
    String reason = '',
    String note = '',
  }) async {
    final actor = uid;
    if (delivery.data['schema_version'] == 'transactional_logistics_v1') {
      await OrderGateway().call('transitionMultiDelivery', {
        'deliveryId': delivery.id,
        'state': state,
        'reason': reason,
        'note': note,
      });
      if (uid != actor) throw StateError('La sesión cambió.');
      return;
    }
    await db.runTransaction((tx) async {
      final ref = db.doc('entregas/${delivery.id}');
      final d = (await tx.get(ref)).data()!;
      final order = db.doc('pedidos/${d['id_pedido']}');
      final o = <String, dynamic>{
        'estado': d['estado'] == 'asignada' ? 'aprobado' : d['estado'],
      };
      final before = state == 'en_ruta' ? 'asignada' : 'en_ruta';
      if (uid != actor ||
          d['repartidor_uid'] != actor ||
          d['estado'] != before ||
          !['en_ruta', 'entregado', 'fallida'].contains(state)) {
        throw StateError('Transición no disponible. Actualiza la entrega.');
      }
      if (state == 'fallida' &&
          (reason.trim().isEmpty || reason.length > 100 || note.length > 180)) {
        throw StateError(
          'Indica un motivo válido y una observación de hasta 180 caracteres.',
        );
      }
      tx.update(ref, {
        'estado': state,
        'fecha_estado': FieldValue.serverTimestamp(),
        'motivo': state == 'fallida' ? reason.trim() : '',
        'observacion': state == 'fallida' ? note.trim() : '',
      });
      tx.update(order, {
        'estado': state,
        'fecha_logistica': FieldValue.serverTimestamp(),
      });
      tx.set(order.collection('historial_estado').doc('LOG_$state'), {
        'estado_anterior': o['estado'],
        'estado_nuevo': state,
        'fecha_cambio': FieldValue.serverTimestamp(),
        'id_usuario': actor,
        'observaciones': state == 'fallida'
            ? '${reason.trim()}: ${note.trim()}'
            : '',
      });
      if (state == 'entregado') {
        tx.update(ref.collection('detalle_entrega').doc('DENT001'), {
          'cantidad_entregada': d['cantidad'],
        });
      }
    });
  }
}
