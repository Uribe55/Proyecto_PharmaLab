import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/utils/bolivia_time.dart';

void main() {
  group('BoliviaTime', () {
    test('convierte un instante UTC a hora de pared de Bolivia (UTC-4)', () {
      final instant = DateTime.utc(2026, 6, 19, 2, 30);
      final bolivia = BoliviaTime.fromInstant(instant);
      expect(bolivia, DateTime(2026, 6, 18, 22, 30));
      expect(bolivia.isUtc, isFalse);
    });

    test('un pedido entregado a las 23:30 de Bolivia no salta al día siguiente', () {
      // 2026-06-19 03:30 UTC = 2026-06-18 23:30 en Bolivia.
      final delivered = BoliviaTime.fromInstant(DateTime.utc(2026, 6, 19, 3, 30));
      expect(delivered.day, 18);
      expect(delivered.hour, 23);
    });

    test('inicio y fin del día de pared', () {
      final date = DateTime(2026, 6, 18, 15);
      expect(BoliviaTime.startOfDay(date), DateTime(2026, 6, 18));
      expect(
        BoliviaTime.endOfDay(date),
        DateTime(2026, 6, 18, 23, 59, 59, 999),
      );
    });
  });
}
