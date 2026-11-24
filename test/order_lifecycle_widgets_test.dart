import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/models/app_user.dart';
import 'package:proyecto_final_movil/models/cart_item.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/models/order_lifecycle.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';
import 'package:proyecto_final_movil/widgets/order_lifecycle_panel.dart';
import 'package:proyecto_final_movil/screens/repartidor/driver_delivery_detail_screen.dart';
import 'package:proyecto_final_movil/screens/register_screen.dart';

void main() {
  final service = PharmaService.instance;
  Future<void> login(UserRole role) async {
    final user = service.users.firstWhere((u) => u.role == role);
    expect(
      await service.login(
        email: user.email,
        password: PharmaService.demoPassword,
      ),
      isNull,
    );
  }

  Future<PharmacyOrder> create() async {
    await login(UserRole.cliente);
    return service.createOrder(
      items: [CartItem(product: service.products.first)],
    );
  }

  Future<void> showPanel(WidgetTester tester, PharmacyOrder order) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: OrderLifecyclePanel(order: order)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> action(WidgetTester tester, String label, String reason) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, reason);
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cliente cancela pendiente con motivo y ve estado final', (
    tester,
  ) async {
    final order = await create();
    final stock = service.products.first.stock;
    await showPanel(tester, order);
    expect(find.text('Cancelar pedido'), findsOneWidget);
    expect(find.text('Aprobar pedido'), findsNothing);
    await action(tester, 'Cancelar pedido', 'Compra duplicada');
    expect(order.status, OrderStatus.cancelado);
    expect(service.products.first.stock, stock + 1);
    expect(find.text('Estado: Cancelado'), findsOneWidget);
    expect(find.text('Cancelar pedido'), findsNothing);
  });
  testWidgets('Cliente solicita y vendedor resuelve sin cancelación directa', (
    tester,
  ) async {
    final order = await create();
    await login(UserRole.vendedor);
    expect(service.approveOrder(order), isTrue);
    await login(UserRole.cliente);
    await showPanel(tester, order);
    expect(find.text('Cancelar pedido'), findsNothing);
    await action(tester, 'Solicitar cancelación', 'Cambiar compra');
    expect(order.pendingCancellation, isNotNull);
    expect(order.isApproved, isTrue);
    await login(UserRole.vendedor);
    await tester.pumpAndSettle();
    expect(find.text('Aprobar cancelación'), findsOneWidget);
    await action(tester, 'Aprobar cancelación', 'Aceptada antes de despacho');
    expect(order.status, OrderStatus.cancelado);
    expect(
      order.cancellationRequests.single.status,
      CancellationStatus.accepted,
    );
  });
  testWidgets(
    'Repartidor distingue iniciar ruta de confirmar entrega y no cancela',
    (tester) async {
      final order = await create();
      await login(UserRole.vendedor);
      service.approveOrder(order);
      final driver = service.users.firstWhere(
        (u) => u.role == UserRole.repartidor,
      );
      service.assignDelivery(order, driver);
      await login(UserRole.repartidor);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DriverDeliveryDetailScreen(order: order),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Iniciar ruta'), findsOneWidget);
      expect(find.text('Confirmar entrega'), findsNothing);
      expect(find.text('Cancelar pedido'), findsNothing);
      await tester.tap(find.text('Iniciar ruta'));
      await tester.pumpAndSettle();
      expect(order.isInTransit, isTrue);
      expect(find.text('Confirmar entrega'), findsOneWidget);
      expect(find.text('Reportar incidencia temporal'), findsOneWidget);
    },
  );
  testWidgets('Registro conserva la validación de NIT sin llamar a Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const RegisterScreen()),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'NIT'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'NIT'), '12-34');
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('El NIT debe contener entre 7 y 15 dígitos'),
      findsOneWidget,
    );
  });
}
