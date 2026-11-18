import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'client_avatar.dart';

/// Encabezado de las pantallas que viven dentro de la navegación inferior.
class ClientTabHeader extends StatelessWidget {
  const ClientTabHeader({
    super.key,
    required this.title,
    this.showAvatar = true,
    this.leading,
    this.actions,
  });

  final String title;
  final bool showAvatar;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: leading != null ? Align(
              alignment: Alignment.centerLeft,
              child: leading,
            ) : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          if (actions != null)
            ...actions!
          else
            SizedBox(
              width: 40,
              child: showAvatar
                  ? const Align(
                      alignment: Alignment.centerRight,
                      child: ClientAvatar(size: 34),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Barra superior de las pantallas que se abren con Navigator.push.
class ClientPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClientPageAppBar({
    super.key,
    required this.title,
    this.showAvatar = false,
    this.actions,
  });

  final String title;
  final bool showAvatar;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        if (actions != null)
          ...actions!
        else if (showAvatar)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: ClientAvatar(size: 34)),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
