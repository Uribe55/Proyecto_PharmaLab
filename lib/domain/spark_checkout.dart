import '../data/repositories/remote_order_repository.dart';
import 'spark_approval.dart';

/// Contrato finito: un producto, un lote y cinco escrituras atómicas.
class SparkCheckout {
  static const schema = 'spark_single_v1';
  static const limitMessage =
      'Esta versión permite un producto y un único lote por pedido, hasta 1000 cajas. No se dividen compras ni se eliminan productos del carrito.';

  static Map<String, dynamic> item(Map<String, dynamic> request) {
    final items = request['items'];
    if (items is! List || items.length != 1 || items.single is! Map) {
      throw const RemoteOrderException(limitMessage, definitive: true);
    }
    final line = Map<String, dynamic>.from(items.single as Map);
    if (line['productId'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,100}$')
            .hasMatch(line['productId'] as String) ||
        line['quantity'] is! int ||
        (line['quantity'] as int) < 1 ||
        (line['quantity'] as int) > 1000 ||
        line['expectedPriceCents'] is! int ||
        (line['expectedPriceCents'] as int) <= 0) {
      throw const RemoteOrderException(
        'Revisa el producto y la cantidad de cajas (1 a 1000).',
        definitive: true,
      );
    }
    if (request['notes'] is! String ||
        (request['notes'] as String).length > 500 ||
        request['addressId'] is! String ||
        (request['addressId'] as String).isEmpty ||
        (request['addressId'] as String).contains('/') ||
        request['operationId'] is! String ||
        !RegExp(r'^[A-Za-z0-9]{20}$')
            .hasMatch(request['operationId'] as String)) {
      throw const RemoteOrderException(
        'Dirección, observaciones o ID de operación no válidos.',
        definitive: true,
      );
    }
    return line;
  }

  static Future<void> prepare(
    ApprovalTransaction tx, {
    required String uid,
    required String farmId,
    required String lotId,
    required Map<String, dynamic> request,
    required Object serverTimestamp,
    required DateTime now,
  }) async {
    final input = item(request);
    final id = request['operationId'] as String;
    final productId = input['productId'] as String;
    final quantity = input['quantity'] as int;
    if ([uid, farmId, lotId].any((s) => s.isEmpty || s.contains('/'))) {
      throw const RemoteOrderException(
        'Sesión o lote no válido.',
        definitive: true,
      );
    }
    final orderPath = 'pedidos/$id';
    final operationPath = 'usuarios/$uid/operaciones_pedido/$id';
    final operation = await tx.read(operationPath);
    final existing = await tx.read(orderPath);
    if (operation != null || existing != null) {
      final line = operation?['linea'] as Map?;
      if (operation?['pedido_id'] == id &&
          operation?['id_cliente'] == farmId &&
          operation?['id_direccion'] == request['addressId'] &&
          operation?['observaciones'] == request['notes'] &&
          line?['id_producto'] == productId &&
          line?['cantidad'] == quantity &&
          line?['precio_unitario'] is num &&
          ((line!['precio_unitario'] as num) * 100).round() ==
              input['expectedPriceCents'] &&
          existing?['id_operacion'] == id &&
          existing?['usuario_id'] == uid) {
        return; // Ya confirmado: ningún segundo descuento, incluso tras reiniciar.
      }
      throw const RemoteOrderException(
        'El ID ya pertenece a otra operación. No se reemplazó el pedido.',
        definitive: true,
      );
    }
    final user = await tx.read('usuarios/$uid');
    final farm = await tx.read('farmacia_cliente/$farmId');
    final address = await tx.read('direcciones/${request['addressId']}');
    final product = await tx.read('productos/$productId');
    final lot = await tx.read('lotes_productos/$lotId');
    if (user?['rol'] != 'cliente' ||
        user?['estado'] != true ||
        farm?['usuario_id'] != uid ||
        farm?['estado'] != true ||
        address?['id_cliente'] != farmId ||
        address?['estado'] != true) {
      throw const RemoteOrderException(
        'La sesión, farmacia o dirección no está autorizada.',
        definitive: true,
      );
    }
    final price = product?['precio'];
    if (product?['estado'] != true ||
        price is! num ||
        !price.isFinite ||
        price <= 0 ||
        price > 1000000) {
      throw const RemoteOrderException(
        'El producto no está disponible para la venta.',
        definitive: true,
      );
    }
    final cents = (price * 100).round();
    if (cents != input['expectedPriceCents']) {
      throw RemoteOrderException(
        'El precio cambió. Revisa el importe y confirma nuevamente.',
        definitive: true,
        prices: {productId: cents},
      );
    }
    final stock = lot?['cantidad_disponible'];
    final expiry = lot?['fecha_vencimiento'];
    if (lot?['producto_id'] != productId ||
        stock is! int ||
        stock < quantity ||
        (product?['requiere_vencimiento'] == true &&
            (expiry is! DateTime || !expiry.isAfter(now)))) {
      throw const RemoteOrderException(
        'El lote ya no tiene suficientes cajas vigentes. Actualiza el catálogo y reintenta.',
        definitive: true,
      );
    }
    final line = <String, dynamic>{
      'id_producto': productId,
      'id_lote': lotId,
      'cantidad': quantity,
      'precio_unitario': price,
      'subtotal': price * quantity,
    };
    tx.create(orderPath, {
      'schema_version': schema,
      'estado': 'pendiente',
      'fecha_pedido': serverTimestamp,
      'id_cliente': farmId,
      'id_direccion': request['addressId'],
      'total': line['subtotal'],
      'usuario_id': uid,
      'id_operacion': id,
      'numero_comercial': 'PED-$id',
      'linea': line,
      'observaciones': request['notes'],
    });
    tx.create('$orderPath/detalle_pedido/LINEA1', line);
    tx.create('$orderPath/historial_estado/CONFIRMACION', {
      'estado_anterior': null,
      'estado_nuevo': 'pendiente',
      'fecha_cambio': serverTimestamp,
      'id_usuario': uid,
    });
    tx.create(operationPath, {
      'pedido_id': id,
      'id_cliente': farmId,
      'id_direccion': request['addressId'],
      'linea': line,
      'observaciones': request['notes'],
      'fecha': serverTimestamp,
    });
    tx.update('lotes_productos/$lotId', {
      'cantidad_disponible': stock - quantity,
      'ultimo_pedido_id': id,
    });
  }
}
