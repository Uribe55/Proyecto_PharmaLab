import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'admin_account_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';

/// Contenedor principal del módulo Administrador.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late int _index = widget.initialIndex;

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
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
            AdminDashboardScreen(onOpenUsers: () => _selectTab(1)),
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
