import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/mappers/firestore_order_mapper.dart';
import 'package:proyecto_final_movil/data/repositories/remote_order_repository.dart';
import 'package:proyecto_final_movil/models/delivery_address.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/order_history_screen.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/order_tracking_screen.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';
import 'package:proyecto_final_movil/viewmodels/order_history_view_model.dart';

class Feed implements RemoteOrderRepository {
  final stream = StreamController<PharmacyOrder>.broadcast();
  int subscriptions = 0;
  @override
  Stream<PharmacyOrder> watchOrder(String documentId) {
    subscriptions++;
    return stream.stream;
  }

  @override
  bool get confirmationEnabled => false;
  @override
  Future<void> addAddress(
    String name,
    String address,
    String reference,
  ) async {}
  @override
  Future<PharmacyOrder> confirm(Map<String, dynamic> request) =>
      throw UnimplementedError();
  @override
  String newOperationId() => 'unused';
  @override
  Future<PharmacyOrder?> result(String operationId) async => null;
  @override
  Stream<List<DeliveryAddress>> watchAddresses() => const Stream.empty();
  @override
  Stream<List<PharmacyOrder>> watchOwnOrders() => const Stream.empty();
}

class History extends OrderHistoryViewModel {
  void emit(List<PharmacyOrder> value) {
    orders = value;
    loading = false;
    notifyListeners();
  }
}

PharmacyOrder fixture({
  String status = 'pendiente',
  bool cached = false,
  bool legacy = false,
  bool assigned = false,
  bool dated = true,
  Map<String, Map<String, dynamic>> history = const {},
}) {
  final user = PharmaService.demoUsers.firstWhere(
    (user) => user.role.name == 'cliente',
  );
  return FirestoreOrderMapper.fromMaps(
    documentId: 'ORD_hidden',
    ownerUid: user.id,
    data: {
      'schema_version': legacy ? 'spark_single_v2' : 'transactional_multi_v1',
      'numero_comercial': 'PED005',
      'id_cliente': 'FARM001',
      'usuario_id': user.id,
      if (dated)
        'fecha_pedido': Timestamp.fromDate(DateTime.utc(2026, 3, 1, 10)),
      'estado': status,
      'total': 99,
      'nombre_farmacia': 'Farmacia propia',
      'entrega': {
        'direccion': 'Dirección histórica',
        'referencia': 'Puerta azul',
      },
      if (assigned) 'id_entrega': 'ENT001',
      if (status != 'pendiente')
        'fecha_aprobacion': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
      if (status == 'en_ruta' || status == 'entregado')
        'fecha_despacho': Timestamp.fromDate(DateTime.utc(2026, 3, 3)),
      if (status == 'entregado')
        'fecha_logistica': Timestamp.fromDate(DateTime.utc(2026, 3, 4)),
    },
    details: [
      {
        'id_producto': 'P1',
        'nombre': 'Nombre histórico A',
        'presentacion': 'Caja',
        'cantidad': 2,
        'precio_unitario': 10,
        'subtotal': 20,
        'factor_inventario': 10,
        'cantidad_inventario': 20,
        'asignaciones_lotes': [
          {'id_lote': 'L1', 'cantidad': 5},
          {'id_lote': 'L2', 'cantidad': 15},
        ],
      },
      if (!legacy)
        {
          'id_producto': 'P2',
          'nombre': 'Nombre histórico B',
          'presentacion': 'Frasco',
          'cantidad': 1,
          'precio_unitario': 79,
          'subtotal': 79,
        },
    ],
    history: history,
    fromCache: cached,
    deliveryData: assigned
        ? {
            'id_repartidor': 'EMP001',
            'estado': status == 'aprobado' ? 'asignada' : status,
            'fecha_creacion': Timestamp.fromDate(DateTime.utc(2026, 3, 2, 12)),
            'motivo': status == 'fallida' ? 'Farmacia cerrada' : '',
          }
        : null,
  );
}

void main() {
  Future<void> login() async {
    final user = PharmaService.demoUsers.firstWhere(
      (user) => user.role.name == 'cliente',
    );
    await PharmaService.instance.login(
      email: user.email,
      password: PharmaService.demoPassword,
    );
  }

  Widget app(Widget child) =>
      MaterialApp(theme: AppTheme.lightTheme, home: child);
  test('filtros conservan fallidos activos y ordenan por fecha', () {
    final pending = fixture(),
        delivered = fixture(status: 'entregado'),
        failed = fixture(status: 'fallida'),
        cancelled = fixture(status: 'cancelado');
    expect(
      OrderHistoryViewModel.selectOrders([
        pending,
        delivered,
        failed,
        cancelled,
      ], 'active'),
      [pending, failed],
    );
    expect(
      OrderHistoryViewModel.selectOrders([
        pending,
        delivered,
        failed,
        cancelled,
      ], 'history'),
      [delivered, cancelled],
    );
    expect(
      OrderHistoryViewModel.selectOrders([pending, delivered], 'entregado'),
      [delivered],
    );
    final old = fixture(dated: false);
    expect(
      OrderHistoryViewModel.selectOrders([old, pending], 'all').first,
      pending,
    );
  });
  test('múltiples lotes no duplican líneas; precios y fechas permanecen históricos', () {
    final order = fixture();
    expect(order.items.length, 2);
    expect(order.items.first.quantity, 2);
    expect(order.items.first.inventoryQuantity, 20);
    expect(order.items.first.unitPrice, 10);
    expect(order.total, 99);
    expect(order.lotAllocations.length, 2);
    expect(order.createdAt.toUtc(), DateTime.utc(2026, 3, 1, 10));
    expect(fixture(legacy: true).items.length, 1);
  });
  test(
    'eventos se ordenan y las fechas ausentes no se presentan como reales',
    () {
      final order = fixture(
        history: {
          'later': {
            'estado_nuevo': 'aprobado',
            'estado_anterior': 'pendiente',
            'fecha_cambio': '2026-03-02T00:00:00Z',
          },
          'earlier': {'estado': 'pendiente', 'fecha': '2026-03-01T00:00:00Z'},
          'undated': {'estado_nuevo': 'en_ruta'},
        },
      );
      expect(
        order.history.where((event) => event.atKnown).map((event) => event.id),
        ['earlier', 'later'],
      );
      expect(
        order.history.singleWhere((event) => event.id == 'undated').atKnown,
        false,
      );
    },
  );
  testWidgets(
    'Mis pedidos: lista vacía, activos e historial sin otra pantalla',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await login();
      final vm = History();
      vm.emit([]);
      await tester.pumpWidget(
        app(OrderHistoryScreen(onBrowse: () {}, viewModel: vm)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin pedidos por aquí'), findsOneWidget);
      vm.emit([fixture(), fixture(status: 'entregado')]);
      await tester.pumpAndSettle();
      expect(find.text('PED005'), findsNWidgets(2));
      expect(find.text('ORD_hidden'), findsNothing);
      await tester.tap(find.text('Activos'));
      await tester.pumpAndSettle();
      expect(find.text('Seguir pedido'), findsOneWidget);
      expect(find.text('Ver detalle'), findsNothing);
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('Ver detalle'), findsOneWidget);
      expect(find.text('Seguir pedido'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      await PharmaService.instance.logout();
    },
  );
  testWidgets(
    'seguimiento remoto se actualiza sin duplicar listeners ni consultar Render',
    (tester) async {
      await login();
      final feed = Feed();
      await tester.pumpWidget(
        app(OrderTrackingScreen(order: fixture(), repository: feed)),
      );
      await tester.pumpAndSettle();
      feed.stream.add(fixture(cached: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Información guardada'), findsOneWidget);
      feed.stream.add(fixture());
      await tester.pumpAndSettle();
      expect(find.textContaining('Información guardada'), findsNothing);
      feed.stream.add(fixture(status: 'aprobado', assigned: true));
      await tester.pumpAndSettle();
      expect(find.text('Aprobado'), findsOneWidget);
      expect(find.textContaining('Información guardada'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Repartidor asignado').first,
        250,
      );
      await tester.pumpAndSettle();
      expect(find.text('Repartidor asignado'), findsWidgets);
      feed.stream.add(fixture(status: 'en_ruta', assigned: true));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.text('En ruta'), findsOneWidget);
      feed.stream.add(fixture(status: 'entregado', assigned: true));
      await tester.pumpAndSettle();
      expect(find.text('Entregado'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Nombre histórico B'), 250);
      await tester.pumpAndSettle();
      expect(find.text('Nombre histórico A'), findsOneWidget);
      expect(find.text('Nombre histórico B'), findsOneWidget);
      expect(feed.subscriptions, 1);
      await tester.pumpWidget(const SizedBox());
      expect(feed.stream.hasListener, false);
      await feed.stream.close();
      await PharmaService.instance.logout();
    },
  );
  testWidgets('cancelación y fechas incompletas no inventan etapas ni fechas', (
    tester,
  ) async {
    await login();
    final feed = Feed();
    await tester.pumpWidget(
      app(
        OrderTrackingScreen(
          order: fixture(status: 'cancelado', dated: false),
          repository: feed,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pedido entregado'), 250);
    await tester.pumpAndSettle();
    expect(find.text('Sin evidencia registrada'), findsWidgets);
    expect(find.textContaining('1970'), findsNothing);
    feed.stream.add(fixture(status: 'fallida', assigned: true));
    await tester.pumpAndSettle();
    expect(feed.subscriptions, 1);
    await tester.pumpWidget(const SizedBox());
    await feed.stream.close();
    await PharmaService.instance.logout();
  });
}
