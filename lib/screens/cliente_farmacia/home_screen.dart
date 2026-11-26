import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../viewmodels/cart_view_model.dart';
import '../../services/pharma_service.dart';
import '../../viewmodels/catalog_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_card.dart';
import '../../widgets/account_navigation.dart';
import '../../widgets/client_avatar.dart';
import '../../widgets/pharma_logo.dart';
import '../../widgets/product_card.dart';
import '../../widgets/cart_navigation.dart';
import '../../widgets/section_header.dart';
import 'catalog_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCatalog(
    BuildContext context, [
    ProductCategory? category,
    String? categoryId,
  ]) {
    final openAccount = AccountNavigation.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => AccountNavigation(
          onOpenAccount: () {
            Navigator.of(routeContext).pop();
            openAccount?.call();
          },
          child: CatalogScreen(
            onOpenCart: CartNavigation.of(context),
            initialCategory: category,
            initialCategoryId: categoryId,
          ),
        ),
      ),
    );
  }

  void _openProduct(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          onOpenCart: CartNavigation.of(context),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, Product product) {
    if (CartViewModel.instance.quantityFor(product) > 0) {
      CartNavigation.of(context)?.call();
      return;
    }
    final added = CartViewModel.instance.add(product);
    final message = added
        ? '${product.name} se agregó al carrito.'
        : product.isAvailable
        ? 'No hay más unidades disponibles de ${product.name}.'
        : '${product.name} no tiene stock disponible.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = CatalogViewModel.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        PharmaService.instance,
        vm,
        CartViewModel.instance,
      ]),
      builder: (context, _) {
        final pharmacy = PharmaService.instance.pharmacy;
        final remote = PharmaService.instance.usesFirebase;
        final featured = remote
            ? vm.featuredProducts
            : PharmaService.instance.featuredProducts;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PharmaLogo(height: 46),
                        ),
                      ),
                      SizedBox(width: 12),
                      ClientAvatar(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${pharmacy.firstName}',
                        style: AppText.muted.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pharmacy.commercialName,
                        style: AppText.h1.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openCatalog(context),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.muted,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '¿Qué necesita tu laboratorio?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _PromoBanner(onExplore: () => _openCatalog(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: SectionHeader(
                    title: 'Categorías',
                    trailingLabel: 'Ver todas',
                    onTrailingTap: () => _openCatalog(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: remote
                      ? SizedBox(
                          height: 108,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: vm.categories.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final item = vm.categories[index];
                              return SizedBox(
                                width: 122,
                                child: CategoryCard(
                                  category: item.visualCategory,
                                  labelOverride: item.name,
                                  onTap: () =>
                                      _openCatalog(context, null, item.id),
                                ),
                              );
                            },
                          ),
                        )
                      : SizedBox(
                          height: 108,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: ProductCategory.values.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final category = ProductCategory.values[index];
                              return SizedBox(
                                width: 122,
                                child: CategoryCard(
                                  category: category,
                                  onTap: () => _openCatalog(context, category),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                  child: SectionHeader(
                    title: 'Productos destacados',
                    caption: '${featured.length} productos',
                  ),
                ),
                if (remote && vm.loading)
                  const Padding(
                    padding: EdgeInsets.all(22),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (remote && vm.error != null)
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(vm.error!, textAlign: TextAlign.center),
                  )
                else if (featured.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('No hay productos disponibles por ahora.'),
                  )
                else
                  GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 720
                          ? 3
                          : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 248,
                    ),
                    itemCount: featured.length,
                    itemBuilder: (context, index) {
                      final product = featured[index];
                      return ProductCard(
                        product: product,
                        inCart: CartViewModel.instance.quantityFor(product) > 0,
                        onViewCart: CartNavigation.of(context),
                        onTap: () => _openProduct(context, product),
                        onAdd: () => _addToCart(context, product),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _QualityNote(remote: remote),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.mint, AppColors.brandGreenTint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU ALIADO EN DIAGNÓSTICO',
                  style: AppText.eyebrow.copyWith(
                    fontSize: 8.5,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ciencia y calidad.\nEn cada pedido.',
                  style: AppText.h2.copyWith(fontSize: 19.5, height: 1.18),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Soluciones que hacen la diferencia.',
                  style: AppText.meta,
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onExplore,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explorar catálogo',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.biotech_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityNote extends StatelessWidget {
  const _QualityNote({required this.remote});

  final bool remote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Productos de calidad · Atención en Bolivia',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ),
          ],
        ),
        SizedBox(height: 5),
        Text(
          remote
              ? 'Catálogo desde Firebase · pedidos todavía no habilitados.'
              : 'Precios y existencias de demostración.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
        ),
      ],
    );
  }
}
