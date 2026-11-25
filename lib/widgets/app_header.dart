import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'user_avatar.dart';
import 'pharma_logo.dart';

/// Encabezado de las pantallas que viven dentro de la navegación inferior.
class AppTabHeader extends StatelessWidget {
  const AppTabHeader({
    super.key,
    required this.title,
    this.showAvatar = true,
    this.leading,
    this.actions,
    this.showLogo = false,
  });

  final String title;
  final bool showAvatar;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    if (showLogo) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PharmaLogo(height: 46),
                  ),
                ),
                const SizedBox(width: 12),
                if (showAvatar) const UserAvatar(),
                ...?actions,
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: AppText.h2),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: leading != null
                ? Align(alignment: Alignment.centerLeft, child: leading)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              width: 48,
              child: showAvatar
                  ? const Align(
                      alignment: Alignment.centerRight,
                      child: UserAvatar(size: 34),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Barra superior de las pantallas que se abren con Navigator.push.
class AppPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageAppBar({
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
            child: Center(child: UserAvatar(size: 34)),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
