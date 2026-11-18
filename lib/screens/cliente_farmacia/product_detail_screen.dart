import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/availability_chip.dart';
import '../../widgets/category_visuals.dart';
import '../../widgets/client_header.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  Product get _product => widget.product;

  int get _maxQuantity => CartService.instance.remainingFor(_product);

  void _addToCart() {
    final quantity = _quantity > _maxQuantity ? _maxQuantity : _quantity;
    if (quantity <= 0) return;

    final added = CartService.instance.add(_product, quantity: quantity);
    if (!mounted) return;

    if (!added) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No hay stock suficiente de ${_product.name}. '
              'Disponible: ${_product.stock} unidades.',
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
  Widget build(BuildContext context) {
    final maxQuantity = _maxQuantity;
    final canAdd = maxQuantity > 0;
    final quantity = _quantity.clamp(1, maxQuantity > 0 ? maxQuantity : 1);
    final tint = categoryTint(_product.category);

    return Scaffold(
      appBar: const ClientPageAppBar(title: 'Detalle de producto'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          ProductImage(
            product: _product,
            height: 220,
            iconSize: 62,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: categoryBackground(_product.category),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _product.category.label,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              ),
              const Spacer(),
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
                  'Stock: ${_product.stock} unidades',
                  textAlign: TextAlign.right,
                  style: AppText.meta,
                ),
              ),
            ],
          ),
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
                _InfoRow(label: 'Categoría', value: _product.category.label),
                const Divider(),
                _InfoRow(label: 'Presentación', value: _product.presentation),
                const Divider(),
                _InfoRow(label: 'Laboratorio', value: _product.brand),
                const Divider(),
                _InfoRow(
                  label: 'Disponibilidad',
                  value: _product.isAvailable
                      ? '${_product.stock} unidades'
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cantidad', style: AppText.label),
                      SizedBox(height: 3),
                      Text(
                        'Según el stock disponible',
                        style: AppText.meta,
                      ),
                    ],
                  ),
                ),
                QuantityStepper(
                  value: quantity,
                  max: maxQuantity > 0 ? maxQuantity : 1,
                  onChanged: canAdd
                      ? (value) => setState(() => _quantity = value)
                      : (value) {},
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canAdd ? _addToCart : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  canAdd
                      ? 'Añadir al carrito · '
                          '${formatBs(_product.price * quantity)}'
                      : 'Producto agotado',
                ),
              ),
            ),
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
          SizedBox(
            width: 108,
            child: Text(label, style: AppText.meta),
          ),
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
