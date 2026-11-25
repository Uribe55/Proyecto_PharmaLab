import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/models/app_user.dart';
import 'package:proyecto_final_movil/screens/administrador/admin_shell.dart';
import 'package:proyecto_final_movil/screens/cliente_farmacia/client_shell.dart';
import 'package:proyecto_final_movil/screens/repartidor/driver_shell.dart';
import 'package:proyecto_final_movil/screens/vendedor/seller_shell.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/theme/app_theme.dart';
import 'package:proyecto_final_movil/widgets/pharma_logo.dart';
import 'package:proyecto_final_movil/widgets/account_navigation.dart';

void main() {
  for (final role in UserRole.values) {
    testWidgets('Logo y acceso a la cuenta de ${role.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = PharmaService.instance;
      final user = PharmaService.demoUsers.firstWhere((u) => u.role == role);
      expect(
        await service.login(
          email: user.email,
          password: PharmaService.demoPassword,
        ),
        isNull,
      );
      final shell = switch (role) {
        UserRole.cliente => const ClientShell(),
        UserRole.vendedor => const SellerShell(),
        UserRole.repartidor => const DriverShell(),
        UserRole.administrador => const AdminShell(),
      };
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: shell),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PharmaLogo), findsOneWidget);
      await tester.tap(find.byType(AccountAvatarButton).hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        role == UserRole.cliente ? 3 : 2,
      );
      expect(find.text(user.name), findsWidgets);
      expect(tester.takeException(), isNull);
      // Volver al inicio con el botón del sistema conserva el shell.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      if (role == UserRole.cliente) {
        await tester.tap(find.textContaining('necesita tu laboratorio'));
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(AccountAvatarButton).hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsNothing);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await service.logout();
    });
  }
}
