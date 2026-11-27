import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/spark_checkout.dart';
import '../../domain/spark_address.dart';
import '../../models/delivery_address.dart';
import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../services/firebase_environment.dart';
import 'firestore_order_reader.dart';
import 'firestore_spark_checkout.dart';
import 'checkout_diagnostics.dart';
import 'numbered_transaction.dart';
import 'order_gateway.dart';
import '../mappers/firestore_order_mapper.dart';
import '../repositories/remote_order_repository.dart';

class FirestoreOrderDataSource
    implements RemoteOrderRepository, MultiOrderCapability {
  FirestoreOrderDataSource({FirebaseFirestore? db, PharmaService? session})
    : _db = db ?? FirebaseEnvironment.firestore,
      _session = session ?? PharmaService.instance;
  final FirebaseFirestore _db;
  final PharmaService _session;
  // Conserva el ID ante un error de red/resultado incierto durante esta sesión.
  final Map<String, String> _addressAttempts = {};
  String get _farm =>
      _session.pharmacyId ?? (throw StateError('Farmacia no identificada.'));
  String get _uid =>
      _session.uid ?? (throw StateError('Sesión no identificada.'));
  @override
  bool get confirmationEnabled => true;
  @override
  bool get supportsMultipleProducts => FirebaseEnvironment.multiOrdersEnabled;
  @override
  String newOperationId() => _db.collection('pedidos').doc().id;

  @override
  Future<PharmacyOrder> confirm(Map<String, dynamic> request) async {
    if (supportsMultipleProducts) {
      final uid = _uid, farm = _farm;
      final response = await OrderGateway().call('confirmOrder', request);
      if (_session.uid != uid || _session.pharmacyId != farm) {
        throw StateError('La sesión cambió.');
      }
      final snapshot = response?['_confirmedOrder'];
      if (snapshot is Map &&
          snapshot['usuario_id'] == uid &&
          snapshot['id_cliente'] == farm &&
          snapshot['id_operacion'] == request['operationId']) {
        return FirestoreOrderMapper.fromMaps(
          documentId: response!['orderId'] as String,
          ownerUid: uid,
          data: Map<String, dynamic>.from(snapshot),
          details: (snapshot['lineas'] as List)
              .map((line) => Map<String, dynamic>.from(line as Map))
              .toList(),
          history: const {},
          fromCache: false,
        );
      }
      return _load(response!['orderId'] as String, server: true);
    }
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
    if (supportsMultipleProducts) {
      if (FirebaseEnvironment.externalOrdersEnabled) {
        final response = await OrderGateway().call('orderOperationResult', {
          'operationId': operationId,
        });
        if (_session.uid != uid || _session.pharmacyId != farm) {
          throw StateError('La sesión cambió.');
        }
        if (response != null) {
          return _load(response['orderId'] as String, server: true);
        }
      }
      // Conserva también la recuperación de operaciones Spark anteriores.
      final operation = await _db
          .doc('usuarios/$uid/operaciones_pedido/$operationId')
          .get(const GetOptions(source: Source.server));
      if (_session.uid != uid || _session.pharmacyId != farm) {
        throw StateError('La sesión cambió.');
      }
      if (!operation.exists) return null;
      final data = operation.data()!;
      if (data['id_cliente'] != farm) {
        throw StateError('La operación pertenece a otra farmacia.');
      }
      final result = data['resultado'];
      final id = result is Map ? result['orderId'] : data['pedido_id'];
      if (id is! String) {
        throw StateError('La operación no contiene un resultado verificable.');
      }
      return _load(id, server: true);
    }
    final diagnostics = CheckoutDiagnostics(
      uid: uid,
      farmId: farm,
      orderId: operationId,
      projectId: _db.app.options.projectId,
    );
    try {
      diagnostics.mark(
        'idempotencia.lectura',
        document: 'usuarios/$uid/operaciones_pedido/$operationId',
      );
      final operation = await _db
          .doc('usuarios/$uid/operaciones_pedido/$operationId')
          .get(const GetOptions(source: Source.server));
      diagnostics.mark(
        'idempotencia.leida',
        document: operation.reference.path,
        exists: operation.exists,
      );
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
      diagnostics.mark('pedido.carga_relacionados');
      return await _load(operationId, server: true);
    } on FirebaseException catch (error) {
      diagnostics.failure(error);
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
  Stream<List<PharmacyOrder>> watchOwnOrders({int limit = 50}) {
    final uid = _uid, farm = _farm;
    return _db
        .collection('pedidos')
        .where('id_cliente', isEqualTo: farm)
        .orderBy('fecha_pedido', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          if (_session.uid != uid || _session.pharmacyId != farm) {
            throw StateError('La sesión cambió.');
          }
          return snapshot.docs.map((doc) {
            final data = doc.data();
            if (data['id_cliente'] != farm) throw StateError('Pedido ajeno.');
            final lines = data['lineas'] is List
                ? data['lineas'] as List
                : data['linea'] is Map
                ? [data['linea']]
                : const [];
            return FirestoreOrderMapper.fromMaps(
              documentId: doc.id,
              ownerUid: uid,
              data: data,
              details: lines
                  .map((line) => Map<String, dynamic>.from(line as Map))
                  .toList(),
              history: const {},
              fromCache:
                  snapshot.metadata.isFromCache ||
                  snapshot.metadata.hasPendingWrites,
            );
          }).toList();
        });
  }

  @override
  Stream<PharmacyOrder> watchOrder(String documentId) {
    final uid = _uid;
    final farm = _farm;
    return FirestoreOrderReader(_db).watchClient(
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
                name: doc.data()['nombre'] as String? ?? 'Dirección',
                commercialNumber:
                    doc.data()['numero_comercial'] as String? ??
                    (RegExp(r'^DIR[0-9]{3,}$').hasMatch(doc.id) ? doc.id : ''),
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
    final uid = _uid, farm = _farm;
    final attemptKey = [
      uid,
      farm,
      name.trim(),
      address.trim(),
      reference.trim(),
    ].map((part) => '${part.length}:$part').join();
    final id = _addressAttempts.putIfAbsent(
      attemptKey,
      () => _db.collection('direcciones').doc().id,
    );
    await numberedTransaction(_db, 'configuracion/contadores_direcciones', (
      tx,
    ) async {
      if (_session.uid != uid || _session.pharmacyId != farm) {
        throw StateError('La sesión cambió.');
      }
      await SparkAddress.prepare(
        SparkTransactionAdapter(_db, tx),
        uid: uid,
        farmId: farm,
        documentId: id,
        name: name,
        address: address,
        reference: reference,
      );
      if (_session.uid != uid || _session.pharmacyId != farm) {
        throw StateError('La sesión cambió.');
      }
    });
    _addressAttempts.remove(attemptKey);
  }
}
