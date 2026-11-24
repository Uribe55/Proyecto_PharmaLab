import 'package:flutter/material.dart';

/// Comparte el acceso a la pestaña de cuenta del rol activo.
class AccountNavigation extends InheritedWidget {
  const AccountNavigation({
    super.key,
    required this.onOpenAccount,
    required super.child,
  });

  final VoidCallback onOpenAccount;

  static VoidCallback? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AccountNavigation>()
      ?.onOpenAccount;

  @override
  bool updateShouldNotify(AccountNavigation oldWidget) =>
      onOpenAccount != oldWidget.onOpenAccount;
}

class AccountAvatarButton extends StatelessWidget {
  const AccountAvatarButton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onOpen = AccountNavigation.of(context);
    if (onOpen == null) return child;
    return Tooltip(
      message: 'Mi cuenta',
      child: Semantics(
        button: true,
        label: 'Abrir mi cuenta',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
