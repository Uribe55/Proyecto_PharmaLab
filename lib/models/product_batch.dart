/// Lote de producto. El stock no se duplica en la colección `productos`.
class ProductBatch {
  const ProductBatch({
    required this.id,
    required this.productId,
    required this.available,
    this.expiresAt,
  });

  final String id;
  final String productId;
  final int available;
  final DateTime? expiresAt;

  bool eligible({required bool requiresExpiry, required DateTime today}) {
    if (available <= 0) return false;
    if (expiresAt == null) return !requiresExpiry;
    final expiryDate = DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day);
    final currentDate = DateTime(today.year, today.month, today.day);
    return !expiryDate.isBefore(currentDate);
  }
}
