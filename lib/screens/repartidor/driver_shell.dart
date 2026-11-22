import 'package:flutter/material.dart';

import '../../services/pharma_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import 'driver_account_screen.dart';
import 'driver_deliveries_screen.dart';
import 'driver_history_screen.dart';

/// Contenedor principal del módulo Repartidor.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  late int _index = widget.initialIndex;

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PharmaService.instance,
        SyncService.instance,
      ]),
      builder: (context, _) {
        final service = PharmaService.instance;
        final driver = service.currentUser;
        final active = driver == null
            ? 0
            : service
                  .ordersForDriver(driver.id)
                  .where((order) => order.isInTransit)
                  .length;

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
                DriverDeliveriesScreen(),
                DriverHistoryScreen(),
                DriverAccountScreen(),
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
                      count: active,
                      isLabelVisible: active > 0,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.local_shipping_outlined),
                    ),
                    selectedIcon: Badge.count(
                      count: active,
                      isLabelVisible: active > 0,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.local_shipping_rounded),
                    ),
                    label: 'Mis entregas',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.history_rounded),
                    selectedIcon: Icon(Icons.history_toggle_off_rounded),
                    label: 'Historial',
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
