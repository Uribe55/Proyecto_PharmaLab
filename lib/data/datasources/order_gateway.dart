import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../../services/firebase_environment.dart';
import '../repositories/remote_order_repository.dart';
import 'emulator_order_gateway.dart';

/// Selección explícita de transporte. Un error HTTP nunca activa Spark/callables.
class OrderGateway {
  Future<Map<String, dynamic>?> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (!FirebaseEnvironment.externalOrdersEnabled) {
      return EmulatorOrderGateway().call(name, data);
    }
    if (FirebaseEnvironment.emulatorOrdersEnabled) {
      throw StateError('No combines Render con Firebase Emulator Suite.');
    }
    final base = Uri.tryParse(FirebaseEnvironment.apiUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('PHARMALAB_API_URL debe ser un origen HTTPS válido.');
    }
    if (FirebaseEnvironment.firestore.app.options.projectId !=
        'proyecto-pharmalab') {
      throw StateError('El backend requiere el proyecto Firebase operacional.');
    }
    final user = FirebaseEnvironment.auth.currentUser;
    if (user == null) {
      throw const RemoteOrderException('Inicia sesión.', definitive: true);
    }
    String segment(Object? value) => Uri.encodeComponent(value.toString());
    final path = switch (name) {
      'confirmOrder' => '/api/orders',
      'orderOperationResult' =>
        '/api/operations/${segment(data['operationId'])}',
      'cancelOrder' => '/api/orders/${segment(data['orderId'])}/cancel',
      'assignMultiOrder' => '/api/orders/${segment(data['orderId'])}/assign',
      'approveMultiOrder' => '/api/orders/${segment(data['orderId'])}/approve',
      'transitionMultiDelivery' =>
        '/api/deliveries/${segment(data['deliveryId'])}/transition',
      _ => throw StateError('Operación HTTP no soportada.'),
    };
    final client = http.Client();
    try {
      final tokenClock = Stopwatch()..start();
      final token = await user.getIdToken();
      tokenClock.stop();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final uri = base.replace(path: path);
      final httpClock = Stopwatch()..start();
      final response =
          await (name == 'orderOperationResult'
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(data)))
              .timeout(const Duration(seconds: 120));
      httpClock.stop();
      final serverTiming = response.headers['server-timing'];
      final processing = double.tryParse(
        RegExp(r'processing;dur=([0-9.]+)')
                .firstMatch(serverTiming ?? '')
                ?.group(1) ??
            '',
      );
      debugPrint(
        jsonEncode({
          'event': 'order_http_metrics',
          'operation': name,
          'tokenMs': tokenClock.elapsedMilliseconds,
          'httpMs': httpClock.elapsedMilliseconds,
          'serverProcessingMs': ?processing,
          if (processing != null)
            'networkQueueAndWakeEstimateMs':
                (httpClock.elapsedMilliseconds - processing).clamp(
                  0,
                  double.infinity,
                ),
        }),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final error = payload['error'] as Map?;
        final details = error?['details'] as Map?;
        final prices = details?['prices'] as Map?;
        throw RemoteOrderException(
          error?['message'] as String? ?? 'No se pudo verificar la operación.',
          definitive: [400, 401, 403, 409, 412].contains(response.statusCode),
          prices:
              prices?.map(
                (k, v) => MapEntry(k.toString(), (v as num).toInt()),
              ) ??
              const {},
        );
      }
      if (FirebaseEnvironment.auth.currentUser?.uid != user.uid) {
        throw StateError('La sesión cambió.');
      }
      return payload['data'] == null
          ? null
          : {
              ...Map<String, dynamic>.from(payload['data'] as Map),
              if (payload['order'] is Map) '_confirmedOrder': payload['order'],
            };
    } on RemoteOrderException {
      rethrow;
    } catch (_) {
      throw const RemoteOrderException(
        'No se pudo verificar el resultado. El servidor puede estar reactivándose. Consulta o reintenta la misma operación.',
        definitive: false,
      );
    } finally {
      client.close();
    }
  }
}
