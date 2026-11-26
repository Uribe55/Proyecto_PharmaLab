import '../../models/order.dart';

class StaffOrderFeed {
  const StaffOrderFeed(this.orders, {this.fromCache = false});
  final List<PharmacyOrder> orders;
  final bool fromCache;
}

abstract interface class StaffOrderRepository {
  Stream<StaffOrderFeed> watchOrders();
  Stream<PharmacyOrder> watchOrder(String orderId);
  bool get approvalEnabled;
  Future<void> approve(String orderId);
}
