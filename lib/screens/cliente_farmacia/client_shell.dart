import 'package:flutter/material.dart';

import '../../viewmodels/cart_view_model.dart';
import '../../services/pharma_service.dart';
import '../../viewmodels/catalog_view_model.dart';
import '../../theme/app_theme.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';

/// Contenedor principal del módulo Cliente Farmacia.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    CartViewModel.instance.addListener(_onCartChanged);
    if (PharmaService.instance.usesFirebase) {
      CatalogViewModel.instance.start();
    }
  }

  @override
  void dispose() {
    CartViewModel.instance.removeListener(_onCartChanged);
    CatalogViewModel.instance.stop();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = CartViewModel.instance.lineCount;

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
            const HomeScreen(),
            OrderHistoryScreen(onBrowse: () => _selectTab(0)),
            CartScreen(onBrowse: () => _selectTab(0)),
            const ProfileScreen(),
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
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Catálogo',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Mis pedidos',
              ),
              NavigationDestination(
                icon: Badge.count(
                  count: cartCount,
                  isLabelVisible: cartCount > 0,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                selectedIcon: Badge.count(
                  count: cartCount,
                  isLabelVisible: cartCount > 0,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.shopping_cart_rounded),
                ),
                label: 'Carrito',
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
  }
}
