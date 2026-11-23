import 'package:flutter/material.dart';

import '../../models/dashboard_models.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/admin_dashboard_viewmodel.dart';
import '../../widgets/app_header.dart';
import '../../widgets/dashboard/dashboard_alerts.dart';
import '../../widgets/dashboard/dashboard_charts.dart';
import '../../widgets/dashboard/dashboard_kpi_card.dart';
import '../../widgets/empty_state.dart';

enum InventoryFilter { todos, agotados, bajo, vencidos, porVencer }

/// Detalle de inventario, stock utilizable y vencimientos.
///
/// Vista de solo lectura. El stock se toma de `lotes_productos` cuando hay
/// Firestore; en modo local se muestra el stock del catálogo de demostración y
/// se indica que no hay lotes ni vencimientos disponibles.
class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({
    super.key,
    required this.viewModel,
    this.initialFilter = InventoryFilter.todos,
  });

  final AdminDashboardViewModel viewModel;
  final InventoryFilter initialFilter;

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  late InventoryFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final inventory = vm.inventory;
        final now = DateTime.now();
        final products = _filteredProducts(inventory);
        final lots = _filteredLots(inventory, now);

        return Scaffold(
          appBar: AppPageAppBar(
            title: 'Inventario',
            actions: [
              IconButton(
                tooltip: 'Actualizar inventario',
                onPressed: vm.loadingInventory
                    ? null
                    : () => vm.loadInventory(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const Text('CONTROL DE INVENTARIO', style: AppText.eyebrow),
                const SizedBox(height: 7),
                const Text('Existencias y vencimientos.', style: AppText.h1),
                const SizedBox(height: 6),
                const Text(
                  'El stock utilizable excluye los lotes vencidos y respeta el '
                  'umbral de cada producto.',
                  style: AppText.muted,
                ),
                const SizedBox(height: 14),
                _InventorySource(
                  inventory: inventory,
                  onRefresh: vm.loadInventory,
                  refreshing: vm.loadingInventory,
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in InventoryFilter.values) ...[
                        _FilterChip(
                          label: _filterLabel(filter),
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                        if (filter != InventoryFilter.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (vm.loadingInventory)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (inventory.error != null)
                  DashboardErrorSurface(
                    message: inventory.error!,
                    onRetry: vm.loadInventory,
                  )
                else if (!inventory.hasData)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Aún no hay información de inventario',
                      description:
                          inventory.note ??
                          'No se encontraron productos ni lotes en '
                              'lotes_productos.',
                      action: OutlinedButton(
                        onPressed: vm.loadInventory,
                        child: const Text('Volver a consultar'),
                      ),
                    ),
                  )
                else ...[
                  const Text('Resumen de stock', style: AppText.h3),
                  const SizedBox(height: 10),
                  _SummaryGrid(
                    items: [
                      (
                        'Agotados',
                        '${inventory.products.where((p) => p.level == StockLevel.agotado).length}',
                        Icons.remove_shopping_cart_outlined,
                        AppColors.danger,
                        AppColors.dangerBackground,
                      ),
                      (
                        'Stock bajo',
                        '${inventory.products.where((p) => p.level == StockLevel.bajo).length}',
                        Icons.warning_amber_rounded,
                        AppColors.pendingText,
                        AppColors.pendingBackground,
                      ),
                      (
                        'Disponibles',
                        '${inventory.products.where((p) => p.level == StockLevel.normal).length}',
                        Icons.check_circle_outline_rounded,
                        AppColors.successText,
                        AppColors.successBackground,
                      ),
                      (
                        'Lotes',
                        '${inventory.lots.length}',
                        Icons.inventory_2_outlined,
                        AppColors.primary,
                        AppColors.mint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Productos', style: AppText.h3),
                      ),
                      Text(
                        '${products.length} resultado(s)',
                        style: AppText.meta,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (products.isEmpty)
                    const DashboardSurface(
                      child: DashboardEmptyText(
                        icon: Icons.inventory_2_outlined,
                        text: 'No hay productos que coincidan con el filtro.',
                      ),
                    )
                  else
                    for (final product in products) ...[
                      _ProductStockTile(product: product),
                      if (product != products.last) const SizedBox(height: 9),
                    ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Lotes y vencimientos', style: AppText.h3),
                      ),
                      Text('${lots.length} lote(s)', style: AppText.meta),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!inventory.hasLotData)
                    DashboardSurface(
                      child: DashboardEmptyText(
                        icon: Icons.event_busy_outlined,
                        text:
                            inventory.note ??
                            'No hay lotes registrados. La fecha de vencimiento '
                                'solo se evalúa cuando requiere_vencimiento es '
                                'verdadero.',
                      ),
                    )
                  else if (lots.isEmpty)
                    const DashboardSurface(
                      child: DashboardEmptyText(
                        icon: Icons.event_available_outlined,
                        text:
                            'No hay lotes que coincidan con el filtro de '
                            'vencimiento.',
                      ),
                    )
                  else
                    for (final lot in lots) ...[
                      _LotTile(lot: lot, now: now),
                      if (lot != lots.last) const SizedBox(height: 9),
                    ],
                  if (inventory.productsWithoutLots > 0) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${inventory.productsWithoutLots} producto(s) del '
                      'catálogo no tienen lotes registrados; su stock no se '
                      'contabiliza para evitar datos duplicados.',
                      style: AppText.meta.copyWith(fontSize: 10),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Umbral de stock bajo: '
                    '${inventory.lowStockThreshold} unidades, salvo que el '
                    'producto defina stock_minimo o umbral_stock.',
                    style: AppText.meta.copyWith(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<DashboardProductStock> _filteredProducts(DashboardInventory inventory) {
    return switch (_filter) {
      InventoryFilter.agotados =>
        inventory.products
            .where((product) => product.level == StockLevel.agotado)
            .toList(),
      InventoryFilter.bajo =>
        inventory.products
            .where((product) => product.level == StockLevel.bajo)
            .toList(),
      _ => inventory.products,
    };
  }

  List<DashboardLot> _filteredLots(DashboardInventory inventory, DateTime now) {
    if (!inventory.hasLotData) return const [];
    return inventory.lots.where((lot) {
      if (lot.quantity <= 0) return false;
      final days = lot.daysToExpire(now);
      return switch (_filter) {
        InventoryFilter.vencidos => days != null && days < 0,
        InventoryFilter.porVencer => days != null && days >= 0 && days <= 90,
        _ => true,
      };
    }).toList()..sort((a, b) {
      final aDate = a.expiresAt;
      final bDate = b.expiresAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
  }

  String _filterLabel(InventoryFilter filter) {
    return switch (filter) {
      InventoryFilter.todos => 'Todos',
      InventoryFilter.agotados => 'Agotados',
      InventoryFilter.bajo => 'Stock bajo',
      InventoryFilter.vencidos => 'Vencidos',
      InventoryFilter.porVencer => 'Por vencer',
    };
  }
}

class _InventorySource extends StatelessWidget {
  const _InventorySource({
    required this.inventory,
    required this.onRefresh,
    required this.refreshing,
  });

  final DashboardInventory inventory;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (inventory.origin) {
      InventoryOrigin.firestore => (
        'lotes_productos · Firestore',
        AppColors.successText,
        AppColors.successBackground,
      ),
      InventoryOrigin.local => (
        'Stock local de demostración',
        AppColors.pendingText,
        AppColors.pendingBackground,
      ),
      InventoryOrigin.permissionDenied => (
        'Permisos denegados para el inventario',
        AppColors.danger,
        AppColors.dangerBackground,
      ),
      InventoryOrigin.unavailable => (
        'Inventario no disponible',
        AppColors.danger,
        AppColors.dangerBackground,
      ),
      InventoryOrigin.loading => (
        'Cargando inventario…',
        AppColors.muted,
        AppColors.background,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar inventario',
            visualDensity: VisualDensity.compact,
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<(String, String, IconData, Color, Color)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 9) / 2;
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: DashboardKpiCard(
                  label: item.$1,
                  value: item.$2,
                  icon: item.$3,
                  accent: item.$4,
                  background: item.$5,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProductStockTile extends StatelessWidget {
  const _ProductStockTile({required this.product});

  final DashboardProductStock product;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (product.level) {
      StockLevel.agotado => (
        'Agotado',
        AppColors.danger,
        AppColors.dangerBackground,
      ),
      StockLevel.bajo => (
        'Stock bajo',
        AppColors.pendingText,
        AppColors.pendingBackground,
      ),
      StockLevel.normal => (
        'Disponible',
        AppColors.successText,
        AppColors.successBackground,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${product.category} · ${product.lotCount} lote(s)',
            style: AppText.meta.copyWith(fontSize: 9.5),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Disponible: ${product.usable} u.',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                'Umbral: ${product.threshold}',
                style: AppText.meta.copyWith(fontSize: 9.5),
              ),
            ],
          ),
          if (product.expired > 0 || product.nextExpiration != null) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              runSpacing: 3,
              children: [
                if (product.expired > 0)
                  Text(
                    '${product.expired} u. vencidas excluidas',
                    style: AppText.meta.copyWith(
                      fontSize: 9.5,
                      color: AppColors.danger,
                    ),
                  ),
                if (product.nextExpiration != null)
                  Text(
                    'Próximo vencimiento: ${_date(product.nextExpiration!)}',
                    style: AppText.meta.copyWith(fontSize: 9.5),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _LotTile extends StatelessWidget {
  const _LotTile({required this.lot, required this.now});

  final DashboardLot lot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = lot.daysToExpire(now);
    final expired = days != null && days < 0;
    final soon = days != null && days >= 0 && days <= 30;
    final color = expired
        ? AppColors.danger
        : (soon ? AppColors.pendingText : AppColors.successText);
    final background = expired
        ? AppColors.dangerBackground
        : (soon ? AppColors.pendingBackground : AppColors.successBackground);
    final expiryLabel = lot.expiresAt == null
        ? 'Sin fecha de vencimiento'
        : _date(lot.expiresAt!);
    final statusLabel = days == null
        ? 'No requiere control'
        : (expired
              ? 'Vencido hace ${days.abs()} día(s)'
              : 'Vence en $days día(s)');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              expired
                  ? Icons.event_busy_rounded
                  : Icons.event_available_outlined,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lot.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (lot.lotCode.isNotEmpty) 'Lote ${lot.lotCode}',
                    '${lot.quantity} u.',
                    lot.category,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                expiryLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(statusLabel, style: AppText.meta.copyWith(fontSize: 8.5)),
            ],
          ),
        ],
      ),
    );
  }

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
