import '../data/repositories/remote_order_repository.dart';

/// No convierte strings ni doubles a enteros: un contador inválido se bloquea.
class CommercialNumber {
  static String orderLabel(dynamic value, String documentId) {
    if (value is String && RegExp(r'^PED[0-9]{3,}$').hasMatch(value)) {
      return value;
    }
    if (RegExp(r'^PED[0-9]{3,}$').hasMatch(documentId)) return documentId;
    return 'Pedido sin número comercial';
  }

  static String code(String prefix, int number) =>
      '$prefix${number.toString().padLeft(3, '0')}';

  static int next(Map<String, dynamic>? counter, String prefix) {
    final value = counter?['ultimo_numero'];
    final document = counter?['ultimo_documento_id'];
    if (value is! int ||
        value < 1 ||
        value >= 999999999 ||
        counter?['ultimo_id'] != code(prefix, value) ||
        document is! String ||
        document.isEmpty ||
        document.contains('/')) {
      throw const RemoteOrderException(
        'La numeración comercial requiere revisión. No se guardó ningún cambio.',
        definitive: true,
      );
    }
    return value + 1;
  }

  static Map<String, dynamic> counter(
    String prefix,
    int n,
    String documentId,
  ) => {
    'ultimo_numero': n,
    'ultimo_id': code(prefix, n),
    'ultimo_documento_id': documentId,
  };
}
