import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/staff_order_repository.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/screens/vendedor/remote_seller_orders_screen.dart';

class ApprovalRepositoryFake implements StaffOrderRepository {
  final events = StreamController<PharmacyOrder>.broadcast(sync: true);
  final committed = Completer<void>();
  int requests = 0;
  @override
  bool get approvalEnabled => true;
  @override
  Stream<StaffOrderFeed> watchOrders() => const Stream.empty();
  @override
  Stream<PharmacyOrder> watchOrder(String orderId) => events.stream;
  @override
  Future<void> approve(String orderId) {
    requests++;
    return committed.future;
  }
}

PharmacyOrder order(OrderStatus status) => PharmacyOrder(
  number: 'PED-ABCDEFGHIJKLMNOPQRST',
  documentId: 'ABCDEFGHIJKLMNOPQRST',
  remote: true,
  createdAt: DateTime.utc(2026),
  status: status,
  items: [],
  pharmacyName: 'Farmacia',
  address: 'Av. Principal',
  contactName: 'Cliente',
  contactPhone: '70000000',
);

void main() {
  testWidgets(
    'aprobar bloquea doble pulsación y muestra éxito solo tras commit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ApprovalRepositoryFake();
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSellerOrderDetailScreen(
            order: order(OrderStatus.pendiente),
            repository: repository,
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Aprobar pedido'), 180);
      await tester.tap(find.text('Aprobar pedido'));
      await tester.pump();
      expect(repository.requests, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        find.text('Pedido aprobado y registrado en Firestore.'),
        findsNothing,
      );
      repository.committed.complete();
      repository.events.add(order(OrderStatus.aprobado));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Pedido aprobado y registrado en Firestore.'),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(repository.requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(repository.events.close());
      await tester.pump();
    },
  );
}
