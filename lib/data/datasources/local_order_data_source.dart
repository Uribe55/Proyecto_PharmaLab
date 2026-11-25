import '../../models/order.dart';
import '../../models/product.dart';

/// Fuente local en memoria. No simula persistencia ni conexiones remotas.
class LocalOrderDataSource {
  LocalOrderDataSource({
    required this.orders,
    required this.products,
    required this.isRemote,
    required this.onChanged,
  });
  final List<PharmacyOrder> orders;
  final List<Product> products;
  final bool Function() isRemote;
  final void Function() onChanged;
}
