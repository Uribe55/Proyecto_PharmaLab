part of '../pharma_service.dart';

/// Se lanza cuando se intenta confirmar un pedido sin stock suficiente (RF-09).
class StockUnavailableException implements Exception {
  const StockUnavailableException(this.productName, this.available);

  final String productName;
  final int available;

  @override
  String toString() =>
      'Stock insuficiente de $productName. Disponible: $available.';
}
