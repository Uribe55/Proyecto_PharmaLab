import '../shared/remote_logistics_screen.dart';

import 'package:flutter/material.dart';

import '../../widgets/account_navigation.dart';
import '../../data/datasources/firestore_staff_order_data_source.dart';
import '../../models/app_user.dart';
import '../../viewmodels/seller_orders_view_model.dart';
import 'remote_seller_orders_screen.dart';

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
  SellerOrdersViewModel? _remote;
  int _notificationVersion = 0;

  @override
  void initState() {
    super.initState();
    final service = PharmaService.instance;
    if (service.usesFirebase) {
      _remote = SellerOrdersViewModel(
        repository: FirestoreStaffOrderDataSource(),
        sessionChanges: service,
        authorizedUid: () =>
            service.currentUser?.active == true &&
                [
                  UserRole.vendedor,
                  UserRole.administrador,
                ].contains(service.role)
            ? service.uid
            : null,
      );
      _remote!.addListener(_announceNewOrders);
    }
  }

  void _announceNewOrders() {
    final vm = _remote!;
    if (vm.notificationVersion == _notificationVersion) return;
    _notificationVersion = vm.notificationVersion;
    final count = vm.newPendingCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || PharmaService.instance.uid == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? 'Llegó un nuevo pedido pendiente.'
                : 'Llegaron $count pedidos pendientes.',
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _remote?.removeListener(_announceNewOrders);
    _remote?.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([PharmaService.instance, ?_remote]),
      builder: (context, _) {
        final pending =
            _remote?.pendingCount ?? PharmaService.instance.pendingOrdersCount;

        return PopScope(
          canPop: _index == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _selectTab(0);
          },
          child: Scaffold(
            body: AccountNavigation(
              onOpenAccount: () => _selectTab(2),
              child: IndexedStack(
                index: _index,
                children: [
                  if (_remote != null)
                    RemoteSellerOrdersScreen(viewModel: _remote!)
                  else
                    const SellerOrdersScreen(),
                  if (_remote != null)
                    const RemoteLogisticsScreen()
                  else
                    const SellerAssignmentsScreen(),
                  const SellerAccountScreen(),
                ],
              ),
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
