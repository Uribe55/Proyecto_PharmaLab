import 'package:flutter/material.dart';

import '../services/pharma_service.dart';
import '../theme/app_theme.dart';
import 'account_navigation.dart';

class ClientAvatar extends StatelessWidget {
  const ClientAvatar({super.key, this.size = 38, this.showBorder = true});

  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final initials = PharmaService.instance.pharmacy.initials;

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
        return AccountAvatarButton(child: avatar);
      },
    );
  }
}
