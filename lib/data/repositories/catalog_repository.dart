import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/catalog_category.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../utils/bolivia_time.dart';
import '../datasources/firestore_catalog_data_source.dart';

/// Transforma documentos Firestore en modelos usados por la aplicación.
class CatalogRepository {
  CatalogRepository({FirestoreCatalogDataSource? dataSource})
    : _source = dataSource;

  FirestoreCatalogDataSource? _source;
  FirestoreCatalogDataSource get source =>
      _source ??= FirestoreCatalogDataSource();

  Stream<List<CatalogCategory>> watchCategories() =>
      source.watchCategories().map((snapshot) {
        final categories = snapshot.docs.map((doc) {
          final name = _text(doc.data()['nombre']);
          return CatalogCategory(
            id: doc.id,
            name: name.isEmpty ? doc.id : name,
          );
        }).toList();
        categories.sort((a, b) => a.id.compareTo(b.id));
        return categories;
      });

  Stream<List<ProductBatch>> watchBatches() =>
      source.watchBatches().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          final rawDate = data['fecha_vencimiento'];
          return ProductBatch(
            id: doc.id,
            productId: _text(data['producto_id']),
            available: data['cantidad_disponible'] is int
                ? _integer(data['cantidad_disponible'])
                : 0,
            active:
                data['estado'] != false &&
                data['bloqueado'] != true &&
                data['comercializable'] != false,
            invalidExpiry: rawDate != null && rawDate is! Timestamp,
            expiresAt: rawDate is Timestamp
                ? BoliviaTime.fromInstant(rawDate.toDate())
                : null,
          );
        }).toList();
      });

  Stream<List<CatalogProductRecord>> watchProducts() =>
      source.watchActiveProducts().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return CatalogProductRecord(
            id: doc.id,
            name: _text(data['nombre']),
            code: _text(data['codigo']),
            brand: _text(data['marca']),
            description: _text(data['descripcion']),
            presentation: _text(data['presentacion']),
            categoryId: _text(data['categoria_id']),
            price: _double(data['precio']),
            requiresExpiry: data['requiere_vencimiento'] == true,
            concentration: _text(data['concentracion']),
            material: _text(data['material']),
            size: _text(data['talla']),
            featured: data['destacado'] == true,
            // En la consola existente el campo se llama unidadMedida.
            // Aceptamos tambien unidad_medida por compatibilidad.
            unitOfMeasure: _text(data['unidadMedida'] ?? data['unidad_medida']),
            unitsPerPackage: _integer(data['unidad_por_envase']),
            baseInventory: data['inventario_unidad'] == 'base',
            presentations: data['presentaciones_venta'] is List
                ? (data['presentaciones_venta'] as List)
                      .whereType<Map>()
                      .map((p) => Map<String, dynamic>.from(p))
                      .toList()
                : const [],
          );
        }).toList();
      });

  /// Arma el catálogo combinando precios, categorías y existencias de lotes.
  List<Product> assemble({
    required List<CatalogProductRecord> records,
    required List<CatalogCategory> categories,
    required List<ProductBatch> batches,
    required DateTime now,
  }) {
    final namesById = {for (final item in categories) item.id: item.name};
    final categoriesById = {for (final item in categories) item.id: item};
    final stockByProduct = <String, int>{};
    final expiryByProduct = {
      for (final item in records) item.id: item.requiresExpiry,
    };

    for (final batch in batches) {
      if (!batch.eligible(
        requiresExpiry: expiryByProduct[batch.productId] ?? true,
        today: now,
      )) {
        continue;
      }
      stockByProduct.update(
        batch.productId,
        (stock) => stock + batch.available,
        ifAbsent: () => batch.available,
      );
    }

    final result = <Product>[];
    for (final record in records) {
      final category = categoriesById[record.categoryId];
      final product = Product(
        id: record.id,
        name: record.name,
        brand: record.brand,
        presentation: record.presentation,
        category: category?.visualCategory ?? ProductCategory.insumosClinicos,
        categoryId: record.categoryId,
        categoryName: namesById[record.categoryId] ?? 'Sin categoría',
        price: record.price,
        stock: stockByProduct[record.id] ?? 0,
        description: record.description,
        isFeatured: record.featured,
        code: record.code,
        concentration: record.concentration,
        material: record.material,
        size: record.size,
        requiresExpiry: record.requiresExpiry,
        unitOfMeasure: record.unitOfMeasure,
        unitsPerPackage: record.unitsPerPackage,
      );
      if (!record.baseInventory) {
        result.add(product);
      } else {
        final seen = <String>{};
        for (final choice in record.presentations) {
          final id = choice['id'],
              factor = choice['unidades_base'],
              price = choice['precio'];
          if (id is! String ||
              !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
              !seen.add(id) ||
              choice['estado'] != true ||
              factor is! int ||
              factor < 1 ||
              factor > 10000 ||
              price is! num ||
              !price.isFinite ||
              price <= 0 ||
              choice['nombre'] is! String) {
            continue;
          }
          result.add(
            Product(
              id: product.id,
              name: product.name,
              brand: product.brand,
              presentation: choice['nombre'] as String,
              category: product.category,
              categoryId: product.categoryId,
              categoryName: product.categoryName,
              price: price.toDouble(),
              stock: product.stock ~/ factor,
              description: product.description,
              isFeatured: product.isFeatured,
              code: product.code,
              concentration: product.concentration,
              material: product.material,
              size: product.size,
              requiresExpiry: product.requiresExpiry,
              unitOfMeasure:
                  choice['unidad_medida'] as String? ??
                  choice['nombre'] as String,
              unitsPerPackage: product.unitsPerPackage,
              presentationId: id,
              inventoryFactor: factor,
              inventoryStock: product.stock,
            ),
          );
        }
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  static String _text(dynamic value) => value is String ? value.trim() : '';
  static int _integer(dynamic value) {
    if (value is! num) return 0;
    final number = value.toInt();
    return number < 0 ? 0 : number;
  }

  static double _double(dynamic value) => value is num ? value.toDouble() : 0.0;
}

class CatalogProductRecord {
  const CatalogProductRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.brand,
    required this.description,
    required this.presentation,
    required this.categoryId,
    required this.price,
    required this.requiresExpiry,
    required this.concentration,
    required this.material,
    required this.size,
    required this.featured,
    this.unitOfMeasure = '',
    this.unitsPerPackage = 0,
    this.baseInventory = false,
    this.presentations = const [],
  });

  final String id;
  final String name;
  final String code;
  final String brand;
  final String description;
  final String presentation;
  final String categoryId;
  final double price;
  final bool requiresExpiry;
  final String concentration;
  final String material;
  final String size;
  final bool featured;
  final String unitOfMeasure;
  final int unitsPerPackage;
  final bool baseInventory;
  final List<Map<String, dynamic>> presentations;
}
