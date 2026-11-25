import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/spark_checkout.dart';
import '../../models/delivery_address.dart';
import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../services/firebase_environment.dart';
import 'firestore_order_reader.dart';
import 'firestore_spark_checkout.dart';
import '../repositories/remote_order_repository.dart';

class FirestoreOrderDataSource implements RemoteOrderRepository {
  FirestoreOrderDataSource({FirebaseFirestore? db, PharmaService? session})
    : _db = db ?? FirebaseEnvironment.firestore,
      _session = session ?? PharmaService.instance;
  final FirebaseFirestore _db;
  final PharmaService _session;
  String get _farm =>
      _session.pharmacyId ?? (throw StateError('Farmacia no identificada.'));
  String get _uid =>
      _session.uid ?? (throw StateError('Sesión no identificada.'));
  @override
  bool get confirmationEnabled => true;
  @override
  String newOperationId() => _db.collection('pedidos').doc().id;

  @override
  Future<PharmacyOrder> confirm(Map<String, dynamic> request) async {
    SparkCheckout.item(request);
    final uid = _uid, farm = _farm;
    final existing = await result(request['operationId'] as String);
    if (existing != null) {
      // Verificar también el contenido idempotente, sin consultar stock actual.
      await _db.runTransaction((tx) async {
        await SparkCheckout.prepare(
          SparkTransactionAdapter(_db, tx),
          uid: uid,
          farmId: farm,
          lotId: 'unused',
          request: request,
          serverTimestamp: FieldValue.serverTimestamp(),
          now: DateTime.now(),
        );
      });
      return existing;
    }
    await FirestoreSparkCheckout(_db).confirm(
      uid: uid,
      farmId: farm,
      request: request,
      sessionValid: () => _session.uid == uid && _session.pharmacyId == farm,
    );
    if (_session.uid != uid || _session.pharmacyId != farm) {
      throw StateError('La sesión cambió.');
    }
    return _load(request['operationId'] as String, server: true);
  }

  @override
  Future<PharmacyOrder?> result(String operationId) async {
    if (!RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(operationId)) {
      throw const RemoteOrderException(
        'ID de operación incompatible. No se ha creado otro pedido.',
        definitive: true,
      );
    }
    final uid = _uid, farm = _farm;
    try {
      final operation = await _db
          .doc('usuarios/$uid/operaciones_pedido/$operationId')
          .get(const GetOptions(source: Source.server));
      if (_session.uid != uid || _session.pharmacyId != farm) {
        throw StateError('La sesión cambió.');
      }
      if (!operation.exists) return null;
      final data = operation.data()!;
      if (data['pedido_id'] != operationId || data['id_cliente'] != farm) {
        throw const RemoteOrderException(
          'La operación no coincide con esta farmacia.',
          definitive: true,
        );
      }
      return await _load(operationId, server: true);
    } on FirebaseException catch (error) {
      throw RemoteOrderException(
        error.code == 'permission-denied'
            ? 'No tienes permisos para consultar la operación. Revisa la sesión y las reglas publicadas.'
            : 'No se pudo consultar el resultado. Reintenta con el mismo ID.',
        definitive: false,
      );
    }
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
