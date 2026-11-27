import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.compact = false,
    this.min = 1,
    this.editable = false,
    this.onLimitExceeded,
  });
  final int value, max, min;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onLimitExceeded;
  final bool compact, editable;
  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final controller = TextEditingController(text: '${widget.value}');
  final focus = FocusNode();
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!focus.hasFocus && dirty) _commit();
  }

  @override
  void didUpdateWidget(covariant QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!focus.hasFocus) controller.text = '${widget.value}';
  }

  int _normalized() {
    if (widget.max < widget.min) return widget.value;
    final raw = int.tryParse(controller.text);
    if (raw == null && controller.text.isNotEmpty) {
      widget.onLimitExceeded?.call(widget.max);
      return widget.max;
    }
    final parsed = raw ?? widget.value;
    if (parsed > widget.max) widget.onLimitExceeded?.call(widget.max);
    return parsed.clamp(widget.min, widget.max);
  }

  void _commit() {
    final value = _normalized();
    dirty = false;
    controller.text = '$value';
    if (value != widget.value) widget.onChanged(value);
  }

  void _step(int delta) {
    final base = widget.editable && dirty ? _normalized() : widget.value;
    final value = (base + delta).clamp(
      widget.min,
      widget.max < widget.min ? widget.min : widget.max,
    );
    dirty = false;
    controller.text = '$value';
    focus.unfocus();
    if (widget.max >= widget.min && value != widget.value) {
      widget.onChanged(value);
    }
  }

  @override
  void dispose() {
    focus.removeListener(_focusChanged);
    focus.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 26.0 : 32.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          size: size,
          icon: Icons.remove_rounded,
          enabled: widget.value > widget.min && widget.max >= widget.min,
          onTap: () => _step(-1),
        ),
        SizedBox(
          width: widget.editable
              ? 52
              : widget.compact
              ? 26
              : 34,
          child: widget.editable
              ? TextField(
                  controller: controller,
                  focusNode: focus,
                  enabled: widget.max >= widget.min,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  scrollPadding: const EdgeInsets.all(32),
                  onTap: () => controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  ),
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) =>
                          RegExp(r'^\d*$').hasMatch(newValue.text)
                          ? newValue
                          : oldValue,
                    ),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  onChanged: (_) => dirty = true,
                  onSubmitted: (_) {
                    _commit();
                    focus.unfocus();
                  },
                  onTapOutside: (_) => focus.unfocus(),
                )
              : Text(
                  '${widget.value}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
        ),
        _StepButton(
          size: size,
          icon: Icons.add_rounded,
          enabled: widget.value < widget.max,
          onTap: () => _step(1),
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
