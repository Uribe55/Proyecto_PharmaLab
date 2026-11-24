import 'package:proyecto_final_movil/screens/cliente_farmacia/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/models/app_user.dart';
import 'package:proyecto_final_movil/models/product.dart';
import 'package:proyecto_final_movil/services/cart_service.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/viewmodels/cart_view_model.dart';
import 'package:proyecto_final_movil/viewmodels/catalog_view_model.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/checkout_screen.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/cart_screen.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/client_shell.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';

Product product(String id, {double price = 150, int stock = 10}) => Product(
  id: id,
  name: id,
  brand: '',
  presentation: 'Caja de 20 tabletas',
  category: ProductCategory.genericos,
  price: price,
  stock: stock,
  unitOfMeasure: 'Caja',
  unitsPerPackage: 20,
);

class Session extends ChangeNotifier implements PharmaService {
  @override
  bool get usesFirebase => true;
  @override
  AppUser? currentUser = AppUser(
    id: 'one',
    name: 'Uno',
    email: 'uno@test.bo',
    phone: '',
    role: UserRole.cliente,
  );
  int confirmations = 0;
  void switchUser(String? id) {
    currentUser = id == null
        ? null
        : AppUser(
            id: id,
            name: id,
            email: '$id@test.bo',
            phone: '',
            role: UserRole.cliente,
          );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #createOrder) confirmations++;
    return super.noSuchMethod(invocation);
  }
}

class Catalog extends ChangeNotifier implements CatalogViewModel {
  @override
  bool ready = true;
  @override
  List<Product> products = [];
  void update(List<Product> values) {
    products = values;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final service = CartService.instance;
  late Session session;
  late Catalog catalog;
  late CartViewModel vm;
  setUp(() {
    service.clear();
    session = Session();
    catalog = Catalog()
      ..products = [product('PROD001'), product('PROD002', price: 85)];
    vm = CartViewModel(session: session, catalog: catalog);
  });
  tearDown(() {
    vm.dispose();
    session.dispose();
    catalog.dispose();
    service.clear();
  });

  testWidgets(
    'Detalle real agrega la cantidad comercial y reacciona al catálogo',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProductDetailScreen(product: catalog.products.first, cart: vm),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(Icons.add_rounded),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Añadir al carrito'));
      await tester.pumpAndSettle();
      expect(vm.totalUnits, 2);
      expect(vm.subtotal, 300);
      expect(find.textContaining('se agregó al carrito'), findsOneWidget);
      catalog.update([]);
      await tester.pumpAndSettle();
      expect(vm.canReview, isFalse);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    },
  );
  test('Acumula por ID y calcula Bs 555 por cinco cajas', () {
    expect(vm.add(product('PROD001')), isTrue);
    expect(vm.add(product('PROD001')), isTrue);
    expect(vm.add(product('PROD002'), quantity: 3), isTrue);
    expect(vm.lineCount, 2);
    expect(vm.totalUnits, 5);
    expect(vm.items.first.subtotal, 300);
    expect(vm.items.last.subtotal, 255);
    expect(vm.subtotal, 555);
    expect(catalog.products.first.stock, 10);
  });
  test('Incrementa, reduce, rechaza negativos y exceso; elimina y vacía', () {
    final p = catalog.products.first;
    expect(vm.add(p, quantity: -1), isFalse);
    expect(vm.add(p, quantity: 11), isFalse);
    vm.add(p);
    vm.setQuantity(p, 3);
    expect(vm.totalUnits, 3);
    vm.setQuantity(p, 11);
    expect(vm.totalUnits, 3);
    vm.setQuantity(p, 2);
    expect(vm.totalUnits, 2);
    vm.setQuantity(p, 0);
    expect(vm.isEmpty, isTrue);
    vm.add(p);
    vm.remove(p);
    expect(vm.isEmpty, isTrue);
    vm.add(p);
    vm.clear();
    expect(vm.isEmpty, isTrue);
  });
  test('Reconcilia precio y stock sin reducir cantidades silenciosamente', () {
    vm.add(catalog.products.first, quantity: 4);
    catalog.update([product('PROD001', price: 160, stock: 2)]);
    expect(vm.subtotal, 640);
    expect(vm.items.single.priceChanged, isTrue);
    expect(vm.items.single.quantity, 4);
    expect(vm.canReview, isFalse);
    vm.adjust(vm.items.single);
    expect(vm.totalUnits, 2);
    expect(vm.canReview, isTrue);
    catalog.update([product('PROD001', price: 160, stock: 8)]);
    expect(vm.add(product('PROD001'), quantity: 6), isTrue);
    expect(vm.totalUnits, 8);
  });
  test('Detecta stock cero, desaparición y recuperación del producto', () {
    vm.add(catalog.products.first, quantity: 2);
    catalog.update([product('PROD001', stock: 0)]);
    expect(vm.canReview, isFalse);
    expect(vm.items.single.quantity, 2);
    expect(vm.add(product('PROD001')), isFalse);
    catalog.update([]);
    expect(vm.items.single.availableInCatalog, isFalse);
    expect(vm.canReview, isFalse);
    catalog.update([product('PROD001')]);
    expect(vm.canReview, isTrue);
    catalog.ready = false;
    catalog.notifyListeners();
    expect(vm.canReview, isFalse);
  });
  test('El carrito no se comparte entre cuentas ni al cerrar sesión', () {
    vm.add(catalog.products.first);
    session.switchUser('two');
    expect(vm.isEmpty, isTrue);
    vm.add(catalog.products.first);
    session.switchUser(null);
    expect(vm.isEmpty, isTrue);
    session.switchUser('one');
    expect(vm.isEmpty, isTrue);
  });
  testWidgets(
    'Resumen real deshabilita confirmación y conserva carrito e inventario',
    (tester) async {
      vm.add(catalog.products.first, quantity: 2);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CheckoutScreen(cart: vm),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Las compras de producción permanecen deshabilitadas. La confirmación está disponible únicamente en el entorno de pruebas.',
        ),
        findsOneWidget,
      );
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirmar pedido'),
      );
      expect(button.onPressed, isNull);
      expect(vm.canConfirm, isFalse);
      expect(() => vm.confirmDemoOrder(), throwsStateError);
      expect(vm.totalUnits, 2);
      expect(catalog.products.first.stock, 10);
      expect(session.confirmations, 0);
      catalog.update([product('PROD001', price: 170)]);
      await tester.pumpAndSettle();
      expect(vm.subtotal, 340);
    },
  );
  testWidgets(
    'El carrito permite cancelar y confirmar vaciado en pantalla pequeña',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final local = CartViewModel.instance;
      local.add(product('local'), quantity: 2);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CartScreen(onBrowse: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vaciar carrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(local.totalUnits, 2);
      await tester.tap(find.text('Vaciar carrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vaciar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
    },
  );
  testWidgets('Contador de navegación reacciona al carrito', (tester) async {
    final local = CartViewModel.instance;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ClientShell(initialIndex: 2),
      ),
    );
    await tester.pumpAndSettle();
    local.add(product('local'));
    await tester.pumpAndSettle();
    final badge = tester.widgetList<Badge>(find.byType(Badge)).first;
    expect(badge.isLabelVisible, isTrue);
    expect((badge.label! as Text).data, '1');
    local.clear();
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Badge>(find.byType(Badge)).first.isLabelVisible,
      isFalse,
    );
  });
}
