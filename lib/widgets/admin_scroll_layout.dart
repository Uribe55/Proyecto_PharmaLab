import 'package:flutter/material.dart';

/// Comparte las cabeceras con la lista descendiente sin crear otro viewport.
/// La hoja [AdminScrollList] las incorpora como slivers normales, en orden.
class AdminScrollLayout extends StatelessWidget {
  const AdminScrollLayout({
    super.key,
    required this.header,
    required this.body,
  });

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final parent = context
        .dependOnInheritedWidgetOfExactType<_AdminScrollHeaders>();
    return _AdminScrollHeaders(
      headers: [...?parent?.headers, header],
      child: body,
    );
  }
}

class _AdminScrollHeaders extends InheritedWidget {
  const _AdminScrollHeaders({required this.headers, required super.child});

  final List<Widget> headers;

  @override
  bool updateShouldNotify(_AdminScrollHeaders oldWidget) =>
      headers != oldWidget.headers;
}

/// Un único scroll vertical para cabeceras, filtros y contenido administrativo.
/// No hay animaciones de altura ni cabeceras flotantes al invertir el gesto.
class AdminScrollList extends StatelessWidget {
  const AdminScrollList({
    super.key,
    required this.padding,
    this.headerChildren = const [],
    required this.children,
    this.headerPrefix,
    this.scrollKey,
    this.controller,
    this.maxContentWidth,
  });

  final EdgeInsets padding;
  final List<Widget> headerChildren;
  final List<Widget> children;
  final Widget? headerPrefix;
  final Key? scrollKey;
  final ScrollController? controller;
  final double? maxContentWidth;

  Widget _constrain(Widget child) => maxContentWidth == null
      ? child
      : Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth!),
            child: SizedBox(width: double.infinity, child: child),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final headers = context
        .dependOnInheritedWidgetOfExactType<_AdminScrollHeaders>()
        ?.headers;
    return CustomScrollView(
      key: scrollKey,
      controller: controller,
      slivers: [
        for (final header in headers ?? const <Widget>[])
          SliverToBoxAdapter(child: header),
        if (headerPrefix != null) SliverToBoxAdapter(child: headerPrefix),
        SliverPadding(
          padding: padding.copyWith(bottom: 0),
          sliver: SliverList.list(
            children: [for (final child in headerChildren) _constrain(child)],
          ),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _constrain(children[index]),
              childCount: children.length,
            ),
          ),
        ),
      ],
    );
  }
}
