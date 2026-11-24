import 'package:flutter/material.dart';

import '../../models/cart_item.dart';
import '../../viewmodels/cart_view_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/client_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartViewModel.instance,
      builder: (context, _) {
        final cart = CartViewModel.instance;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const ClientTabHeader(title: 'Mi carrito'),
                if (cart.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('¿Vaciar el carrito?'),
                          content: const Text(
                            'Se eliminarán todos los productos seleccionados.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Vaciar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) cart.clear();
                    },
                    child: const Text('Vaciar carrito'),
                  ),
                Expanded(
                  child: cart.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: _CartIntro(
                                    subtitle: '0 unidades para tu laboratorio',
                                  ),
                                ),
                                EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Tu carrito está vacío',
                                  description:
                                      'Encuentra los productos que tu '
                                      'laboratorio necesita y añádelos aquí.',
                                  action: OutlinedButton(
                                    onPressed: onBrowse,
                                    child: const Text('Ver todos'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                              child: _CartIntro(
                                subtitle:
                                    '${cart.lineCount} '
                                    '${cart.lineCount == 1 ? 'producto seleccionado' : 'productos seleccionados'}',
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  24,
                                ),
                                itemCount: cart.items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _CartItemCard(item: cart.items[index]);
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                if (cart.isNotEmpty) _CartSummary(onBrowse: onBrowse),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CartIntro extends StatelessWidget {
  const _CartIntro({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu próximo pedido',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: AppText.muted.copyWith(fontSize: 11.5)),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final product = item.product;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: ProductImage(
              product: product,
              height: 84,
              iconSize: 23,
              showBrand: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatBs(product.price)} por ${product.saleUnit}',
                  style: AppText.meta.copyWith(
                    fontSize: 11.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(product.presentation, style: AppText.meta),
                Text(
                  'Subtotal: ${formatBs(item.subtotal)}',
                  style: AppText.label,
                ),
                Text(
                  item.issue ??
                      'Disponible: ${product.quantityLabel(product.stock)}',
                  style: AppText.meta,
                ),
                if (item.priceChanged)
                  const Text(
                    'Precio actualizado desde el catálogo.',
                    style: AppText.meta,
                  ),
                if (item.needsAdjustment &&
                    item.availableInCatalog &&
                    product.stock > 0)
                  TextButton(
                    onPressed: () => CartViewModel.instance.adjust(item),
                    child: const Text('Ajustar al stock disponible'),
                  ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    QuantityStepper(
                      compact: true,
                      min: 0,
                      value: item.quantity,
                      max: product.stock,
                      onChanged: (value) =>
                          CartViewModel.instance.setQuantity(product, value),
                    ),
                    TextButton(
                      onPressed: () => CartViewModel.instance.remove(product),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.quantity >= product.stock && item.availableInCatalog)
                  const Text(
                    'Alcanzaste el stock máximo disponible.',
                    style: AppText.meta,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final cart = CartViewModel.instance;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${cart.totalUnits} unidades comerciales · ${cart.lineCount} productos',
            style: AppText.meta,
          ),
          if (cart.isRemote)
            const Text(
              'Importe estimado según el último catálogo recibido. Los productos no disponibles conservan su último precio conocido.',
              style: AppText.meta,
            ),
          if (!cart.catalogReady)
            const Text(
              'Esperando el catálogo vigente. Revisa tu conexión.',
              style: AppText.meta,
            ),
          if (cart.items.any((item) => item.needsAdjustment))
            const Text(
              'Corrige los productos no disponibles antes de continuar.',
              style: AppText.meta,
            ),
          Row(
            children: [
              const Text(
                'Total general',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  formatBs(cart.subtotal),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h1.copyWith(fontSize: 21),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !cart.canReview
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      );
                    },
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continuar pedido'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onBrowse,
              child: const Text('Seguir comprando'),
            ),
          ),
        ],
      ),
    );
  }
}
