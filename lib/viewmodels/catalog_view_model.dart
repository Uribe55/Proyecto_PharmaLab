import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/catalog_repository.dart';
import '../models/catalog_category.dart';
import '../models/product.dart';
import '../models/product_batch.dart';

/// ViewModel observable del catálogo. No accede directamente a Firestore.
class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel._();

  static final CatalogViewModel instance = CatalogViewModel._();

  CatalogRepository? _repository;
  StreamSubscription<List<CatalogProductRecord>>? _productsSubscription;
  StreamSubscription<List<CatalogCategory>>? _categoriesSubscription;
  StreamSubscription<List<ProductBatch>>? _batchesSubscription;

  List<CatalogProductRecord> _records = [];
  List<CatalogCategory> _categories = [];
  List<ProductBatch> _batches = [];
  List<Product> _products = [];
  bool _hasProducts = false;
  bool _hasCategories = false;
  bool _hasBatches = false;
  String? _error;
  bool _started = false;

  bool get loading =>
      _started &&
      !(_hasProducts && _hasCategories && _hasBatches) &&
      _error == null;
  String? get error => _error;
  bool get ready =>
      _started &&
      _hasProducts &&
      _hasCategories &&
      _hasBatches &&
      _error == null;
  List<Product> get products => List.unmodifiable(_products);
  List<CatalogCategory> get categories => List.unmodifiable(_categories);
  List<Product> get featuredProducts {
    final featured = _products.where((item) => item.isFeatured).toList();
    return featured.isEmpty ? _products.take(4).toList() : featured;
  }

  void start() {
    if (_started) return;
    _started = true;
    _error = null;
    _hasProducts = false;
    _hasCategories = false;
    _hasBatches = false;
    notifyListeners();

    final repository = _repository ??= CatalogRepository();
    _productsSubscription = repository.watchProducts().listen((items) {
      _records = items;
      _hasProducts = true;
      _refresh();
    }, onError: _onError);
    _categoriesSubscription = repository.watchCategories().listen((items) {
      _categories = items;
      _hasCategories = true;
      _refresh();
    }, onError: _onError);
    _batchesSubscription = repository.watchBatches().listen((items) {
      _batches = items;
      _hasBatches = true;
      _refresh();
    }, onError: _onError);
  }

  void _onError(Object error, StackTrace stackTrace) {
    debugPrint('Catálogo Firestore: $error');
    _error = 'No se pudo cargar el catálogo. Comprueba tu conexión y las reglas de Firestore.';
    notifyListeners();
  }

  void _refresh() {
    _error = null;
    if (_hasProducts && _hasCategories && _hasBatches) {
      _products = _repository!.assemble(
        records: _records,
        categories: _categories,
        batches: _batches,
        now: DateTime.now(),
      );
    }
    notifyListeners();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    unawaited(_productsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_categoriesSubscription?.cancel() ?? Future<void>.value());
    unawaited(_batchesSubscription?.cancel() ?? Future<void>.value());
    _productsSubscription = null;
    _categoriesSubscription = null;
    _batchesSubscription = null;
    _products = [];
    _categories = [];
    _records = [];
    _batches = [];
    _hasProducts = false;
    _hasCategories = false;
    _hasBatches = false;
    _error = null;
    // No notificar mientras ClientShell/los widgets están en dispose.
  }
}
