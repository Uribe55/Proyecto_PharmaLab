import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Diagnóstico opt-in de desarrollo. Nunca imprime payloads, notas o tokens.
/// Activar: --dart-define=SPARK_CHECKOUT_DIAGNOSTICS=true
class CheckoutDiagnostics {
  CheckoutDiagnostics({
    required this.uid,
    required this.farmId,
    required this.orderId,
    required this.projectId,
    bool? enabled,
    void Function(String)? sink,
  }) : enabled =
           kDebugMode &&
           (enabled ??
               const bool.fromEnvironment('SPARK_CHECKOUT_DIAGNOSTICS')),
       _sink = sink ?? debugPrint;
  final String uid, farmId, orderId, projectId;
  final bool enabled;
  final void Function(String) _sink;
  int attempt = 0;
  String stage = 'inicio';
  String? path;
  bool? orderExists;

  void beginAttempt() {
    attempt++;
    orderExists = null;
    mark('transaccion.inicio');
  }

  void mark(String value, {String? document, bool? exists}) {
    stage = value;
    path = document;
    if (document == 'pedidos/$orderId' && exists != null) orderExists = exists;
    _write({'stage': stage, 'path': document, 'exists': exists});
  }

  void failure(FirebaseException error) {
    _write({
      'stage': stage,
      'path': path,
      'code': error.code,
      'plugin': error.plugin,
      'message': _redact(error.message ?? ''),
    });
  }

  void _write(Map<String, Object?> event) {
    if (!enabled) return;
    _sink(
      '[SparkCheckout] ${jsonEncode({'project': projectId, 'uid': uid, 'farmId': farmId, 'orderId': orderId, 'attempt': attempt, 'orderExists': orderExists, ...event})}',
    );
  }

  static String _redact(String text) => text
      .replaceAll(
        RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
        'Bearer [redacted]',
      )
      .replaceAll(
        RegExp(
          r'(?:access_token|refresh_token|id_token|password|authorization)\s*[:=]\s*[^\s,;]+',
          caseSensitive: false,
        ),
        '[redacted]',
      );
}
