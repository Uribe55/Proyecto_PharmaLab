import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/client_shell.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/product_detail_screen.dart';
import 'package:proyecto_final_movil/screens/vendedor/seller_orders_screen.dart';
import 'package:proyecto_final_movil/screens/repartidor/driver_deliveries_screen.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/viewmodels/cart_view_model.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';
import 'package:proyecto_final_movil/widgets/pharma_logo.dart';
import 'package:proyecto_final_movil/widgets/staff_filter_chip.dart';
import 'package:proyecto_final_movil/utils/formatters.dart';

void main() {
  Future<void> login(String role) async {
    final user = PharmaService.demoUsers.firstWhere((u) => u.role.name == role);
    await PharmaService.instance.login(
      email: user.email,
      password: PharmaService.demoPassword,
    );
  }

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
  }

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.6)),
      child: child!,
    ),
    home: child,
  );

  testWidgets(
    'Carrito: cantidad visible y editable con teclado en pantalla pequeña',
    (tester) async {
      phone(tester);
      await login('cliente');
      final cart = CartViewModel.instance;
      cart.clear();
      final product = PharmaService.instance.products.firstWhere(
        (p) => p.stock >= 5,
      );
      cart.add(product, quantity: 1);
      await tester.pumpWidget(app(const ClientShell(initialIndex: 2)));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.ensureVisible(field);
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.enterText(field, '4');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(field);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(844 - 320));
      expect(tester.widget<TextField>(field).controller!.text, '4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cart.quantityFor(product), 4);
      await tester.pumpWidget(const SizedBox());
      cart.clear();
      await PharmaService.instance.logout();
    },
  );

  testWidgets(
    'Detalle: escritura directa, límite de stock y total actualizado',
    (tester) async {
      phone(tester);
      await login('cliente');
      final cart = CartViewModel.instance;
      cart.clear();
      final product = PharmaService.instance.products.firstWhere(
        (p) => p.stock >= 5,
      );
      await tester.pumpWidget(app(ProductDetailScreen(product: product)));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.scrollUntilVisible(field, 250);
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.enterText(field, '4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '4');
      expect(find.text(formatBs(product.estimatedTotal(4))), findsOneWidget);
      await tester.ensureVisible(field);
      await tester.enterText(field, '${product.stock + 1}');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        '${product.stock}',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await PharmaService.instance.logout();
    },
  );

  for (final role in ['vendedor', 'repartidor']) {
    testWidgets('$role: logo y filtros comparten un scroll vertical', (
      tester,
    ) async {
      phone(tester);
      await login(role);
      await tester.pumpWidget(
        app(
          role == 'vendedor'
              ? const SellerOrdersScreen()
              : const DriverDeliveriesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PharmaLogo), findsOneWidget);
      final vertical = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      expect(vertical, findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(StaffFilterChip).first,
        150,
        scrollable: vertical,
      );
      await tester.tap(find.byType(StaffFilterChip).first);
      await tester.pumpAndSettle();
      expect(find.byType(PharmaLogo).hitTestable(), findsNothing);
      await tester.drag(vertical, const Offset(0, 1800));
      await tester.pumpAndSettle();
      expect(find.byType(PharmaLogo).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await PharmaService.instance.logout();
    });
  }
}
