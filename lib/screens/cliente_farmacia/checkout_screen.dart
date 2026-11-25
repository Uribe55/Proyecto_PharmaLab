import 'package:flutter/material.dart';

import '../../models/cart_item.dart';
import '../../viewmodels/cart_view_model.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/client_header.dart';
import 'order_tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.cart});

  final CartViewModel? cart;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  CartViewModel get _cart => widget.cart ?? CartViewModel.instance;
  final _notesController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _editAddress() async {
    final controller = TextEditingController(
      text: PharmaService.instance.pharmacy.address,
    );

    final newAddress = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dirección de entrega'),
        content: AppTextField(
          label: 'Dirección',
          hint: 'Calle, número y ciudad',
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (!mounted || newAddress == null || newAddress.isEmpty) return;

    PharmaService.instance.updateAddress(newAddress);
    setState(() {});
  }

  Future<void> _confirmOrder() async {
    final cart = _cart;
    if (!cart.canConfirm) return;

    // RF-07: el estado de cuenta se valida también en el ViewModel/servicio.
    if (PharmaService.instance.currentUser?.tieneDeudaVencida == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes confirmar el pedido mientras tengas una deuda '
            'vencida.',
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (!cart.canConfirm) {
      setState(() => _loading = false);
      return;
    }

    try {
      final order = cart.confirmDemoOrder(notes: _notesController.text);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OrderTrackingScreen(order: order, showConfirmation: true),
        ),
      );
    } on StockUnavailableException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Stock insuficiente'),
          content: Text(
            '${error.productName} solo tiene ${error.available} unidades '
            'disponibles. Ajusta la cantidad del carrito antes de confirmar.',
            style: AppText.muted,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo confirmar el pedido. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _cart,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final cart = _cart;
    final pharmacy = PharmaService.instance.pharmacy;
    final hasDebt =
        PharmaService.instance.currentUser?.tieneDeudaVencida == true;

    return Scaffold(
      appBar: ClientPageAppBar(
        title: cart.isRemote ? 'Revisar carrito' : 'Confirmar pedido',
      ),
      body: cart.isEmpty
          ? const Center(
              child: Text('Tu carrito está vacío.', style: AppText.muted),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                if (cart.isRemote)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Tu carrito está listo. La confirmación de pedidos estará disponible próximamente.',
                      style: AppText.label,
                    ),
                  ),
                if (!cart.canReview)
                  const Text(
                    'Revisa la disponibilidad del catálogo y ajusta el carrito antes de continuar.',
                    style: AppText.label,
                  ),
                _CheckoutCard(
                  title: 'Resumen de compra',
                  trailing:
                      '${cart.lineCount} '
                      '${cart.lineCount == 1 ? 'producto' : 'productos'} · '
                      '${cart.totalUnits} unidades',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < cart.items.length;
                        index++
                      ) ...[
                        if (index > 0) const Divider(height: 20),
                        _ItemLine(item: cart.items[index]),
                      ],
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total del pedido',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              formatBs(cart.subtotal),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.h3.copyWith(fontSize: 17),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CheckoutCard(
                  title: 'Datos de entrega',
                  trailingAction: TextButton(
                    onPressed: _editAddress,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _RoundIcon(icon: Icons.location_on_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacy.commercialName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              pharmacy.address,
                              style: AppText.muted.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CheckoutCard(
                  title: 'Contacto',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _RoundIcon(icon: Icons.person_outline_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacy.responsible,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              pharmacy.phone,
                              style: AppText.muted.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CheckoutCard(
                  title: 'Estado de cuenta',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoundIcon(
                        icon: hasDebt
                            ? Icons.error_outline_rounded
                            : Icons.verified_user_outlined,
                        danger: hasDebt,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasDebt ? 'Deuda vencida' : 'Cuenta al día',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: hasDebt
                                    ? AppColors.danger
                                    : AppColors.successText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasDebt
                                  ? 'Regulariza tu deuda con el área '
                                        'comercial para poder confirmar '
                                        'nuevos pedidos.'
                                  : 'No tienes facturas vencidas. Puedes '
                                        'confirmar tu pedido.',
                              style: AppText.muted.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CheckoutCard(
                  title: 'Observaciones',
                  child: AppTextField(
                    label: 'Referencia o instrucciones',
                    hint: 'Ej. llamar antes de llegar',
                    controller: _notesController,
                    maxLines: 3,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: 14),
                if (hasDebt) ...[
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.block_rounded,
                          size: 17,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'No puedes confirmar el pedido mientras tengas '
                            'una deuda vencida. Comunícate con soporte para '
                            'regularizar tu estado de cuenta.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 17,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          cart.isRemote
                              ? 'Resumen previo: no se genera un pedido ni se modifica el inventario.'
                              : 'Al confirmar, el stock se descuenta automáticamente y se genera un número único de pedido.',
                          style: AppText.meta.copyWith(height: 1.4),
                        ),
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
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total', style: AppText.meta),
                  const SizedBox(height: 2),
                  Text(
                    formatBs(cart.subtotal),
                    style: AppText.h3.copyWith(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      !cart.canConfirm ||
                          _loading ||
                          hasDebt ||
                          PharmaService.instance.usesFirebase
                      ? null
                      : _confirmOrder,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                hasDebt
                                    ? 'Deuda vencida'
                                    : 'Confirmar pedido',
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                hasDebt
                                    ? Icons.lock_outline_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
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

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.title,
    required this.child,
    this.trailing,
    this.trailingAction,
  });

  final String title;
  final Widget child;
  final String? trailing;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h3,
                ),
              ),
              if (trailing != null)
                Flexible(
                  flex: 2,
                  child: Text(
                    trailing!,
                    textAlign: TextAlign.right,
                    style: AppText.meta.copyWith(fontSize: 10.5),
                  ),
                ),
              ?trailingAction,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.product.quantityLabel(item.quantity)} × ${formatBs(item.product.price)}',
                style: AppText.meta.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatBs(item.subtotal),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: danger ? AppColors.dangerBackground : AppColors.mint,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 18,
        color: danger ? AppColors.danger : AppColors.primary,
      ),
    );
  }
}
