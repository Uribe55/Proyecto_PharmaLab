/// Normalización de fechas a la hora local de Bolivia (UTC-4).
///
/// Firestore entrega los `Timestamp` en UTC. Para que los períodos del
/// dashboard (día, mes, trimestre) coincidan con el día real del negocio, las
/// fechas se convierten a un `DateTime` "de pared" con el desfase fijo de
/// Bolivia. No se usa la zona horaria del dispositivo porque puede estar
/// configurada en otra región.
class BoliviaTime {
  const BoliviaTime._();

  static const Duration offset = Duration(hours: -4);

  /// Convierte un instante (UTC o local) a la hora de pared de Bolivia.
  ///
  /// El valor devuelto es un `DateTime` local sin marca de zona, de modo que
  /// pueda compararse directamente con los rangos construidos con [now].
  static DateTime fromInstant(DateTime instant) {
    final utc = instant.toUtc();
    final bolivia = utc.add(offset);
    return DateTime(
      bolivia.year,
      bolivia.month,
      bolivia.day,
      bolivia.hour,
      bolivia.minute,
      bolivia.second,
      bolivia.millisecond,
      bolivia.microsecond,
    );
  }

  /// Hora de pared actual en Bolivia.
  static DateTime now() => fromInstant(DateTime.now());

  /// Inicio del día de pared que contiene [date].
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Fin del día de pared que contiene [date].
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
