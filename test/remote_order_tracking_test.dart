import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/remote_order_repository.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/order_tracking_screen.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';

class TrackingFake implements RemoteOrderRepository {
  int cancellations = 0;
  late final events = StreamController<PharmacyOrder>(
    onCancel: () {
      cancellations++;
    },
  );
  @override
  Stream<PharmacyOrder> watchOrder(String documentId) => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PharmacyOrder tracked(OrderStatus status, String uid) => PharmacyOrder(
  number: 'pedido-remoto',
  documentId: 'pedido-remoto',
  customerId: uid,
  remote: true,
  createdAt: DateTime.utc(2026),
  status: status,
  items: [],
  pharmacyName: 'Farmacia de prueba',
  address: '',
  contactName: '',
  contactPhone: '',
);

void main() {
  testWidgets(
    'el seguimiento muestra la aprobación emitida por el repositorio',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = PharmaService.instance;
      await service.login(
        email: PharmaService.demoEmail,
        password: PharmaService.demoPassword,
      );
      final uid = service.currentUser!.id;
      final repository = TrackingFake();
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            order: tracked(OrderStatus.pendiente, uid),
            repository: repository,
          ),
        ),
      );
      await tester.pump();
      final initialApproved = find.text('Aprobado').evaluate().length;
      repository.events.add(tracked(OrderStatus.aprobado, uid));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Aprobado').evaluate().length,
        greaterThan(initialApproved),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(repository.cancellations, 1);
      unawaited(repository.events.close());
      await tester.pump();
    },
  );
}
