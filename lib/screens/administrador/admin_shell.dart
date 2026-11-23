import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/admin_dashboard_viewmodel.dart';
import '../login_screen.dart';
import 'admin_account_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';

/// Contenedor principal del módulo Administrador.
///
/// El módulo solo se construye cuando la sesión activa tiene rol
/// administrador. Si el rol cambia (o se intenta abrir sin permisos) se
/// bloquea el acceso; las reglas de Firestore siguen siendo la última línea de
/// defensa de los datos.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late int _index = widget.initialIndex;
  late final AdminDashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AdminDashboardViewModel()..init();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  Future<void> _leave() async {
    await PharmaService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (PharmaService.instance.role != UserRole.administrador) {
      return _DeniedScreen(onLeave: _leave);
    }

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _selectTab(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            AdminDashboardScreen(viewModel: _viewModel),
            const AdminUsersScreen(),
            const AdminAccountScreen(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Panel',
              ),
              NavigationDestination(
                icon: Icon(Icons.manage_accounts_outlined),
                selectedIcon: Icon(Icons.manage_accounts_rounded),
                label: 'Usuarios',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Mi cuenta',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeniedScreen extends StatelessWidget {
  const _DeniedScreen({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  color: AppColors.dangerBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 38,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Acceso restringido',
                textAlign: TextAlign.center,
                style: AppText.h2,
              ),
              const SizedBox(height: 8),
              const Text(
                'El panel administrativo solo está disponible para el rol '
                'Administrador. Inicia sesión con una cuenta autorizada.',
                textAlign: TextAlign.center,
                style: AppText.muted,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onLeave,
                  child: const Text('Volver al inicio de sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
