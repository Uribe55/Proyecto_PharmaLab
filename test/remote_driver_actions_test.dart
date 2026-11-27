import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/logistics_repository.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/screens/shared/remote_logistics_screen.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';

class Repository implements LogisticsRepository {
  final stream = StreamController<List<DeliveryRecord>>.broadcast();
  Completer<void>? pending;
  int calls = 0;
  String? state;
  void emit(
    String state, {
    bool cached = false,
    String schema = 'transactional_logistics_v1',
  }) => stream.add([
    DeliveryRecord('delivery', {
      'schema_version': schema,
      'estado': state,
      'from_cache': cached,
      'farmacia': 'Farmacia',
      'pedido_numero': 'PED002',
    }),
  ]);
  @override
  Stream<List<DeliveryRecord>> watchDeliveries() => stream.stream;
  @override
  Stream<List<LogisticsDriver>> watchDrivers() => const Stream.empty();
  @override
  Future<void> assign(PharmacyOrder order, String employeeId) async {}
  @override
  Future<void> transition(
    DeliveryRecord delivery,
    String state, {
    String reason = '',
    String note = '',
  }) async {
    calls++;
    this.state = state;
    if (pending != null) await pending!.future;
    emit(state);
  }
}

void main() {
  Future<Repository> open(WidgetTester tester, {bool history = false}) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final driver = PharmaService.demoUsers.firstWhere(
      (user) => user.role.name == 'repartidor',
    );
    await PharmaService.instance.login(
      email: driver.email,
      password: PharmaService.demoPassword,
    );
    final repository = Repository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RemoteLogisticsScreen(repository: repository, history: history),
      ),
    );
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await repository.stream.close();
      await PharmaService.instance.logout();
    });
    return repository;
  }

  testWidgets(
    'caché a servidor habilita Iniciar reparto aunque el documento no cambie',
    (tester) async {
      final repository = await open(tester);
      repository.emit('asignada', cached: true);
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Iniciar reparto');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.textContaining('Esperando sincronización'), findsOneWidget);
      repository.emit('asignada');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      repository.pending = Completer<void>();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      expect(repository.calls, 1);
      expect(repository.state, 'en_ruta');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('En ruta'), findsWidgets);
      expect(find.text('Confirmar entrega'), findsOneWidget);
      expect(find.text('Iniciar reparto'), findsNothing);
    },
  );
  testWidgets('Spark conserva acciones; entregada y fallida no se reinician', (
    tester,
  ) async {
    final repository = await open(tester);
    repository.emit('asignada', schema: 'spark_logistics_v1');
    await tester.pumpAndSettle();
    expect(find.text('Iniciar reparto'), findsOneWidget);
    repository.emit('en_ruta');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();
    expect(repository.state, 'entregado');
    expect(find.text('Entregada'), findsWidgets);
    expect(find.text('Confirmar entrega'), findsNothing);
    expect(find.text('Ver detalle'), findsOneWidget);
    repository.emit('fallida');
    await tester.pumpAndSettle();
    expect(find.text('Iniciar reparto'), findsNothing);
  });
  testWidgets('historial muestra entregada sin acciones de modificación', (
    tester,
  ) async {
    final repository = await open(tester, history: true);
    repository.emit('entregado');
    await tester.pumpAndSettle();
    expect(find.text('Entregada'), findsWidgets);
    expect(find.text('Iniciar reparto'), findsNothing);
    expect(find.text('Confirmar entrega'), findsNothing);
  });

  testWidgets(
    'entrega fallida usa la transición existente y queda sin acciones',
    (tester) async {
      final repository = await open(tester);
      repository.emit('en_ruta');
      await tester.pumpAndSettle();
      await tester.tap(find.text('REGISTRAR ENTREGA FALLIDA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(repository.state, 'fallida');
      expect(repository.calls, 1);
      expect(find.text('Confirmar entrega'), findsNothing);
      expect(find.text('Iniciar reparto'), findsNothing);
    },
  );
}
