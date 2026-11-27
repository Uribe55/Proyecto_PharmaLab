import '../../models/delivery_address.dart';
import '../../models/order.dart';

/// Contrato remoto: no expone transiciones que todavía no son seguras.
abstract interface class RemoteOrderRepository {
  bool get confirmationEnabled;
  String newOperationId();
  Future<PharmacyOrder> confirm(Map<String, dynamic> request);
  Future<PharmacyOrder?> result(String operationId);
  Stream<List<PharmacyOrder>> watchOwnOrders();
  Stream<PharmacyOrder> watchOrder(String documentId);
  Stream<List<DeliveryAddress>> watchAddresses();
  Future<void> addAddress(String name, String address, String reference);
}

abstract interface class MultiOrderCapability {
  bool get supportsMultipleProducts;
}

class RemoteOrderException implements Exception {
  const RemoteOrderException(
    this.message, {
    this.definitive = false,
    this.prices = const {},
  });
  final String message;
  final bool definitive;
  final Map<String, int> prices;
  @override
  String toString() => message;
}
