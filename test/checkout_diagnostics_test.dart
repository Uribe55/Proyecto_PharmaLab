import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/datasources/checkout_diagnostics.dart';

void main() {
  test('diagnóstico desactivado no imprime información', () {
    final messages = <String>[];
    final trace = CheckoutDiagnostics(
      uid: 'uid-prueba',
      farmId: 'FARM004',
      orderId: 'ABCDEFGHIJKLMNOPQRST',
      projectId: 'demo-test',
      enabled: false,
      sink: messages.add,
    );
    trace.beginAttempt();
    trace.failure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'rechazado',
      ),
    );
    expect(messages, isEmpty);
  });

  test('identifica lectura, intento y existencia sin ocultar la excepción original', () {
    final messages = <String>[];
    final trace = CheckoutDiagnostics(
      uid: 'uid-prueba',
      farmId: 'FARM004',
      orderId: 'ABCDEFGHIJKLMNOPQRST',
      projectId: 'demo-test',
      enabled: true,
      sink: messages.add,
    );
    trace.beginAttempt();
    trace.mark(
      'transaccion.leida',
      document: 'pedidos/ABCDEFGHIJKLMNOPQRST',
      exists: false,
    );
    expect(trace.orderExists, isFalse);
    trace.beginAttempt();
    trace.mark('transaccion.lectura', document: 'pedidos/ABCDEFGHIJKLMNOPQRST');
    trace.failure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ),
    );
    final last =
        jsonDecode(messages.last.substring('[SparkCheckout] '.length)) as Map;
    expect(last['stage'], 'transaccion.lectura');
    expect(last['path'], 'pedidos/ABCDEFGHIJKLMNOPQRST');
    expect(last['attempt'], 2);
    expect(
      last['orderExists'],
      isNull,
      reason: 'Un intento nuevo no reutiliza una lectura anterior',
    );
    expect(last['plugin'], 'cloud_firestore');
    expect(last['code'], 'permission-denied');
    expect(last['message'], 'Missing or insufficient permissions.');
  });

  test('no atribuye un rechazo del commit a la última escritura encolada', () {
    final messages = <String>[];
    final trace = CheckoutDiagnostics(
      uid: 'u',
      farmId: 'FARM004',
      orderId: 'o',
      projectId: 'demo-test',
      enabled: true,
      sink: messages.add,
    );
    trace.mark(
      'transaccion.encolar_actualizacion',
      document: 'lotes_productos/LOTE001',
    );
    trace.mark('transaccion.commit');
    trace.failure(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    final last =
        jsonDecode(messages.last.substring('[SparkCheckout] '.length)) as Map;
    expect(last['path'], isNull);
    expect(last['stage'], 'transaccion.commit');
  });

  test('redacta credenciales accidentales del mensaje nativo', () {
    final messages = <String>[];
    final trace = CheckoutDiagnostics(
      uid: 'u',
      farmId: 'FARM004',
      orderId: 'o',
      projectId: 'demo-test',
      enabled: true,
      sink: messages.add,
    );
    trace.failure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Bearer secret.token password=secret-password refresh_token=secret-refresh',
      ),
    );
    expect(messages.last, isNot(contains('secret.')));
    expect(messages.last, isNot(contains('secret-password')));
    expect(messages.last, isNot(contains('secret-refresh')));
  });
}
