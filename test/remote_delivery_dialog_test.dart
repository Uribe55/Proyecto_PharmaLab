import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/logistics_repository.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/screens/shared/remote_logistics_screen.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';

class FakeLogistics implements LogisticsRepository {
  int transitions = 0;
  final record = DeliveryRecord('delivery-internal', {
    'schema_version': 'spark_logistics_v1',
    'estado': 'en_ruta',
    'pedido_numero': 'PED004',
    'farmacia': 'Farmacia real de prueba',
    'direccion': 'Calle 1',
  });
  @override
  Stream<List<DeliveryRecord>> watchDeliveries() => Stream.value([record]);
  @override
  Stream<List<LogisticsDriver>> watchDrivers() => Stream.value([]);
  @override
  Future<void> assign(PharmacyOrder order, String employeeId) async {}
  @override
  Future<void> transition(
    DeliveryRecord delivery,
    String state, {
    String reason = '',
    String note = '',
  }) async {
    transitions++;
  }
}

void main() {
  testWidgets(
    'cancelar incidencia remota no escribe y respeta cierre del diálogo',
    (tester) async {
      final session = PharmaService.instance;
      final driver = PharmaService.demoUsers.firstWhere(
        (u) => u.role.name == 'repartidor',
      );
      await session.login(
        email: driver.email,
        password: PharmaService.demoPassword,
      );
      final repository = FakeLogistics();
      await tester.pumpWidget(
        MaterialApp(home: RemoteLogisticsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('REGISTRAR ENTREGA FALLIDA'));
      await tester.tap(find.text('REGISTRAR ENTREGA FALLIDA'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Borrador');
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repository.transitions, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await session.logout();
    },
  );
}
