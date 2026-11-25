import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/spark_approval.dart';
import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../services/firebase_environment.dart';
import '../../services/pharma_service.dart';
import '../repositories/staff_order_repository.dart';
import 'firestore_order_reader.dart';

class FirestoreStaffOrderDataSource implements StaffOrderRepository {
  FirestoreStaffOrderDataSource({FirebaseFirestore? db, PharmaService? session})
    : _db = db ?? FirebaseEnvironment.firestore,
      _session = session ?? PharmaService.instance;
  final FirebaseFirestore _db;
  final PharmaService _session;

  bool _authorized(String uid) =>
      _session.uid == uid &&
      _session.currentUser?.active == true &&
      [UserRole.vendedor, UserRole.administrador].contains(_session.role);

  @override
  Stream<StaffOrderFeed> watchOrders() {
    final uid = _session.uid;
    if (uid == null || !_authorized(uid)) {
      throw StateError('Sesión de personal no válida.');
    }
    // Todos los pendientes: el contador no se recorta a una ventana de 50.
    return _db
        .collection('pedidos')
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snapshot) async {
          if (!_authorized(uid)) throw StateError('La sesión cambió.');
          final reader = FirestoreOrderReader(_db);
          final orders = await Future.wait(
            snapshot.docs.map(
              (doc) => reader.load(
                doc.id,
                ownerUid: uid,
                authorized: (_) => _authorized(uid),
              ),
            ),
          );
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (!_authorized(uid)) throw StateError('La sesión cambió.');
          return StaffOrderFeed(
            orders,
            fromCache:
                snapshot.metadata.isFromCache || orders.any((o) => o.fromCache),
          );
        });
  }

  @override
  Stream<PharmacyOrder> watchOrder(String orderId) {
    final uid = _session.uid;
    if (uid == null || !_authorized(uid)) throw StateError('Sesión no válida.');
    return FirestoreOrderReader(_db)
        .watch(orderId, ownerUid: uid, authorized: (_) => _authorized(uid));
  }

  @override
  bool get approvalEnabled => SparkApproval.enabled;

  @override
  Future<void> approve(String orderId) async {
    if (!approvalEnabled) throw StateError(SparkApproval.blockedReason);
    final uid = _session.uid;
    if (uid == null || !_authorized(uid)) throw StateError('Sesión no válida.');
    await _db.runTransaction((transaction) async {
      if (!_authorized(uid)) throw StateError('La sesión cambió.');
      await SparkApproval.prepare(
        _ApprovalAdapter(_db, transaction),
        uid: uid,
        orderId: orderId,
        serverTimestamp: FieldValue.serverTimestamp(),
      );
    });
  }
}

class _ApprovalAdapter implements ApprovalTransaction {
  _ApprovalAdapter(this.db, this.transaction);
  final FirebaseFirestore db;
  final Transaction transaction;
  @override
  Future<Map<String, dynamic>?> read(String path) async =>
      (await transaction.get(db.doc(path))).data();
  @override
  void update(String path, Map<String, dynamic> values) =>
      transaction.update(db.doc(path), values);
  @override
  void create(String path, Map<String, dynamic> values) =>
      transaction.set(db.doc(path), values);
}
