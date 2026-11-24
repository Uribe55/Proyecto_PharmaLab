import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/delivery_address.dart';
import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../services/firebase_environment.dart';
import '../mappers/firestore_order_mapper.dart';
import '../repositories/remote_order_repository.dart';

class FirestoreOrderDataSource implements RemoteOrderRepository {
  FirestoreOrderDataSource({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
    PharmaService? session,
  }) : _db = db ?? FirebaseEnvironment.firestore,
       _functions = functions ?? FirebaseEnvironment.functions,
       _session = session ?? PharmaService.instance;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final PharmaService _session;
  String get _farm =>
      _session.pharmacyId ?? (throw StateError('Farmacia no identificada.'));
  String get _uid =>
      _session.uid ?? (throw StateError('Sesión no identificada.'));
  @override
  bool get confirmationEnabled => FirebaseEnvironment.emulatorOrdersEnabled;
  @override
  String newOperationId() => _db.collection('pedidos').doc().id;

  Future<dynamic> _call(String name, Map<String, dynamic> data) async {
    if (!confirmationEnabled) {
      throw const RemoteOrderException(
        'Confirmación de producción deshabilitada.',
        definitive: true,
      );
    }
    try {
      return (await _functions.httpsCallable(name).call<dynamic>(data)).data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      final prices = details['prices'] as Map? ?? {};
      throw RemoteOrderException(
        e.message ?? 'No se pudo confirmar la operación.',
        // Un timeout/transport error puede ocurrir DESPUÉS del commit.
        definitive: const [
          'invalid-argument',
          'permission-denied',
          'unauthenticated',
          'failed-precondition',
          'resource-exhausted',
        ].contains(e.code),
        prices: {
          for (final entry in prices.entries)
            entry.key.toString(): (entry.value as num).toInt(),
        },
      );
    }
  }

  @override
  Future<PharmacyOrder> confirm(Map<String, dynamic> request) async {
    final uid = _uid;
    final farm = _farm;
    final response = Map<String, dynamic>.from(
      await _call('confirmOrder', request) as Map,
    );
    if (_uid != uid || _farm != farm) throw StateError('La sesión cambió.');
    return _load(response['orderId'] as String, server: true);
  }

  @override
  Future<PharmacyOrder?> result(String operationId) async {
    final response = await _call('orderOperationResult', {
      'operationId': operationId,
    });
    if (response == null) return null;
    return _load((response as Map)['orderId'] as String, server: true);
  }

  Future<PharmacyOrder> _load(String id, {bool server = false}) async {
    final options = GetOptions(
      source: server ? Source.server : Source.serverAndCache,
    );
    final uid = _uid;
    final farm = _farm;
    final ref = _db.collection('pedidos').doc(id);
    final results = await Future.wait([
      ref.get(options),
      ref.collection('detalle_pedido').get(options),
      ref.collection('historial_estado').get(options),
    ]);
    final doc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    if (!doc.exists || doc.data()!['id_cliente'] != farm || _uid != uid) {
      throw StateError('Pedido no disponible para esta farmacia.');
    }
    final details = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final history = results[2] as QuerySnapshot<Map<String, dynamic>>;
    return FirestoreOrderMapper.fromMaps(
      documentId: id,
      ownerUid: uid,
      data: doc.data()!,
      details: details.docs.map((d) => d.data()).toList(),
      history: {for (final d in history.docs) d.id: d.data()},
      fromCache:
          doc.metadata.isFromCache ||
          details.metadata.isFromCache ||
          history.metadata.isFromCache,
    );
  }

  @override
  Stream<List<PharmacyOrder>> watchOwnOrders() {
    // No se combina con _orders de demostración; el filtro coincide con rules.
    return _db
        .collection('pedidos')
        .where('id_cliente', isEqualTo: _farm)
        .orderBy('fecha_pedido', descending: true)
        .limit(50)
        .snapshots(includeMetadataChanges: true)
        .asyncMap(
          (snapshot) async =>
              Future.wait(snapshot.docs.map((d) => _load(d.id))),
        );
  }

  @override
  Stream<PharmacyOrder> watchOrder(String documentId) {
    final ref = _db.collection('pedidos').doc(documentId);
    late StreamController<PharmacyOrder> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    Future<void> emit() async {
      try {
        final order = await _load(documentId);
        if (!controller.isClosed) controller.add(order);
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      }
    }

    controller = StreamController<PharmacyOrder>(
      onListen: () {
        subscriptions.add(
          ref
              .snapshots(includeMetadataChanges: true)
              .listen((_) => emit(), onError: controller.addError),
        );
        for (final name in ['detalle_pedido', 'historial_estado']) {
          subscriptions.add(
            ref
                .collection(name)
                .snapshots()
                .listen((_) => emit(), onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<DeliveryAddress>> watchAddresses() => _db
      .collection('direcciones')
      .where('id_cliente', isEqualTo: _farm)
      .where('estado', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => DeliveryAddress(
                id: doc.id,
                name: doc.data()['nombre'] as String? ?? doc.id,
                address: doc.data()['direccion'] as String? ?? '',
                reference: doc.data()['referencia'] as String? ?? '',
              ),
            )
            .toList(),
      );

  @override
  Future<void> addAddress(String name, String address, String reference) async {
    if (name.trim().isEmpty || address.trim().isEmpty) {
      throw StateError('Completa la dirección.');
    }
    await _db.collection('direcciones').add({
      'id_cliente': _farm,
      'nombre': name.trim(),
      'direccion': address.trim(),
      'referencia': reference.trim(),
      'latitud': null,
      'longitud': null,
      'estado': true,
    });
  }
}
