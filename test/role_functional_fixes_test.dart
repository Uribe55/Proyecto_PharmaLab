import 'package:flutter/material.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/client_shell.dart';
import 'package:proyecto_final_movil/viewmodels/cart_view_model.dart';
import 'package:proyecto_final_movil/widgets/product_card.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/domain/seller_order_list.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/widgets/quantity_stepper.dart';
import 'package:proyecto_final_movil/widgets/contact_edit_dialog.dart';
import 'package:proyecto_final_movil/screens/shared/employee_account_screen.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/widgets/delivery_card.dart';
import 'package:proyecto_final_movil/data/repositories/logistics_repository.dart';

PharmacyOrder order(
  String id,
  OrderStatus status,
  int day, {
  bool known = true,
}) => PharmacyOrder(
  number: id,
  createdAt: DateTime(2026, 1, day),
  createdAtKnown: known,
  status: status,
  items: [],
  pharmacyName: 'Farmacia',
  address: 'Calle',
  contactName: '',
  contactPhone: '',
);
void main() {
  test('historial solo entregadas, sin duplicados y por fecha efectiva', () {
    final old = DeliveryRecord('old', {
      'estado': 'Entregado',
      'fecha_estado': DateTime(2026, 1, 1),
    });
    final fresh = DeliveryRecord('new', {
      'estado': 'entregado',
      'fecha_estado': DateTime(2026, 2, 1),
    });
    final failed = DeliveryRecord('fail', {'estado': 'Entrega fallida'});
    expect(
      deliveryList([old, fresh, failed, fresh], history: true).map((d) => d.id),
      ['new', 'old'],
    );
    expect(
      deliveryList([old, fresh, failed], filter: 'fallida').single.id,
      'fail',
    );
  });
  testWidgets(
    'catálogo cambia a Ver carrito, navega sin duplicar y restaura + al eliminar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = PharmaService.instance;
      final client = PharmaService.demoUsers.firstWhere(
        (u) => u.role.name == 'cliente',
      );
      await session.login(
        email: client.email,
        password: PharmaService.demoPassword,
      );
      final cart = CartViewModel.instance;
      cart.clear();
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const ClientShell()),
      );
      await tester.pumpAndSettle();
      final card = find.byType(ProductCard).first;
      await tester.scrollUntilVisible(
        card,
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      final add = find.descendant(
        of: card,
        matching: find.byIcon(Icons.add_rounded),
      );
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(cart.totalUnits, 1);
      await tester.tap(find.text('Ver carrito'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(cart.totalUnits, 1);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(cart.isEmpty, isTrue);
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Ver carrito'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await session.logout();
    },
  );

  test('Todos prioriza pendientes antiguos; fechas desconocidas al final del grupo', () {
    final orders = [
      order('nuevo', OrderStatus.entregado, 25),
      order('p2', OrderStatus.pendiente, 10),
      order('desconocido', OrderStatus.pendiente, 1, known: false),
      order('p1', OrderStatus.pendiente, 2),
      order('viejo', OrderStatus.aprobado, 4),
    ];
    expect(sellerOrderList(orders).map((o) => o.number), [
      'p1',
      'p2',
      'desconocido',
      'nuevo',
      'viejo',
    ]);
    expect(
      sellerOrderList(
        orders,
        status: OrderStatus.pendiente,
      ).map((o) => o.number),
      ['p1', 'p2', 'desconocido'],
    );
    for (final status in OrderStatus.values) {
      expect(
        sellerOrderList(
          orders,
          status: status,
        ).every((o) => o.status == status),
        isTrue,
      );
    }
  });
  testWidgets(
    'cantidad editable conserva foco y valida vacío, cero, decimales, negativos y máximo',
    (tester) async {
      var quantity = 1, exceeded = 0;
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                refresh = update;
                return QuantityStepper(
                  editable: true,
                  value: quantity,
                  max: 25,
                  onLimitExceeded: (_) => exceeded++,
                  onChanged: (v) => update(() => quantity = v),
                );
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.enterText(field, '');
      await tester.pump();
      expect(quantity, 1);
      refresh(() {});
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      await tester.enterText(field, '-4');
      expect(tester.widget<TextField>(field).controller!.text, '');
      await tester.enterText(field, '1.5');
      expect(tester.widget<TextField>(field).controller!.text, '');
      await tester.enterText(field, '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(quantity, 25);
      expect(exceeded, 1);
      await tester.tap(field);
      await tester.enterText(field, '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(quantity, 1);
      await tester.tap(field);
      await tester.enterText(field, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(quantity, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cancelar perfil con foco no guarda ni usa controladores eliminados',
    (tester) async {
      final service = PharmaService.instance;
      final driver = PharmaService.demoUsers.firstWhere(
        (u) => u.role.name == 'repartidor',
      );
      await service.login(
        email: driver.email,
        password: PharmaService.demoPassword,
      );
      final original = service.currentUser!;
      await tester.pumpWidget(
        const MaterialApp(home: EmployeeAccountScreen(title: 'Mi cuenta')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'No guardar');
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(ContactEditDialog), findsNothing);
      expect(service.currentUser!.name, original.name);
      expect(service.currentUser!.phone, original.phone);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.logout();
    },
  );
  testWidgets('entrega finalizada muestra detalle y ninguna acción operativa', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeliveryCard(
            delivery: DeliveryRecord('ENT001', {
              'estado': 'Entregado',
              'pedido_numero': 'PED001',
              'farmacia': 'Mi farmacia',
              'direccion': 'Calle 1',
              'telefono': '70012345',
              'fecha_estado': DateTime(2026, 1, 10),
            }),
          ),
        ),
      ),
    );
    expect(find.text('Entregada'), findsOneWidget);
    expect(find.text('70012345'), findsOneWidget);
    expect(find.text('INICIAR REPARTO'), findsNothing);
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
