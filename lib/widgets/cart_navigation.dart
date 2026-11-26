import 'package:flutter/material.dart';

/// Acceso a la pestaña existente, compartido también con rutas de catálogo.
class CartNavigation extends InheritedWidget {
  const CartNavigation({super.key, required this.open, required super.child});
  final VoidCallback open;
  static VoidCallback? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CartNavigation>()?.open;
  @override
  bool updateShouldNotify(CartNavigation oldWidget) => open != oldWidget.open;
}
