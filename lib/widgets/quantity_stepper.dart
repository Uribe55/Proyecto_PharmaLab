import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.compact = false,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 26.0 : 32.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          size: size,
          icon: Icons.remove_rounded,
          enabled: value > 1,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: compact ? 26 : 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12 : 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        _StepButton(
          size: size,
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.size,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.surface : AppColors.background,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: enabled ? AppColors.ink : AppColors.border,
          ),
        ),
      ),
    );
  }
}
