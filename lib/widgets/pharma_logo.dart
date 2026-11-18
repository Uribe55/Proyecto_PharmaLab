import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PharmaLogo extends StatelessWidget {
  const PharmaLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 34.0 : 38.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 9),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PharmaLab',
              style: TextStyle(
                fontSize: compact ? 18 : 20,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'CIENCIA QUE CONECTA',
              style: TextStyle(
                fontSize: compact ? 6.4 : 6.8,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.35,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
