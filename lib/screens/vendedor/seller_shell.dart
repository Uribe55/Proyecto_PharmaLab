import 'package:flutter/material.dart';

import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import 'seller_account_screen.dart';
import 'seller_assignments_screen.dart';
import 'seller_orders_screen.dart';

/// Contenedor principal del módulo Vendedor.
class SellerShell extends StatefulWidget {
  const SellerShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  late int _index = widget.initialIndex;

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final pending = PharmaService.instance.pendingOrdersCount;

        return PopScope(
          canPop: _index == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _selectTab(0);
          },
          child: Scaffold(
            body: IndexedStack(
              index: _index,
              children: const [
                SellerOrdersScreen(),
                SellerAssignmentsScreen(),
                SellerAccountScreen(),
              ],
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _selectTab,
                destinations: [
                  NavigationDestination(
                    icon: Badge.count(
                      count: pending,
                      isLabelVisible: pending > 0,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.inbox_outlined),
                    ),
                    selectedIcon: Badge.count(
                      count: pending,
                      isLabelVisible: pending > 0,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.inbox_rounded),
                    ),
                    label: 'Pedidos',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(Icons.local_shipping_rounded),
                    label: 'Entregas',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Mi cuenta',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
