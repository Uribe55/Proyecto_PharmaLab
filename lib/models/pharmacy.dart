class PharmacyProfile {
  const PharmacyProfile({
    required this.commercialName,
    required this.nit,
    required this.responsible,
    required this.phone,
    required this.address,
    required this.email,
  });

  final String commercialName;
  final String nit;
  final String responsible;
  final String phone;
  final String address;
  final String email;

  String get firstName {
    final parts = responsible.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'cliente';
    return parts.first;
  }

  String get initials {
    final parts = responsible
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PL';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  PharmacyProfile copyWith({
    String? commercialName,
    String? nit,
    String? responsible,
    String? phone,
    String? address,
    String? email,
  }) {
    return PharmacyProfile(
      commercialName: commercialName ?? this.commercialName,
      nit: nit ?? this.nit,
      responsible: responsible ?? this.responsible,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
    );
  }
}
