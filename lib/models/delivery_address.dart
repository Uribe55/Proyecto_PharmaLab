class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.name,
    required this.address,
    this.reference = '',
    this.commercialNumber = '',
  });
  final String id, name, address, reference;
  final String commercialNumber;
  String get label =>
      commercialNumber.isEmpty ? name : '$commercialNumber · $name';
}
