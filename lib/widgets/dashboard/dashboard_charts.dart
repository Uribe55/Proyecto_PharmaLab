import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/dashboard_metrics.dart';
import '../../models/dashboard_models.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

Color statusColor(OrderStatus status) {
  return switch (status) {
    OrderStatus.pendiente => AppColors.pendingText,
    OrderStatus.aprobado => AppColors.approvedText,
    OrderStatus.enRuta => AppColors.primary,
    OrderStatus.entregado => AppColors.successText,
    OrderStatus.fallida || OrderStatus.cancelado => AppColors.danger,
    OrderStatus.reprogramado => AppColors.lavenderInk,
  };
}

Color statusBackground(OrderStatus status) {
  return switch (status) {
    OrderStatus.pendiente => AppColors.pendingBackground,
    OrderStatus.aprobado => AppColors.approvedBackground,
    OrderStatus.enRuta => AppColors.mint,
    OrderStatus.entregado => AppColors.successBackground,
    OrderStatus.fallida || OrderStatus.cancelado => AppColors.dangerBackground,
    OrderStatus.reprogramado => AppColors.lavender,
  };
}

const List<Color> dashboardChartPalette = [
  AppColors.primary,
  AppColors.ink,
  AppColors.approvedText,
  AppColors.pendingText,
  AppColors.lavenderInk,
  AppColors.successText,
  AppColors.peachInk,
  AppColors.danger,
];

const TextStyle _axisStyle = TextStyle(
  fontSize: 9,
  height: 1.1,
  color: AppColors.muted,
);

const TextStyle _tooltipStyle = TextStyle(
  fontSize: 10.5,
  height: 1.35,
  color: Colors.white,
  fontWeight: FontWeight.w500,
);

/// Distribución de pedidos por estado en barras horizontales compactas.
class StatusBarsChart extends StatelessWidget {
  const StatusBarsChart({super.key, required this.counts, this.onTap});

  final Map<OrderStatus, int> counts;
  final ValueChanged<OrderStatus>? onTap;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, value) => sum + value);
    if (total == 0) {
      return const DashboardEmptyText(
        icon: Icons.bar_chart_rounded,
        text: 'Aún no hay pedidos en el período seleccionado.',
      );
    }
    final maxCount = counts.values.fold(1, math.max);
    return Column(
      children: [
        for (var i = 0; i < OrderStatus.values.length; i++) ...[
          _StatusBarRow(
            status: OrderStatus.values[i],
            count: counts[OrderStatus.values[i]] ?? 0,
            total: total,
            maxCount: maxCount,
            onTap: onTap == null ? null : () => onTap!(OrderStatus.values[i]),
          ),
          if (i < OrderStatus.values.length - 1) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _StatusBarRow extends StatelessWidget {
  const _StatusBarRow({
    required this.status,
    required this.count,
    required this.total,
    required this.maxCount,
    this.onTap,
  });

  final OrderStatus status;
  final int count;
  final int total;
  final int maxCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : count / total * 100;
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 12, color: AppColors.background),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(height: 12, color: statusColor(status)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${percent.toStringAsFixed(0)} %',
              textAlign: TextAlign.right,
              style: _axisStyle,
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: AppColors.muted,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: row,
      ),
    );
  }
}

/// Evolución del valor de pedidos entregados.
class DeliveredValueTrendChart extends StatelessWidget {
  const DeliveredValueTrendChart({
    super.key,
    required this.points,
    this.height = 190,
  });

  final List<EvolutionPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.show_chart_rounded,
        text: 'Sin datos suficientes para graficar la evolución.',
      );
    }
    final maxValue = points.fold(0.0, (max, point) {
      return point.value > max ? point.value : max;
    });
    if (maxValue <= 0) {
      return const DashboardEmptyText(
        icon: Icons.show_chart_rounded,
        text: 'Aún no hay pedidos entregados en el período seleccionado.',
      );
    }

    final maxY = _niceMax(maxValue);
    final lastIndex = math.max(1, points.length - 1);
    final labelStep = math.max(1, (points.length / 5).ceil());
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastIndex.toDouble(),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${points[spot.x.round().clamp(0, points.length - 1)].label}'
                    '\n${formatBs(points[spot.x.round().clamp(0, points.length - 1)].value)}'
                    '\n${points[spot.x.round().clamp(0, points.length - 1)].orders} pedido(s)',
                    _tooltipStyle,
                  ),
              ],
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY / 3,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(formatCompactBs(value), style: _axisStyle),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= points.length ||
                      index % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 5,
                    child: Text(points[index].label, style: _axisStyle),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.22,
              color: AppColors.primary,
              barWidth: 2.4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: points.length <= 12,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.primary,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    AppColors.primary.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 180),
      ),
    );
  }
}

/// Comparación mensual del valor entregado.
class PeriodComparisonChart extends StatelessWidget {
  const PeriodComparisonChart({
    super.key,
    required this.points,
    this.height = 190,
  });

  final List<EvolutionPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.bar_chart_rounded,
        text: 'Sin meses suficientes para comparar.',
      );
    }
    final maxValue = points.fold(0.0, (max, point) {
      return point.value > max ? point.value : max;
    });
    if (maxValue <= 0) {
      return const DashboardEmptyText(
        icon: Icons.bar_chart_rounded,
        text: 'Sin valor entregado para comparar en los últimos meses.',
      );
    }
    final maxY = _niceMax(maxValue);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = points[groupIndex];
                return BarTooltipItem(
                  '${point.label}\n${formatBs(point.value)}\n'
                  '${point.orders} pedido(s)',
                  _tooltipStyle,
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: maxY / 3,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(formatCompactBs(value), style: _axisStyle),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 5,
                    child: Text(points[index].label, style: _axisStyle),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].value,
                    color: AppColors.primary,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 180),
      ),
    );
  }
}

/// Participación de categorías en el valor comercial entregado.
class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({
    super.key,
    required this.categories,
    this.height = 180,
  });

  final List<CategorySales> categories;
  final double height;

  @override
  Widget build(BuildContext context) {
    final withValue = categories
        .where((category) => category.amount > 0)
        .toList();
    if (withValue.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.donut_large_outlined,
        text: 'Sin importes por categoría en el período seleccionado.',
      );
    }
    final top = withValue.take(5).toList();
    final rest = withValue.skip(5).toList();
    if (rest.isNotEmpty) {
      final restAmount = rest.fold(0.0, (sum, item) => sum + item.amount);
      final restUnits = rest.fold(0, (sum, item) => sum + item.units);
      final restShare = rest.fold(0.0, (sum, item) => sum + item.amountShare);
      top.add(
        CategorySales(
          category: 'Otras',
          units: restUnits,
          amount: restAmount,
          share: 0,
          amountShare: restShare,
        ),
      );
    }
    final total = top.fold(0.0, (sum, item) => sum + item.amount);
    final slices = [
      for (var i = 0; i < top.length; i++)
        _DonutSlice(
          label: top[i].category,
          value: top[i].amount,
          color: dashboardChartPalette[i % dashboardChartPalette.length],
          percent: total == 0 ? 0 : top[i].amount / total * 100,
        ),
    ];

    return Column(
      children: [
        SizedBox(
          height: height,
          child: _DonutChart(
            slices: slices,
            centerCaption: 'Valor entregado',
            centerValue: formatCompactBs(total),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < slices.length; i++) ...[
          _LegendRow(
            color: slices[i].color,
            label: slices[i].label,
            value: '${slices[i].percent.toStringAsFixed(1)} %',
            detail: formatBs(top[i].amount),
          ),
          if (i < slices.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// Resultado de entregas: exitosas frente a fallidas.
class DeliveryOutcomeDonut extends StatelessWidget {
  const DeliveryOutcomeDonut({
    super.key,
    required this.delivery,
    this.height = 170,
  });

  final DeliveryMetrics delivery;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (delivery.delivered + delivery.failed == 0) {
      return const DashboardEmptyText(
        icon: Icons.donut_large_outlined,
        text: 'Aún no hay entregas finalizadas en el período.',
      );
    }
    final total = delivery.delivered + delivery.failed;
    final slices = [
      _DonutSlice(
        label: 'Exitosas',
        value: delivery.delivered.toDouble(),
        color: AppColors.successText,
        percent: delivery.delivered / total * 100,
      ),
      _DonutSlice(
        label: 'Fallidas',
        value: delivery.failed.toDouble(),
        color: AppColors.danger,
        percent: delivery.failed / total * 100,
      ),
    ];
    return Column(
      children: [
        SizedBox(
          height: height,
          child: _DonutChart(
            slices: slices,
            centerCaption: 'Tasa de éxito',
            centerValue: formatPercent(delivery.successRate),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < slices.length; i++) ...[
          _LegendRow(
            color: slices[i].color,
            label: slices[i].label,
            value: '${slices[i].percent.toStringAsFixed(1)} %',
            detail: '${slices[i].value.toInt()} entrega(s)',
          ),
          if (i < slices.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// Barras horizontales con los productos más entregados por unidades.
class ProductUnitsBars extends StatelessWidget {
  const ProductUnitsBars({super.key, required this.products});

  final List<ProductSales> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.shopping_bag_outlined,
        text: 'Aún no hay productos entregados en el período seleccionado.',
      );
    }
    final maxUnits = products.fold(1, (max, item) => math.max(max, item.units));
    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          _HorizontalBarRow(
            label: products[i].name,
            detail: '${products[i].units} u. · ${formatBs(products[i].amount)}',
            ratio: products[i].units / maxUnits,
            color: i == 0 ? AppColors.primary : AppColors.approvedText,
            caption: products[i].category,
          ),
          if (i < products.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Productos entregados ordenados por importe histórico.
class ProductAmountBars extends StatelessWidget {
  const ProductAmountBars({super.key, required this.products});

  final List<ProductSales> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.payments_outlined,
        text: 'Aún no hay importes de productos entregados en el período.',
      );
    }
    final maxAmount = products.fold(
      0.0,
      (max, item) => math.max(max, item.amount),
    );
    if (maxAmount <= 0) {
      return const DashboardEmptyText(
        icon: Icons.payments_outlined,
        text: 'Los pedidos entregados no registran importes por producto.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          _HorizontalBarRow(
            label: products[i].name,
            detail: '${formatBs(products[i].amount)} · ${products[i].units} u.',
            ratio: products[i].amount / maxAmount,
            color: i == 0 ? AppColors.primary : AppColors.successText,
            caption: products[i].category,
          ),
          if (i < products.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Productos con menor disponibilidad respecto a su umbral.
class CriticalStockBars extends StatelessWidget {
  const CriticalStockBars({super.key, required this.products});

  final List<DashboardProductStock> products;

  @override
  Widget build(BuildContext context) {
    final critical =
        products.where((product) => product.needsAttention).toList()
          ..sort((a, b) => a.thresholdRatio.compareTo(b.thresholdRatio));
    if (critical.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.check_circle_outline_rounded,
        text: 'Sin productos por debajo del umbral de stock.',
      );
    }
    final visible = critical.take(6).toList();
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _HorizontalBarRow(
            label: visible[i].name,
            detail: '${visible[i].usable} / ${visible[i].threshold} u.',
            ratio: visible[i].threshold <= 0
                ? (visible[i].usable <= 0 ? 0 : 1)
                : (visible[i].usable / visible[i].threshold).clamp(0.0, 1.5),
            color: visible[i].level == StockLevel.agotado
                ? AppColors.danger
                : AppColors.pendingText,
            caption: visible[i].category,
          ),
          if (i < visible.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Distribución de vencimientos en intervalos mutuamente excluyentes.
class ExpiryDistributionChart extends StatelessWidget {
  const ExpiryDistributionChart({
    super.key,
    required this.metrics,
    this.height = 180,
  });

  final InventoryMetrics metrics;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!metrics.hasLotData) {
      return const DashboardEmptyText(
        icon: Icons.event_busy_outlined,
        text: 'No hay lotes con vencimiento registrados.',
      );
    }
    final labels = ['Vencidos', '0–30 d', '31–60 d', '61–90 d'];
    final lots = [
      metrics.expiredLots,
      metrics.expiring30,
      metrics.expiring60,
      metrics.expiring90,
    ];
    final units = [
      metrics.expiredUnits,
      metrics.expiring30Units,
      metrics.expiring60Units,
      metrics.expiring90Units,
    ];
    final maxValue = lots.fold(0, math.max);
    if (maxValue == 0) {
      return const DashboardEmptyText(
        icon: Icons.event_available_outlined,
        text: 'Ningún lote vence en los próximos 90 días.',
      );
    }
    final colors = [
      AppColors.danger,
      AppColors.pendingText,
      AppColors.approvedText,
      AppColors.primary,
    ];
    final maxY = math.max(1, (maxValue * 1.25).ceil()).toDouble();
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${labels[groupIndex]}\n${lots[groupIndex]} lote(s)'
                  '\n${units[groupIndex]} unidad(es)',
                  _tooltipStyle,
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(1, maxY / 3),
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: math.max(1, maxY / 3),
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text('${value.toInt()}', style: _axisStyle),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 5,
                    child: Text(labels[index], style: _axisStyle),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < labels.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: lots[i].toDouble(),
                    color: colors[i],
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 180),
      ),
    );
  }
}

/// Rendimiento por repartidor: entregas exitosas y fallidas agrupadas.
class DriverPerformanceChart extends StatelessWidget {
  const DriverPerformanceChart({
    super.key,
    required this.drivers,
    this.height = 200,
  });

  final List<DriverActivity> drivers;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = drivers
        .where((driver) => driver.delivered + driver.failed > 0)
        .take(6)
        .toList();
    if (visible.isEmpty) {
      return const DashboardEmptyText(
        icon: Icons.local_shipping_outlined,
        text:
            'Sin entregas finalizadas por repartidor. No se calcula una tasa '
            'artificial.',
      );
    }
    final maxValue = visible.fold(
      1,
      (max, driver) => math.max(max, math.max(driver.delivered, driver.failed)),
    );
    final maxY = math.max(1, (maxValue * 1.25).ceil()).toDouble();

    final chart = BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipColor: (_) => AppColors.ink,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final driver = visible[groupIndex];
              final label = rodIndex == 0 ? 'Exitosas' : 'Fallidas';
              return BarTooltipItem(
                '${driver.name}\n$label: ${rod.toY.toInt()}',
                _tooltipStyle,
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(1, maxY / 3),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: math.max(1, maxY / 3),
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text('${value.toInt()}', style: _axisStyle),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= visible.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 5,
                  child: SizedBox(
                    width: 54,
                    child: Text(
                      _shortName(visible[index].name),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _axisStyle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < visible.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: visible[i].delivered.toDouble(),
                  color: AppColors.successText,
                  width: 9,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: visible[i].failed.toDouble(),
                  color: AppColors.danger,
                  width: 9,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 180),
    );

    return Column(
      children: [
        SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(280.0, visible.length * 70.0),
              child: chart,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DotLegend(color: AppColors.successText, label: 'Exitosas'),
            SizedBox(width: 16),
            _DotLegend(color: AppColors.danger, label: 'Fallidas'),
          ],
        ),
      ],
    );
  }

  String _shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts[1].substring(0, 1)}.';
  }
}

/// Evolución del tiempo promedio de entrega.
class DeliveryTimeTrendChart extends StatelessWidget {
  const DeliveryTimeTrendChart({
    super.key,
    required this.points,
    this.height = 180,
  });

  final List<DeliveryTimePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final valid = points.where((point) => point.minutes != null).toList();
    if (valid.length < 2) {
      return const DashboardEmptyText(
        icon: Icons.timer_outlined,
        text:
            'Se necesitan al menos dos intervalos con fechas válidas para '
            'graficar el tiempo de entrega.',
      );
    }
    final maxValue = valid.fold(
      1.0,
      (max, point) => math.max(max, point.minutes ?? 0),
    );
    final maxY = _niceMax(maxValue);
    final labelStep = math.max(1, (points.length / 4).ceil());
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, points.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  if (points[spot.x.round().clamp(0, points.length - 1)]
                          .minutes !=
                      null)
                    LineTooltipItem(
                      '${points[spot.x.round().clamp(0, points.length - 1)].label}'
                      '\n${formatAverageTime(points[spot.x.round().clamp(0, points.length - 1)].minutes)}'
                      '\n${points[spot.x.round().clamp(0, points.length - 1)].samples} muestra(s)',
                      _tooltipStyle,
                    ),
              ],
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: maxY / 3,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(formatAverageTime(value), style: _axisStyle),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= points.length ||
                      index % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 5,
                    child: Text(points[index].label, style: _axisStyle),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  if (points[i].minutes != null)
                    FlSpot(i.toDouble(), points[i].minutes!),
              ],
              isCurved: true,
              curveSmoothness: 0.2,
              color: AppColors.approvedText,
              barWidth: 2.4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.approvedText.withValues(alpha: 0.18),
                    AppColors.approvedText.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 180),
      ),
    );
  }
}

class _DonutSlice {
  const _DonutSlice({
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
  });

  final String label;
  final double value;
  final Color color;
  final double percent;
}

class _DonutChart extends StatefulWidget {
  const _DonutChart({
    required this.slices,
    required this.centerCaption,
    required this.centerValue,
  });

  final List<_DonutSlice> slices;
  final String centerCaption;
  final String centerValue;

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final selected = _touched >= 0 && _touched < widget.slices.length
        ? widget.slices[_touched]
        : null;
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 42,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (!event.isInterestedForInteractions ||
                    response?.touchedSection == null) {
                  if (_touched != -1) setState(() => _touched = -1);
                  return;
                }
                setState(
                  () =>
                      _touched = response!.touchedSection!.touchedSectionIndex,
                );
              },
            ),
            sections: [
              for (var i = 0; i < widget.slices.length; i++)
                PieChartSectionData(
                  value: widget.slices[i].value,
                  color: widget.slices[i].color,
                  radius: _touched == i ? 32 : 27,
                  showTitle: widget.slices[i].percent >= 7,
                  title: '${widget.slices[i].percent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          duration: const Duration(milliseconds: 180),
        ),
        IgnorePointer(
          child: SizedBox(
            width: 108,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected?.label ?? widget.centerCaption,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(fontSize: 9.5),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    selected == null
                        ? widget.centerValue
                        : '${selected.percent.toStringAsFixed(1)} %',
                    maxLines: 1,
                    style: AppText.h3.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            detail,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _axisStyle,
          ),
        ),
      ],
    );
  }
}

class _DotLegend extends StatelessWidget {
  const _DotLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppText.meta.copyWith(fontSize: 9.5)),
      ],
    );
  }
}

class _HorizontalBarRow extends StatelessWidget {
  const _HorizontalBarRow({
    required this.label,
    required this.detail,
    required this.ratio,
    required this.color,
    this.caption,
  });

  final String label;
  final String detail;
  final double ratio;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              detail,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 1),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.meta.copyWith(fontSize: 9),
          ),
        ],
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 8, color: AppColors.background),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(height: 8, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardEmptyText extends StatelessWidget {
  const DashboardEmptyText({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.info_outline_rounded,
            size: 18,
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.muted.copyWith(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

double _niceMax(double value) {
  if (value <= 0) return 1;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
  final normalized = value / magnitude;
  final nice = normalized <= 1
      ? 1.0
      : normalized <= 2
      ? 2.0
      : normalized <= 5
      ? 5.0
      : 10.0;
  return nice * magnitude;
}
