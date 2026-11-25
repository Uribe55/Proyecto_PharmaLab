import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_environment.dart';

import 'package:flutter/foundation.dart';

import '../models/dashboard_models.dart';
import '../models/order.dart';
import 'pharma_service.dart';

/// Repositorio del dashboard administrativo.
///
/// - Pedidos: escucha `pedidos` en Firestore y complementa con `entregas`.
/// - Una consulta vacía o denegada nunca se sustituye por pedidos demo.
/// - Inventario: lee `productos`, `lotes_productos` y `categorias`. En modo
///   local usa el stock del catálogo de demostración, sin inventar lotes ni
///   fechas de vencimiento.
class DashboardRepository {
  DashboardRepository({
    PharmaService? service,
    this.lowStockThreshold = 10,
    this.maxOrders = 300,
    this.maxLots = 1000,
  }) : _service = service ?? PharmaService.instance;

  final PharmaService _service;
  final int lowStockThreshold;
  final int maxOrders;
  final int maxLots;

  FirebaseFirestore get _db => FirebaseEnvironment.firestore;

  static const int defaultLowStockThreshold = 10;

  // ------------------------------------------------------------- Pedidos

  /// Emite pedidos en tiempo real. El consumidor debe cancelar la suscripción.
  Stream<DashboardFeed> watchOrders() {
    final controller = StreamController<DashboardFeed>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ordersSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? deliveriesSub;
    VoidCallback? localListener;
    var remoteOrders = <DashboardOrder>[];
    var deliveries = <String, _DeliveryInfo>{};
    var ordersLoaded = false;
    String? ordersError;
    var ordersDenied = false;
    String? deliveriesWarning;
    var closed = false;

    void emit() {
      if (closed) return;
      if (!_service.usesFirebase) {
        controller.add(
          DashboardFeed(
            orders: _localOrders(),
            origin: DashboardOrigin.local,
            updatedAt: DateTime.now(),
          ),
        );
        return;
      }
      if (!ordersLoaded) return;

      if (ordersError != null) {
        controller.add(
          DashboardFeed(
            orders: const [],
            origin: ordersDenied
                ? DashboardOrigin.permissionDenied
                : DashboardOrigin.error,
            updatedAt: DateTime.now(),
            message: ordersError,
          ),
        );
        return;
      }

      final merged = [
        for (final order in remoteOrders)
          _mergeDelivery(
            order,
            deliveries[order.id] ?? deliveries[order.number],
          ),
      ];
      controller.add(
        DashboardFeed(
          orders: merged,
          origin: DashboardOrigin.firestore,
          updatedAt: DateTime.now(),
          message: _combineMessages(ordersError, deliveriesWarning),
        ),
      );
    }

    controller.onListen = () {
      _service.addListener(emit);
      localListener = emit;
      if (!_service.usesFirebase) {
        emit();
        return;
      }

      ordersSub = _db
          .collection('pedidos')
          .limit(maxOrders)
          .snapshots()
          .listen(
            (snapshot) {
              remoteOrders = [
                for (final doc in snapshot.docs)
                  _orderFromFirestore(doc.id, doc.data()),
              ];
              ordersLoaded = true;
              ordersError = null;
              ordersDenied = false;
              emit();
            },
            onError: (Object error) {
              ordersError = _friendlyError(error, 'los pedidos');
              ordersDenied = _isPermissionError(error);
              ordersLoaded = true;
              emit();
            },
          );

      // `entregas` complementa fechas y repartidor cuando el pedido no los
      // tiene. Si falla, no se bloquea el dashboard de pedidos.
      deliveriesSub = _db
          .collection('entregas')
          .limit(maxOrders)
          .snapshots()
          .listen(
            (snapshot) {
              final next = <String, _DeliveryInfo>{};
              for (final doc in snapshot.docs) {
                final info = _deliveryFromFirestore(doc.id, doc.data());
                if (info.orderId.isEmpty && info.orderNumber.isEmpty) continue;
                if (info.orderId.isNotEmpty) next[info.orderId] = info;
                if (info.orderNumber.isNotEmpty) {
                  next[info.orderNumber] = info;
                }
              }
              deliveries = next;
              deliveriesWarning = null;
              emit();
            },
            onError: (Object error) {
              deliveriesWarning = _friendlyError(error, 'las entregas');
              emit();
            },
          );
    };

    controller.onCancel = () async {
      closed = true;
      final listener = localListener;
      if (listener != null) _service.removeListener(listener);
      await ordersSub?.cancel();
      await deliveriesSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  List<DashboardOrder> _localOrders() {
    final categoryByProduct = {
      for (final product in _service.products)
        product.id: product.category.label,
    };
    final orders = _service.orders
        .map(
          (order) => DashboardOrder(
            id: order.number,
            number: order.number,
            createdAt: order.createdAt,
            status: order.status,
            pharmacyName: order.pharmacyName,
            deliveredAt: order.deliveredAt,
            driverId: order.driverId,
            driverName: order.driverName,
            failureReason: order.failureReason,
            address: order.address,
            contactName: order.contactName,
            contactPhone: order.contactPhone,
            notes: order.notes,
            rawStatus: order.status.name,
            cancelled: order.status == OrderStatus.cancelado,
            items: [
              for (final line in order.items)
                DashboardOrderLine(
                  productId: line.productId,
                  name: line.name,
                  quantity: line.quantity,
                  unitPrice: line.unitPrice,
                  brand: line.brand,
                  presentation: line.presentation,
                  category:
                      categoryByProduct[line.productId] ?? 'Sin categoría',
                ),
            ],
          ),
        )
        .toList();
    orders.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return orders;
  }

  DashboardOrder _orderFromFirestore(String id, Map<String, dynamic> data) {
    final rawStatus = _text(data, const [
      'estado',
      'status',
      'estado_pedido',
      'situacion',
    ]);
    final parsed = _parseStatus(rawStatus);
    final number = _text(data, const [
      'numero',
      'numero_pedido',
      'codigo',
      'codigo_pedido',
      'number',
    ]);
    final createdAt = _date(data, const [
      'creado_en',
      'fecha_pedido',
      'fecha_creacion',
      'created_at',
      'fecha',
      'timestamp',
    ]);
    final deliveredAt = _date(data, const [
      'fecha_entrega',
      'entregado_en',
      'delivered_at',
      'fecha_finalizacion',
      'updated_at',
      'actualizado_en',
    ]);
    final items = _linesFrom(data);
    final declaredTotal = _number(data, const [
      'total',
      'monto_total',
      'importe_total',
      'valor_total',
      'total_bs',
    ]);
    final driverRaw =
        data['repartidor_id'] ??
        data['repartidorId'] ??
        data['empleado_id'] ??
        data['driver_id'] ??
        data['repartidor'];
    final driverId = _refId(driverRaw);
    final driverNameText = _text(data, const [
      'repartidor_nombre',
      'nombre_repartidor',
      'driver_name',
      'nombre_empleado',
    ]);
    final driverName = driverNameText.isNotEmpty
        ? driverNameText
        : (driverId.isEmpty && driverRaw is String ? driverRaw.trim() : '');
    final pharmacyName = _text(data, const [
      'farmacia_nombre',
      'nombre_farmacia',
      'cliente_nombre',
      'pharmacy_name',
    ]);

    return DashboardOrder(
      id: id,
      number: number.isEmpty ? 'PED-$id' : number,
      createdAt: createdAt,
      status: parsed.status,
      cancelled: parsed.cancelled,
      rawStatus: rawStatus,
      deliveredAt: deliveredAt,
      driverId: driverId.isEmpty ? null : driverId,
      driverName: driverName.isEmpty ? null : driverName,
      failureReason: _text(data, const [
        'motivo_fallo',
        'motivo',
        'observacion_fallo',
        'failure_reason',
      ]),
      declaredTotal: declaredTotal,
      pharmacyName: pharmacyName.isEmpty ? 'Farmacia sin nombre' : pharmacyName,
      address: _text(data, const ['direccion_entrega', 'direccion', 'address']),
      contactName: _text(data, const [
        'contacto',
        'nombre_contacto',
        'responsable',
        'contact_name',
      ]),
      contactPhone: _text(data, const [
        'telefono_contacto',
        'contacto_telefono',
        'telefono',
        'celular',
        'contact_phone',
      ]),
      notes: _text(data, const ['observaciones', 'notas', 'notes']),
      items: items,
    );
  }

  List<DashboardOrderLine> _linesFrom(Map<String, dynamic> data) {
    final raw =
        data['items'] ??
        data['detalle'] ??
        data['detalles'] ??
        data['productos'] ??
        data['lineas'] ??
        data['lineas_pedido'];
    if (raw is! List) return const [];

    final lines = <DashboardOrderLine>[];
    for (final element in raw) {
      if (element is! Map) continue;
      final line = Map<String, dynamic>.from(element);
      final productRaw = line['producto'];
      final productMap = productRaw is Map
          ? Map<String, dynamic>.from(productRaw)
          : null;
      final productId = _refId(
        line['producto_id'] ??
            line['productoId'] ??
            line['id_producto'] ??
            productRaw,
      );
      final name =
          _text(line, const [
            'nombre',
            'producto_nombre',
            'nombre_producto',
            'descripcion',
          ]).isNotEmpty
          ? _text(line, const [
              'nombre',
              'producto_nombre',
              'nombre_producto',
              'descripcion',
            ])
          : (productMap == null
                ? 'Producto sin nombre'
                : _text(productMap, const [
                    'nombre',
                    'nombre_producto',
                    'descripcion',
                  ]));
      final quantity =
          _int(line, const [
            'cantidad',
            'unidades',
            'quantity',
            'cantidad_pedida',
          ]) ??
          0;
      final price =
          _number(line, const [
            'precio_unitario',
            'precio',
            'unit_price',
            'valor_unitario',
          ]) ??
          0;
      if (quantity <= 0) continue;

      final categoryRaw =
          line['categoria'] ?? line['categoria_id'] ?? productMap?['categoria'];
      final category = categoryRaw is Map
          ? _text(Map<String, dynamic>.from(categoryRaw), const [
              'nombre',
              'nombre_categoria',
              'descripcion',
              'id',
            ])
          : (categoryRaw is String ? categoryRaw : 'Sin categoría');

      lines.add(
        DashboardOrderLine(
          productId: productId.isEmpty ? name : productId,
          name: name.isEmpty ? 'Producto sin nombre' : name,
          quantity: quantity,
          unitPrice: price,
          category: category.isEmpty ? 'Sin categoría' : category,
          brand: _text(line, const ['marca', 'brand']),
          presentation: _text(line, const ['presentacion', 'presentation']),
        ),
      );
    }
    return lines;
  }

  _DeliveryInfo _deliveryFromFirestore(String id, Map<String, dynamic> data) {
    final rawStatus = _text(data, const ['estado', 'status', 'situacion']);
    final parsed = _parseStatus(rawStatus);
    return _DeliveryInfo(
      id: id,
      orderId: _refId(
        data['pedido_id'] ??
            data['pedidoId'] ??
            data['order_id'] ??
            data['pedido'],
      ),
      orderNumber: _text(data, const [
        'numero_pedido',
        'pedido_numero',
        'order_number',
      ]),
      status: rawStatus.isEmpty ? null : parsed.status,
      cancelled: parsed.cancelled,
      driverId: _refId(
        data['repartidor_id'] ??
            data['repartidorId'] ??
            data['empleado_id'] ??
            data['driver_id'] ??
            data['repartidor'],
      ),
      driverName: _text(data, const [
        'repartidor_nombre',
        'nombre_repartidor',
        'driver_name',
        'nombre_empleado',
      ]),
      deliveredAt: _date(data, const [
        'fecha_entrega',
        'entregado_en',
        'delivered_at',
        'fecha_fin',
        'fecha_finalizacion',
      ]),
      failureReason: _text(data, const [
        'motivo_fallo',
        'motivo',
        'observacion',
        'failure_reason',
      ]),
    );
  }

  DashboardOrder _mergeDelivery(DashboardOrder order, _DeliveryInfo? delivery) {
    if (delivery == null) return order;
    var status = order.status;
    var cancelled = order.cancelled;
    if (delivery.cancelled && !order.isDelivered) {
      cancelled = true;
    } else if (delivery.status != null) {
      final deliveryFinal =
          delivery.status == OrderStatus.entregado ||
          delivery.status == OrderStatus.fallida;
      if (deliveryFinal || order.isPending) {
        status = delivery.status!;
      }
    }
    return order.copyWith(
      status: status,
      cancelled: cancelled,
      deliveredAt: delivery.deliveredAt,
      driverId: delivery.driverId,
      driverName: delivery.driverName,
      failureReason: delivery.failureReason,
    );
  }

  // ---------------------------------------------------------- Inventario

  /// Carga el inventario. En Firebase, el stock se calcula exclusivamente a
  /// partir de `lotes_productos`; nunca se usa un stock duplicado en
  /// `productos`.
  Future<DashboardInventory> loadInventory() async {
    if (!_service.usesFirebase) return _localInventory();

    try {
      final categoriesRead = await _readCollection('categorias', 200);
      final productsRead = await _readCollection('productos', 500);
      final lotsRead = await _readCollection('lotes_productos', maxLots);

      if (lotsRead.error != null) {
        return _unavailableInventory(
          _friendlyError(lotsRead.error!, 'el inventario de lotes'),
          permissionDenied: _isPermissionError(lotsRead.error!),
        );
      }

      final categoryNames = <String, String>{};
      for (final doc in categoriesRead.docs) {
        final name = _text(doc.data(), const [
          'nombre',
          'nombre_categoria',
          'descripcion',
          'categoria',
        ]);
        if (name.isNotEmpty) categoryNames[doc.id] = name;
      }

      final products = <DashboardProduct>[];
      for (final doc in productsRead.docs) {
        final data = doc.data();
        final name = _text(data, const [
          'nombre',
          'nombre_producto',
          'descripcion',
          'producto',
        ]);
        final category = _categoryName(
          data['categoria'] ?? data['categoria_id'] ?? data['categoriaId'],
          categoryNames,
        );
        products.add(
          DashboardProduct(
            id: doc.id,
            name: name.isEmpty ? 'Producto $doc.id' : name,
            category: category,
            requiresExpiration:
                _bool(data, const [
                  'requiere_vencimiento',
                  'requiereVencimiento',
                  'requiere_fecha_vencimiento',
                ]) ??
                true,
            lowStockThreshold: _int(data, const [
              'stock_minimo',
              'umbral_stock',
              'stock_bajo',
              'minimo_stock',
            ]),
            price:
                _number(data, const ['precio', 'precio_venta', 'price']) ?? 0,
          ),
        );
      }

      final productsById = {
        for (final product in products) product.id: product,
      };
      final productsByName = {
        for (final product in products) product.name.toLowerCase(): product,
      };
      final lots = <DashboardLot>[];
      for (final doc in lotsRead.docs) {
        final data = doc.data();
        final productRaw =
            data['producto'] ?? data['producto_id'] ?? data['productoId'];
        final productMap = productRaw is Map
            ? Map<String, dynamic>.from(productRaw)
            : null;
        var productId = _refId(productRaw);
        final productName =
            _text(data, const [
              'producto_nombre',
              'nombre_producto',
              'nombre',
            ]).isNotEmpty
            ? _text(data, const [
                'producto_nombre',
                'nombre_producto',
                'nombre',
              ])
            : (productMap == null
                  ? ''
                  : _text(productMap, const [
                      'nombre',
                      'nombre_producto',
                      'descripcion',
                    ]));
        var product = productsById[productId];
        if (product == null && productName.isNotEmpty) {
          product = productsByName[productName.toLowerCase()];
          productId = product?.id ?? productId;
        }
        final quantity =
            _int(data, const [
              'cantidad',
              'stock',
              'cantidad_disponible',
              'unidades',
              'cantidad_actual',
              'cantidad_lote',
            ]) ??
            0;
        final requires =
            _bool(data, const [
              'requiere_vencimiento',
              'requiereVencimiento',
              'requiere_fecha_vencimiento',
            ]) ??
            product?.requiresExpiration ??
            true;
        lots.add(
          DashboardLot(
            id: doc.id,
            productId: productId,
            productName: product?.name.isNotEmpty == true
                ? product!.name
                : (productName.isEmpty
                      ? 'Producto sin identificar'
                      : productName),
            quantity: quantity,
            requiresExpiration: requires,
            category:
                product?.category ??
                _categoryName(
                  data['categoria'] ?? data['categoria_id'],
                  categoryNames,
                ),
            lotCode: _text(data, const [
              'codigo_lote',
              'lote',
              'numero_lote',
              'codigo',
            ]),
            expiresAt: _date(data, const [
              'fecha_vencimiento',
              'vencimiento',
              'fecha_exp',
              'fecha_caducidad',
              'expires_at',
            ]),
            receivedAt: _date(data, const [
              'fecha_ingreso',
              'fecha_recepcion',
              'creado_en',
              'created_at',
            ]),
          ),
        );
      }

      final partialWarnings = <String>[
        if (productsRead.error != null)
          _friendlyError(productsRead.error!, 'el catálogo de productos'),
        if (categoriesRead.error != null)
          _friendlyError(categoriesRead.error!, 'las categorías'),
      ];

      return _buildInventoryFromLots(
        products: products,
        lots: lots,
        origin: InventoryOrigin.firestore,
        additionalNote: partialWarnings.isEmpty
            ? null
            : '${partialWarnings.join(' ')} El stock se calculó con los lotes '
                  'disponibles.',
      );
    } on FirebaseException catch (error) {
      return _unavailableInventory(
        _friendlyError(error, 'el inventario'),
        permissionDenied: _isPermissionError(error),
      );
    } catch (error) {
      debugPrint('Error al cargar inventario: ${error.runtimeType}');
      return _unavailableInventory(
        'No se pudo cargar el inventario. Revisa la conexión e inténtalo de '
        'nuevo.',
      );
    }
  }

  Future<
    ({List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Object? error})
  >
  _readCollection(String name, int limit) async {
    try {
      final snapshot = await _db.collection(name).limit(limit).get();
      return (docs: snapshot.docs, error: null);
    } catch (error) {
      debugPrint('No se pudo leer $name: ${error.runtimeType}');
      return (
        docs: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        error: error,
      );
    }
  }

  DashboardInventory _buildInventoryFromLots({
    required List<DashboardProduct> products,
    required List<DashboardLot> lots,
    required InventoryOrigin origin,
    String? additionalNote,
  }) {
    final now = DateTime.now();
    final lotsByProduct = <String, List<DashboardLot>>{};
    for (final lot in lots) {
      final key = lot.productId.isNotEmpty
          ? lot.productId
          : 'name:${lot.productName.toLowerCase()}';
      lotsByProduct.putIfAbsent(key, () => []).add(lot);
    }

    final stocks = <DashboardProductStock>[];
    var productsWithoutLots = 0;
    for (final product in products) {
      final productLots = lotsByProduct.remove(product.id);
      if (productLots == null || productLots.isEmpty) {
        productsWithoutLots++;
        continue;
      }
      stocks.add(_stockFor(product, productLots, now));
    }

    // Lotes cuyo producto ya no existe en `productos`: se muestran con el
    // nombre que trae el lote para no ocultar inventario real.
    for (final entry in lotsByProduct.entries) {
      final productLots = entry.value;
      if (productLots.isEmpty) continue;
      final first = productLots.first;
      final placeholder = DashboardProduct(
        id: entry.key,
        name: first.productName,
        category: first.category,
        requiresExpiration: first.requiresExpiration,
      );
      stocks.add(_stockFor(placeholder, productLots, now));
    }

    stocks.sort((a, b) {
      final byLevel = a.level.index.compareTo(b.level.index);
      if (byLevel != 0) return byLevel;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (lots.isEmpty) {
      final emptyNote = products.isEmpty
          ? 'Aún no hay productos ni lotes registrados.'
          : 'Hay $productsWithoutLots producto(s), pero ningún lote en '
                'lotes_productos. El stock se calcula exclusivamente desde los '
                'lotes.';
      return DashboardInventory(
        products: const [],
        lots: const [],
        origin: origin,
        hasLotData: false,
        productsWithoutLots: productsWithoutLots,
        lowStockThreshold: lowStockThreshold,
        note: additionalNote == null ? emptyNote : '$emptyNote $additionalNote',
      );
    }

    return DashboardInventory(
      products: stocks,
      lots: lots,
      origin: origin,
      hasLotData: true,
      productsWithoutLots: productsWithoutLots,
      lowStockThreshold: lowStockThreshold,
      note: additionalNote,
    );
  }

  DashboardProductStock _stockFor(
    DashboardProduct product,
    List<DashboardLot> lots,
    DateTime now,
  ) {
    var usable = 0;
    var expired = 0;
    DateTime? nextExpiration;
    for (final lot in lots) {
      if (lot.isExpiredAt(now)) {
        expired += lot.quantity;
        continue;
      }
      usable += lot.quantity;
      final date = lot.expiresAt;
      if (lot.requiresExpiration && date != null) {
        if (nextExpiration == null || date.isBefore(nextExpiration)) {
          nextExpiration = date;
        }
      }
    }
    final threshold = product.lowStockThreshold ?? lowStockThreshold;
    final level = usable <= 0
        ? StockLevel.agotado
        : (usable <= threshold ? StockLevel.bajo : StockLevel.normal);
    return DashboardProductStock(
      productId: product.id,
      name: product.name,
      category: product.category,
      usable: usable,
      expired: expired,
      threshold: threshold,
      level: level,
      lotCount: lots.length,
      nextExpiration: nextExpiration,
    );
  }

  DashboardInventory _localInventory() {
    final products =
        _service.products
            .map(
              (product) => DashboardProductStock(
                productId: product.id,
                name: product.name,
                category: product.category.label,
                usable: product.stock,
                expired: 0,
                threshold: lowStockThreshold,
                level: product.stock <= 0
                    ? StockLevel.agotado
                    : (product.stock <= lowStockThreshold
                          ? StockLevel.bajo
                          : StockLevel.normal),
                lotCount: 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byLevel = a.level.index.compareTo(b.level.index);
            if (byLevel != 0) return byLevel;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    return DashboardInventory(
      products: products,
      lots: const [],
      origin: InventoryOrigin.local,
      hasLotData: false,
      lowStockThreshold: lowStockThreshold,
      note:
          'Modo local: el stock proviene del catálogo de demostración. '
          'Los lotes y vencimientos se habilitan al usar lotes_productos en '
          'Firestore.',
    );
  }

  DashboardInventory _unavailableInventory(
    String message, {
    bool permissionDenied = false,
  }) {
    return DashboardInventory(
      products: const [],
      lots: const [],
      origin: permissionDenied
          ? InventoryOrigin.permissionDenied
          : InventoryOrigin.unavailable,
      error: message,
      lowStockThreshold: lowStockThreshold,
    );
  }

  // --------------------------------------------------------------- Ayudas

  String _categoryName(dynamic raw, Map<String, String> names) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final name = _text(map, const [
        'nombre',
        'nombre_categoria',
        'descripcion',
        'categoria',
        'id',
      ]);
      return name.isEmpty ? 'Sin categoría' : name;
    }
    if (raw is DocumentReference) {
      return names[raw.id] ?? raw.id;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return names[raw] ?? raw.trim();
    }
    return 'Sin categoría';
  }

  ({OrderStatus status, bool cancelled}) _parseStatus(String raw) {
    final value = _normalize(raw);
    if (value.isEmpty) {
      return (status: OrderStatus.pendiente, cancelled: false);
    }
    if (value.contains('cancel') || value.contains('anul')) {
      return (status: OrderStatus.pendiente, cancelled: true);
    }
    if (value.contains('entreg') ||
        value.contains('deliver') ||
        value.contains('complet')) {
      return (status: OrderStatus.entregado, cancelled: false);
    }
    if (value.contains('fall') ||
        value.contains('fail') ||
        value.contains('rechaz')) {
      return (status: OrderStatus.fallida, cancelled: false);
    }
    if (value.contains('ruta') ||
        value.contains('camino') ||
        value.contains('asign') ||
        value.contains('transit') ||
        value.contains('shipping')) {
      return (status: OrderStatus.enRuta, cancelled: false);
    }
    if (value.contains('aprob') ||
        value.contains('approv') ||
        value.contains('confirm')) {
      return (status: OrderStatus.aprobado, cancelled: false);
    }
    return (status: OrderStatus.pendiente, cancelled: false);
  }

  String _normalize(String value) {
    const accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const plain = 'aaaaaeeeeiiiiooooouuuunc';
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().trim().runes) {
      final character = String.fromCharCode(rune);
      final index = accents.indexOf(character);
      buffer.write(index == -1 ? character : plain[index]);
    }
    return buffer.toString();
  }

  String _text(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return '';
  }

  String _refId(dynamic value) {
    if (value is DocumentReference) return value.id;
    if (value is String) {
      final trimmed = value.trim();
      // Un lote puede guardar el nombre en lugar del id.
      if (trimmed.contains(' ') && !trimmed.contains('-')) {
        return '';
      }
      return trimmed;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _text(map, const ['id', 'codigo', 'documento_id']);
    }
    return '';
  }

  DateTime? _date(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final parsed = _dateValue(data[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _dateValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value < 100000000000 ? value * 1000 : value,
      );
    }
    if (value is num) {
      final millis = value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(
        millis < 100000000000 ? millis * 1000 : millis,
      );
    }
    return null;
  }

  double? _number(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final cleaned = value
            .replaceAll(RegExp(r'[^0-9,.\-]'), '')
            .replaceAll('.', '')
            .replaceAll(',', '.');
        final parsed = double.tryParse(cleaned);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int? _int(Map<String, dynamic> data, List<String> keys) {
    final value = _number(data, keys);
    return value?.round();
  }

  bool? _bool(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = _normalize(value);
        if (normalized == 'true' ||
            normalized == 'si' ||
            normalized == '1' ||
            normalized == 'activo') {
          return true;
        }
        if (normalized == 'false' ||
            normalized == 'no' ||
            normalized == '0' ||
            normalized == 'inactivo') {
          return false;
        }
      }
    }
    return null;
  }

  String? _combineMessages(String? first, String? second) {
    if (first == null || first.isEmpty) return second;
    if (second == null || second.isEmpty) return first;
    return '$first · $second';
  }

  bool _isPermissionError(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';

  String _friendlyError(Object error, String resource) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firestore denegó la lectura de $resource. Revisa las reglas de '
              'seguridad para el rol administrador.',
        'unavailable' || 'deadline-exceeded' =>
          'No se pudo consultar $resource. Revisa la conexión a Internet.',
        'not-found' => 'No se encontró la colección de $resource.',
        _ => 'No se pudo consultar $resource (${error.code}).',
      };
    }
    return 'No se pudo consultar $resource.';
  }
}

class _DeliveryInfo {
  const _DeliveryInfo({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.cancelled,
    required this.driverId,
    required this.driverName,
    required this.deliveredAt,
    required this.failureReason,
  });

  final String id;
  final String orderId;
  final String orderNumber;
  final OrderStatus? status;
  final bool cancelled;
  final String driverId;
  final String driverName;
  final DateTime? deliveredAt;
  final String failureReason;
}
