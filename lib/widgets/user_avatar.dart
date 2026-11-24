import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/pharma_service.dart';
import '../theme/app_theme.dart';
import 'account_navigation.dart';

/// Avatar con las iniciales del usuario en sesión.
///
/// Se puede pasar [user] para mostrarlo en listados de administración.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.size = 38,
    this.showBorder = true,
    this.user,
  });

  final double size;
  final bool showBorder;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final current = user ?? PharmaService.instance.currentUser;
        final initials =
            current?.initials ?? PharmaService.instance.pharmacy.initials;

        final avatar = Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(color: AppColors.surface, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.33,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.primary,
            ),
          ),
        );
        return user == null ? AccountAvatarButton(child: avatar) : avatar;
      },
    );
  }
}
