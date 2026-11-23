import 'package:flutter/material.dart';

import '../../models/dashboard_models.dart';
import '../../theme/app_theme.dart';

/// Selector horizontal de períodos con soporte para rango personalizado.
class DashboardPeriodSelector extends StatelessWidget {
  const DashboardPeriodSelector({
    super.key,
    required this.value,
    required this.range,
    required this.onSelected,
    required this.onPickRange,
  });

  final DashboardPeriod value;
  final DateRange range;
  final ValueChanged<DashboardPeriod> onSelected;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final period in DashboardPeriod.values) ...[
                _PeriodChip(
                  label: period == DashboardPeriod.personalizado
                      ? (value == DashboardPeriod.personalizado
                            ? _shortRange(range)
                            : period.label)
                      : period.label,
                  selected: value == period,
                  onTap: () {
                    if (period == DashboardPeriod.personalizado) {
                      onPickRange();
                    } else {
                      onSelected(period);
                    }
                  },
                ),
                if (period != DashboardPeriod.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Período: ${_longRange(range)}',
          style: AppText.meta.copyWith(fontSize: 10.5),
        ),
      ],
    );
  }

  String _shortRange(DateRange range) {
    return '${_day(range.start)}–${_day(range.end)}';
  }

  String _longRange(DateRange range) {
    if (_sameDay(range.start, range.end)) {
      return '${_day(range.start)} de ${_month(range.start)} de '
          '${range.start.year}';
    }
    return '${_day(range.start)} ${_month(range.start)} '
        '${range.start.year} – ${_day(range.end)} ${_month(range.end)} '
        '${range.end.year}';
  }

  String _day(DateTime date) => date.day.toString().padLeft(2, '0');

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  String _month(DateTime date) => _months[date.month - 1];
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
