import '../../models/order.dart';

class DeliveryRecord {
  const DeliveryRecord(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class LogisticsDriver {
  const LogisticsDriver(this.id, this.name);
  final String id, name;
}

abstract interface class LogisticsRepository {
  Stream<List<LogisticsDriver>> watchDrivers();
  Stream<List<DeliveryRecord>> watchDeliveries();
  Future<void> assign(PharmacyOrder order, String employeeId);
  Future<void> transition(
    DeliveryRecord delivery,
    String state, {
    String reason = '',
    String note = '',
  });
}
