class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.name,
    required this.address,
    this.reference = '',
  });
  final String id, name, address, reference;
}
