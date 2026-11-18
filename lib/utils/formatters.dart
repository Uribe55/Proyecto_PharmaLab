import '../models/order.dart';

const List<String> _months = [
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

/// Formatea un importe con el estilo boliviano: Bs 1.250,00
String formatBs(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts.first;
  final decimals = parts.last;

  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    final remaining = integer.length - i;
    buffer.write(integer[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  return 'Bs $buffer,$decimals';
}

/// Ejemplo: 18 jun 2026 · 09:30
String formatOrderDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = _months[date.month - 1];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day $month ${date.year} · $hour:$minute';
}

/// Texto del resumen del pedido para compartir (RF-20).
String buildOrderSummary(PharmacyOrder order) {
  final buffer = StringBuffer()
    ..writeln('PharmaLab · Resumen de pedido')
    ..writeln('Pedido: ${order.number}')
    ..writeln('Fecha: ${formatOrderDate(order.createdAt)}')
    ..writeln('Estado: ${order.status.label}')
    ..writeln()
    ..writeln('Productos:');

  for (final item in order.items) {
    buffer.writeln(
      '• ${item.name} — ${item.quantity} x ${formatBs(item.unitPrice)} '
      '= ${formatBs(item.subtotal)}',
    );
  }

  buffer
    ..writeln()
    ..writeln('Total: ${formatBs(order.total)}')
    ..writeln()
    ..writeln('Entrega: ${order.pharmacyName}')
    ..writeln('Dirección: ${order.address}')
    ..writeln('Contacto: ${order.contactName} · ${order.contactPhone}');

  if (order.notes.trim().isNotEmpty) {
    buffer.writeln('Observaciones: ${order.notes.trim()}');
  }

  return buffer.toString().trimRight();
}
