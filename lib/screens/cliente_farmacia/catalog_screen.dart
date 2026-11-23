import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../viewmodels/catalog_view_model.dart';
import '../../services/cart_service.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_card.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.initialCategory, this.initialCategoryId});

  final ProductCategory? initialCategory;
  final String? initialCategoryId;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();

  late ProductCategory? _selectedCategory = widget.initialCategory;
  String? _selectedCategoryId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _query.trim().toLowerCase();
    final remote = PharmaService.instance.usesFirebase;

    return products.where((product) {
      final matchesCategory = remote
          ? _selectedCategoryId == null || product.categoryId == _selectedCategoryId
          : _selectedCategory == null || product.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query) ||
          product.presentation.toLowerCase().contains(query) ||
          product.code.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _addToCart(Product product) {
    final added = CartService.instance.add(product);
    final message = added
        ? '${product.name} se agregó al carrito.'
        : product.isAvailable
            ? 'No hay más unidades disponibles de ${product.name}.'
            : '${product.name} no tiene stock disponible.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = CatalogViewModel.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([PharmaService.instance, vm]),
      builder: (context, _) {
        final remote = PharmaService.instance.usesFirebase;
        final products = _filterProducts(
          remote ? vm.products : PharmaService.instance.products,
        );

        return Scaffold(
          appBar: const ClientPageAppBar(
            title: 'Catálogo',
            showAvatar: true,
          ),
          body: remote && vm.loading
              ? const Center(child: CircularProgressIndicator())
              : remote && vm.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(vm.error!, textAlign: TextAlign.center),
                      ),
                    )
                  : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o laboratorio',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: remote ? _selectedCategoryId == null : _selectedCategory == null,
                      onTap: () => setState(() {
                        _selectedCategory = null;
                        _selectedCategoryId = null;
                      }),
                    ),
                    if (remote)
                      for (final category in vm.categories) ...[
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: category.name,
                          selected: _selectedCategoryId == category.id,
                          onTap: () => setState(() => _selectedCategoryId = category.id),
                        ),
                      ]
                    else
                      for (final category in ProductCategory.values) ...[
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: category.label,
                          selected: _selectedCategory == category,
                          onTap: () => setState(() => _selectedCategory = category),
                        ),
                      ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${products.length} '
                      '${products.length == 1 ? 'producto' : 'productos'}',
                      style: AppText.meta.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    if (!remote && _selectedCategory != null)
                      Text(
                        _selectedCategory!.label,
                        style: AppText.meta,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Sin resultados',
                            description: 'No encontramos productos con los '
                                'filtros seleccionados. Prueba con otra '
                                'búsqueda o categoría.',
                            action: OutlinedButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _selectedCategory = null;
                                  _selectedCategoryId = null;
                                });
                              },
                              child: const Text('Limpiar filtros'),
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width >= 720 ? 3 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 248,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            onTap: () => _openProduct(product),
                            onAdd: remote ? null : () => _addToCart(product),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
