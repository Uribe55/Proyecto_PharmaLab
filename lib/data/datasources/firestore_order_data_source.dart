import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/delivery_address.dart';
import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../services/firebase_environment.dart';
import 'firestore_order_reader.dart';
import '../repositories/remote_order_repository.dart';

class FirestoreOrderDataSource implements RemoteOrderRepository {
  FirestoreOrderDataSource({
    FirebaseFirestore? db,
    this.functions,
    PharmaService? session,
  }) : _db = db ?? FirebaseEnvironment.firestore,
       _session = session ?? PharmaService.instance;
  final FirebaseFirestore _db;
  final FirebaseFunctions? functions;
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
      return (await (functions ?? FirebaseEnvironment.functions)
              .httpsCallable(name)
              .call<dynamic>(data))
          .data;
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
    final uid = _uid;
    final farm = _farm;
    return FirestoreOrderReader(_db).load(
      id,
      ownerUid: uid,
      server: server,
      authorized: (data) =>
          _session.uid == uid &&
          _session.pharmacyId == farm &&
          data['id_cliente'] == farm,
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
    final uid = _uid;
    final farm = _farm;
    return FirestoreOrderReader(_db).watch(
      documentId,
      ownerUid: uid,
      authorized: (data) =>
          _session.uid == uid &&
          _session.pharmacyId == farm &&
          data['id_cliente'] == farm,
    );
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
