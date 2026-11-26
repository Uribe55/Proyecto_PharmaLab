import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/widgets/admin_scroll_layout.dart';

Finder get verticalScroll => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
      'cabeceras ligadas a posición, un viewport y última fila: $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        final search = TextEditingController(text: 'selección conservada');
        addTearDown(controller.dispose);
        addTearDown(search.dispose);
        const headerKey = ValueKey('cabecera');
        const filtersKey = ValueKey('filtros');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: const SizedBox(
                height: 80,
                child: Text('Navegación'),
              ),
              body: AdminScrollLayout(
                header: const SizedBox(
                  key: headerKey,
                  height: 160,
                  child: Text('Administrador'),
                ),
                body: AdminScrollLayout(
                  header: const SizedBox(height: 60, child: Text('Pestañas')),
                  body: AdminScrollList(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    headerChildren: [
                      SizedBox(
                        key: filtersKey,
                        height: 100,
                        child: TextField(controller: search),
                      ),
                    ],
                    children: List.generate(
                      60,
                      (i) => SizedBox(height: 70, child: Text('Empleado $i')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(verticalScroll, findsOneWidget);
        final initialTop = tester.getTopLeft(find.byKey(headerKey)).dy;
        controller.jumpTo(12);
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(headerKey)).dy,
          closeTo(initialTop - 12, .1),
        );
        // Una pausa no dispara animaciones que terminen de ocultar la cabecera.
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.getTopLeft(find.byKey(headerKey)).dy,
          closeTo(initialTop - 12, .1),
        );
        controller.jumpTo(1000);
        await tester.pump();
        for (final delta in [40.0, -30.0, 20.0, -10.0]) {
          await tester.drag(verticalScroll, Offset(0, delta));
          await tester.pumpAndSettle();
          expect(find.byKey(headerKey).hitTestable(), findsNothing);
          expect(find.byKey(filtersKey).hitTestable(), findsNothing);
        }
        await tester.fling(verticalScroll, const Offset(0, -600), 1800);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Empleado 59'),
          400,
          scrollable: verticalScroll,
        );
        await tester.ensureVisible(find.text('Empleado 59'));
        await tester.pumpAndSettle();
        expect(find.text('Empleado 59').hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text('Empleado 59')).dy,
          lessThanOrEqualTo(size.height - 80),
        );
        controller.jumpTo(30);
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(headerKey)).dy,
          closeTo(initialTop - 30, .1),
        );
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(headerKey)).dy, initialTop);
        expect(search.text, 'selección conservada');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final count in [0, 1]) {
    testWidgets(
      'lista corta de $count elementos conserva filtros horizontales',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminScrollList(
                padding: const EdgeInsets.all(16),
                headerChildren: [
                  SizedBox(
                    height: 48,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          12,
                          (i) =>
                              SizedBox(width: 100, child: Text('Categoría $i')),
                        ),
                      ),
                    ),
                  ),
                ],
                children: List.generate(count, (i) => Text('Fila $i')),
              ),
            ),
          ),
        );
        final position = tester.state<ScrollableState>(verticalScroll).position;
        final initial = position.pixels;
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(-350, 0),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, initial);
        expect(verticalScroll, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
