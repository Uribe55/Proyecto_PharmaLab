import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../admin_scroll_layout.dart';
import 'dashboard_alerts.dart';

/// Utilidades de composición responsiva del panel administrativo.
class DashboardLayout {
  const DashboardLayout._();

  static const double maxContentWidth = 1180;
  static const double wideBreakpoint = 760;
  static const double desktopBreakpoint = 1000;

  static bool isWide(double width) => width >= wideBreakpoint;

  static bool isDesktop(double width) => width >= desktopBreakpoint;

  /// Ancho de cada tarjeta de indicadores para una grilla de [columns].
  static double gridItemWidth(
    double width,
    int columns, {
    double spacing = 10,
  }) {
    if (columns <= 1) return width;
    return (width - spacing * (columns - 1)) / columns;
  }

  static int kpiColumns(double width) {
    if (width >= 1040) return 6;
    if (width >= 760) return 3;
    if (width >= 520) return 3;
    return 2;
  }
}

/// Desplazamiento vertical único de cada pestaña, con ancho máximo legible en
/// escritorio. Evita anidar varias áreas de desplazamiento vertical.
class DashboardTabScroll extends StatelessWidget {
  const DashboardTabScroll({
    super.key,
    required this.scrollKey,
    required this.children,
    this.controller,
  });

  final Key scrollKey;
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = width >= DashboardLayout.desktopBreakpoint
            ? 28.0
            : 20.0;
        return AdminScrollList(
          scrollKey: scrollKey,
          controller: controller,
          padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 32),
          maxContentWidth: DashboardLayout.maxContentWidth,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ],
        );
      },
    );
  }
}

class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle({
    super.key,
    required this.title,
    this.caption,
    this.action,
  });

  final String title;
  final String? caption;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.h3),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    );
  }
}

class DashboardCardHeader extends StatelessWidget {
  const DashboardCardHeader({
    super.key,
    required this.title,
    this.caption,
    this.action,
  });

  final String title;
  final String? caption;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.h3.copyWith(fontSize: 14)),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption!, style: AppText.meta.copyWith(fontSize: 10)),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    );
  }
}

/// Tarjeta de gráfico con encabezado normalizado.
class DashboardChartCard extends StatelessWidget {
  const DashboardChartCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.action,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? caption;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DashboardSurface(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(title: title, caption: caption, action: action),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Grilla de indicadores que se adapta al ancho disponible.
class DashboardKpiGrid extends StatelessWidget {
  const DashboardKpiGrid({
    super.key,
    required this.children,
    this.columnsBuilder,
    this.spacing = 10,
  });

  final List<Widget> children;
  final int Function(double width)? columnsBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            columnsBuilder?.call(constraints.maxWidth) ??
            DashboardLayout.kpiColumns(constraints.maxWidth);
        final itemWidth = DashboardLayout.gridItemWidth(
          constraints.maxWidth,
          columns,
          spacing: spacing,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Dos columnas en escritorio y una columna en móvil.
class DashboardTwoColumns extends StatelessWidget {
  const DashboardTwoColumns({
    super.key,
    required this.first,
    required this.second,
    this.spacing = 12,
  });

  final Widget first;
  final Widget second;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!DashboardLayout.isWide(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: spacing),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class DashboardInfoNote extends StatelessWidget {
  const DashboardInfoNote({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon ?? Icons.info_outline_rounded,
          size: 15,
          color: AppColors.muted,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppText.meta.copyWith(fontSize: 10))),
      ],
    );
  }
}
