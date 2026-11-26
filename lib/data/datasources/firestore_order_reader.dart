import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/order.dart';
import '../mappers/firestore_order_mapper.dart';

/// Lecturas compartidas. Nunca cambia precios, totales ni documentos históricos.
class FirestoreOrderReader {
  FirestoreOrderReader(this.db);
  final FirebaseFirestore db;

  Stream<PharmacyOrder> watch(
    String id, {
    required String ownerUid,
    required bool Function(Map<String, dynamic>) authorized,
  }) {
    late StreamController<PharmacyOrder> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    var version = 0;
    var cancelled = false;
    Future<void> emit() async {
      final current = ++version;
      try {
        final order = await load(
          id,
          ownerUid: ownerUid,
          authorized: authorized,
        );
        if (!cancelled && current == version) controller.add(order);
      } catch (error, stack) {
        if (!cancelled && current == version) controller.addError(error, stack);
      }
    }

    void onError(Object error, StackTrace stack) {
      if (!cancelled) controller.addError(error, stack);
    }

    final ref = db.collection('pedidos').doc(id);
    controller = StreamController<PharmacyOrder>(
      onListen: () {
        subscriptions.add(
          ref
              .snapshots(includeMetadataChanges: true)
              .listen((_) => emit(), onError: onError),
        );
        for (final name in ['detalle_pedido', 'historial_estado']) {
          subscriptions.add(
            ref
                .collection(name)
                .snapshots()
                .listen((_) => emit(), onError: onError),
          );
        }
      },
      onCancel: () async {
        cancelled = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<PharmacyOrder> load(
    String id, {
    required String ownerUid,
    required bool Function(Map<String, dynamic>) authorized,
    bool server = false,
  }) async {
    final options = GetOptions(
      source: server ? Source.server : Source.serverAndCache,
    );
    final ref = db.collection('pedidos').doc(id);
    final doc = await ref.get(options);
    final data = doc.data();
    if (data == null || !authorized(data)) {
      throw StateError('Pedido no disponible para esta cuenta.');
    }
    final children = await Future.wait([
      ref.collection('detalle_pedido').get(options),
      ref.collection('historial_estado').get(options),
    ]);
    final details = children[0];
    final history = children[1];
    var cached =
        doc.metadata.isFromCache || children.any((s) => s.metadata.isFromCache);
    // Los documentos antiguos contienen referencias, no snapshots de los nombres.
    // Los nombres actuales solo enriquecen la vista; los importes siguen históricos.
    final mapped = Map<String, dynamic>.from(data);
    final lines = details.docs
        .map((d) => Map<String, dynamic>.from(d.data()))
        .toList();
    if (!mapped.containsKey('nombre_farmacia')) {
      final farm = await db
          .collection('farmacia_cliente')
          .doc(data['id_cliente'] as String)
          .get(options);
      cached |= farm.metadata.isFromCache;
      final profile = farm.data() ?? {};
      mapped['nombre_farmacia'] =
          profile['nombre_farmacia'] ?? data['id_cliente'];
      mapped['responsable'] ??= profile['responsable'];
      mapped['telefono'] ??= profile['telefono'];
    }
    if (!mapped.containsKey('entrega') && data['id_direccion'] is String) {
      final address = await db
          .collection('direcciones')
          .doc(data['id_direccion'] as String)
          .get(options);
      cached |= address.metadata.isFromCache;
      mapped['entrega'] = {
        'direccion': address.data()?['direccion'] ?? 'Dirección no disponible',
      };
    }
    for (final line in lines) {
      if (line['nombre'] != null) continue;
      // El cliente no tiene permiso de leer productos históricos inactivos.
      // El ID original es suficiente si ese nombre ya no se puede consultar.
      try {
        final product = await db
            .collection('productos')
            .doc(line['id_producto'] as String)
            .get(options);
        cached |= product.metadata.isFromCache;
        final current = product.data() ?? {};
        line['nombre'] = current['nombre'] ?? line['id_producto'];
        line['presentacion'] ??= current['presentacion'];
        line['unidad_medida'] ??=
            current['unidadMedida'] ?? current['unidad_medida'];
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied' && error.code != 'not-found') {
          rethrow;
        }
      }
    }
    if (!authorized(data)) throw StateError('La sesión cambió.');
    return FirestoreOrderMapper.fromMaps(
      documentId: id,
      ownerUid: ownerUid,
      data: mapped,
      details: lines,
      history: {for (final event in history.docs) event.id: event.data()},
      fromCache: cached,
    );
  }
}
