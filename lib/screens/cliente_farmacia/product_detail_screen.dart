import 'package:flutter/material.dart';

import '../../models/product.dart';

import '../../viewmodels/cart_view_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/availability_chip.dart';
import '../../widgets/category_visuals.dart';
import '../../widgets/client_header.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    this.cart,
    this.onOpenCart,
  });

  final VoidCallback? onOpenCart;
  final Product product;
  final CartViewModel? cart;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  CartViewModel get _cart => widget.cart ?? CartViewModel.instance;
  int _quantity = 1;

  Product get _product =>
      _cart.currentProduct(widget.product) ?? widget.product;

  // La selección respeta las unidades comerciales disponibles fuera del carrito.
  int get _maxQuantity => _cart.remainingFor(_product);

  void _addToCart() {
    if (_cart.quantityFor(_product) > 0) {
      widget.onOpenCart?.call();
      return;
    }
    final quantity = _quantity > _maxQuantity ? _maxQuantity : _quantity;
    if (quantity <= 0) return;

    final added = _cart.add(_product, quantity: quantity);
    if (!mounted) return;

    if (!added) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No hay stock suficiente de ${_product.name}. '
              'Disponible: ${_product.quantityLabel(_product.stock)}.',
            ),
          ),
        );
      return;
    }

    setState(() => _quantity = 1);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$quantity × ${_product.name} se agregó al carrito.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _cart,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final maxQuantity = _maxQuantity;
    final remote = _cart.isRemote;
    final inCart = _cart.quantityFor(_product) > 0;
    final canAdd = maxQuantity > 0;
    final quantity = _quantity.clamp(1, maxQuantity > 0 ? maxQuantity : 1);
    final tint = categoryTint(_product.category);

    return Scaffold(
      appBar: const ClientPageAppBar(title: 'Detalle de producto'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          ProductImage(product: _product, height: 220, iconSize: 62),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryBackground(_product.category),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _product.displayCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: tint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AvailabilityChip(product: _product),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _product.brand.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 7),
          Text(_product.name, style: AppText.h1.copyWith(fontSize: 23)),
          const SizedBox(height: 6),
          Text(_product.presentation, style: AppText.muted),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  formatBs(_product.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h1.copyWith(fontSize: 25),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Stock: ${_product.quantityLabel(_product.stock)}',
                  textAlign: TextAlign.right,
                  style: AppText.meta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Precio por ${_product.saleUnit}', style: AppText.meta),
          const SizedBox(height: 18),
          Text(_product.description, style: AppText.body),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Categoría', value: _product.displayCategory),
                const Divider(),
                _InfoRow(label: 'Presentación', value: _product.presentation),
                const Divider(),
                _InfoRow(label: 'Unidad de venta', value: _product.saleUnit),
                const Divider(),
                if (_product.brand.isNotEmpty) ...[
                  _InfoRow(label: 'Laboratorio', value: _product.brand),
                  const Divider(),
                ],
                if (_product.concentration.isNotEmpty) ...[
                  _InfoRow(
                    label: 'Concentración',
                    value: _product.concentration,
                  ),
                  const Divider(),
                ],
                if (_product.material.isNotEmpty) ...[
                  _InfoRow(label: 'Material', value: _product.material),
                  const Divider(),
                ],
                if (_product.size.isNotEmpty) ...[
                  _InfoRow(label: 'Talla', value: _product.size),
                  const Divider(),
                ],
                const Divider(),
                _InfoRow(
                  label: 'Disponibilidad',
                  value: _product.isAvailable
                      ? _product.quantityLabel(_product.stock)
                      : 'Sin stock',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cantidad de ${_product.unitForQuantity(2)}',
                        style: AppText.label,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        maxQuantity > 0
                            ? 'Puedes seleccionar hasta $maxQuantity'
                            : 'Sin existencias disponibles',
                        style: AppText.meta,
                      ),
                    ],
                  ),
                ),
                QuantityStepper(
                  value: quantity,
                  max: maxQuantity > 0 ? maxQuantity : 1,
                  onChanged: maxQuantity > 0
                      ? (value) => setState(() => _quantity = value)
                      : (_) {},
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          remote ? 'Total estimado' : 'Total',
                          style: AppText.label,
                        ),
                        Text(
                          _product.quantityLabel(quantity),
                          style: AppText.meta,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatBs(_product.estimatedTotal(quantity)),
                    style: AppText.h2,
                  ),
                ],
              ),
              if (remote) ...[
                const SizedBox(height: 5),
                const Text(
                  'Cálculo informativo. No se genera un pedido ni se descuenta stock.',
                  style: AppText.meta,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: inCart
                    ? widget.onOpenCart
                    : canAdd
                    ? _addToCart
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    inCart
                        ? 'Ver carrito'
                        : canAdd
                        ? 'Añadir al carrito · '
                              '${formatBs(_product.estimatedTotal(quantity))}'
                        : 'Producto agotado',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 108, child: Text(label, style: AppText.meta)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
