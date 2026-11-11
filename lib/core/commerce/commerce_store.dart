import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../networking/api_client.dart';
import 'commerce_models.dart';
import 'inventory_models.dart';

class CommerceStore {
  static const _productsKey = 'commerce_products_v1';
  static const _ordersKey = 'commerce_orders_v1';
  static const _commissionKey = 'commerce_commission_percent_v1';
  static const _movementsKey = 'commerce_inventory_movements_v1';
  static const _pointOfSaleKey = 'commerce_point_of_sale_v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// UUID válido para que un producto nuevo pueda guardarse tanto localmente
  /// como en Supabase con el mismo identificador.
  static String newProductId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<List<CommerceProduct>> listProducts(String workshopId) async {
    final prefs = await SharedPreferences.getInstance();
    var all = _decodeList(
      prefs.getString(_productsKey),
    ).map(CommerceProduct.fromJson).toList();
    final cleaned = all.where((item) => !_isLegacyDemo(item)).toList();
    if (cleaned.length != all.length) {
      all = cleaned;
      await _saveProducts(all);
    }
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      final localForWorkshop = all
          .where((item) => item.workshopId == workshopId)
          .toList(growable: false);
      try {
        // Respalda publicaciones antiguas que existían solo en el dispositivo.
        // Esto evita que el catálogo se vea distinto en celular y computador.
        if (localForWorkshop.isNotEmpty) {
          await ApiClient().client
              .from('products')
              .upsert(localForWorkshop.map(_cloudPayload).toList());
        }
        final rows = await ApiClient().client
            .from('products')
            .select()
            .eq('workshop_id', workshopId);
        final cloud = rows
            .map((row) => _cloudProduct(Map<String, dynamic>.from(row)))
            .toList();
        final merged = <String, CommerceProduct>{
          for (final product in all) product.id: product,
          for (final product in cloud) product.id: product,
        };
        all = merged.values.toList();
        await _saveProducts(all);
      } catch (_) {
        // Se mantiene el catálogo local si temporalmente no hay conexión o
        // la migración de catálogo aún está aplicándose.
      }
    }
    final items = all.where((item) => item.workshopId == workshopId).toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<void> saveProduct(
    CommerceProduct product, {
    String movementReason = 'Ajuste de inventario',
    InventoryMovementType movementType = InventoryMovementType.adjustment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _decodeList(
      prefs.getString(_productsKey),
    ).map(CommerceProduct.fromJson).toList();
    final barcode = product.barcode.trim();
    if (barcode.isNotEmpty &&
        all.any(
          (item) =>
              item.workshopId == product.workshopId &&
              item.id != product.id &&
              item.barcode == barcode,
        )) {
      throw StateError('El código de barras ya está registrado.');
    }
    final index = all.indexWhere((item) => item.id == product.id);
    final previousStock = index < 0 ? 0 : all[index].stock;
    index < 0 ? all.add(product) : all[index] = product;
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      // Con nube activa no se informa que una publicación fue guardada si la
      // base de datos la rechazó: el administrador puede corregir el error.
      await ApiClient().client.from('products').upsert(_cloudPayload(product));
    }
    await _saveProducts(all);
    final difference = product.stock - previousStock;
    if (difference != 0) {
      await _appendMovement(
        InventoryMovement(
          id: 'movement-${DateTime.now().microsecondsSinceEpoch}',
          workshopId: product.workshopId,
          productId: product.id,
          productName: product.name,
          type: index < 0 ? InventoryMovementType.initial : movementType,
          quantityDelta: difference,
          balanceAfter: product.stock,
          reason: index < 0 ? 'Registro inicial del producto' : movementReason,
          createdAt: DateTime.now(),
        ),
      );
    }
    revision.value++;
  }

  Future<List<CommerceProduct>> findProducts(
    String workshopId,
    String query,
  ) async {
    final products = await listProducts(workshopId);
    final normalized = _normalize(query);
    if (normalized.isEmpty) return products;
    return products.where((product) {
      final searchable = _normalize(
        '${product.name} ${product.brand} ${product.barcode} '
        '${product.sku} ${product.category} ${product.description}',
      );
      return searchable.contains(normalized);
    }).toList();
  }

  Future<CommerceProduct?> findByBarcode(
    String workshopId,
    String barcode,
  ) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    final products = await listProducts(workshopId);
    for (final product in products) {
      if (product.barcode == normalized) return product;
    }
    return null;
  }

  Future<void> deleteProduct(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final all =
        _decodeList(
            prefs.getString(_productsKey),
          ).map(CommerceProduct.fromJson).toList()
          ..removeWhere((item) => item.id == productId);
    await _saveProducts(all);
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      try {
        await ApiClient().client.from('products').delete().eq('id', productId);
      } catch (_) {}
    }
    revision.value++;
  }

  CommerceProduct _cloudProduct(Map<String, dynamic> row) => CommerceProduct(
    id: row['id'].toString(),
    workshopId: row['workshop_id'].toString(),
    name: row['name']?.toString() ?? '',
    category: row['category']?.toString() ?? 'Otros',
    description: row['description']?.toString() ?? '',
    priceCents: ((row['price'] as num?)?.toDouble() ?? 0).round() * 100,
    stock: (row['stock'] as num?)?.toInt() ?? 1,
    brand: row['brand']?.toString() ?? '',
    barcode: row['barcode']?.toString() ?? '',
    sku: row['sku']?.toString() ?? '',
    partNumber: row['part_number']?.toString() ?? '',
    packageWeight: row['package_weight']?.toString() ?? '',
    productCondition: row['product_condition']?.toString() ?? 'Nuevo',
    origin: row['origin']?.toString() ?? '',
    oemCode: row['oem_code']?.toString() ?? '',
    includesPistons: row['includes_pistons'] as bool? ?? false,
    includesRings: row['includes_rings'] as bool? ?? false,
    isKit: row['is_kit'] as bool? ?? false,
    active: row['is_active'] as bool? ?? true,
    imagePath: row['image_path']?.toString(),
    imageBytes: _decodeCloudImage(row['image_base64']),
    imageGallery: _decodeCloudGallery(row['image_gallery_base64']),
  );

  Map<String, dynamic> _cloudPayload(CommerceProduct product) => {
    'id': product.id,
    'workshop_id': product.workshopId,
    'name': product.name,
    'category': product.category,
    'description': product.description,
    'price': product.priceCents ~/ 100,
    'stock': product.stock,
    'brand': product.brand,
    'barcode': product.barcode,
    'sku': product.sku,
    'part_number': product.partNumber,
    'package_weight': product.packageWeight,
    'product_condition': product.productCondition,
    'origin': product.origin,
    'oem_code': product.oemCode,
    'includes_pistons': product.includesPistons,
    'includes_rings': product.includesRings,
    'is_kit': product.isKit,
    'is_active': product.active,
    'image_path': product.imagePath,
    'image_base64': product.imageBytes == null
        ? null
        : base64Encode(product.imageBytes!),
    'image_gallery_base64': product.photos.map(base64Encode).toList(),
  };

  List<Uint8List> _decodeCloudGallery(dynamic value) {
    if (value is! List) return const [];
    return value.map(_decodeCloudImage).whereType<Uint8List>().take(4).toList();
  }

  Uint8List? _decodeCloudImage(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    try {
      return base64Decode(value.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> purgeWorkshop(String workshopId) async {
    final prefs = await SharedPreferences.getInstance();
    final products =
        _decodeList(
            prefs.getString(_productsKey),
          ).map(CommerceProduct.fromJson).toList()
          ..removeWhere((item) => item.workshopId == workshopId);
    final orders =
        _decodeList(
            prefs.getString(_ordersKey),
          ).map(CommerceOrder.fromJson).toList()
          ..removeWhere((item) => item.workshopId == workshopId);
    final movements =
        _decodeList(
            prefs.getString(_movementsKey),
          ).map(InventoryMovement.fromJson).toList()
          ..removeWhere((item) => item.workshopId == workshopId);
    final pointOfSale =
        _decodeList(
            prefs.getString(_pointOfSaleKey),
          ).map(PointOfSaleTicket.fromJson).toList()
          ..removeWhere((item) => item.workshopId == workshopId);
    await _saveProducts(products);
    await _saveOrders(orders);
    await prefs.setString(
      _movementsKey,
      jsonEncode(movements.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _pointOfSaleKey,
      jsonEncode(pointOfSale.map((item) => item.toJson()).toList()),
    );
    revision.value++;
  }

  Future<List<CommerceOrder>> listOrders({
    String? workshopId,
    String? clientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var items = _decodeList(
      prefs.getString(_ordersKey),
    ).map(CommerceOrder.fromJson);
    if (workshopId != null) {
      items = items.where((item) => item.workshopId == workshopId);
    }
    if (clientId != null) {
      items = items.where((item) => item.clientId == clientId);
    }
    final result = items.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<CommerceOrder> createSandboxPurchase({
    required CommerceProduct product,
    required String workshopName,
    required String clientId,
    required String clientName,
    required int quantity,
    required String paymentMethod,
  }) async {
    if (!product.available || quantity < 1 || quantity > product.stock) {
      throw StateError('No hay existencias suficientes.');
    }
    final now = DateTime.now();
    final random = Random.secure();
    final total = product.priceCents * quantity;
    final commission = (total * (await commissionPercent) / 100).round();
    final suffix = now.microsecondsSinceEpoch.toString();
    final order = CommerceOrder(
      id: 'order-$suffix',
      workshopId: product.workshopId,
      workshopName: workshopName,
      clientId: clientId,
      clientName: clientName,
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      unitPriceCents: product.priceCents,
      platformFeeCents: commission,
      paymentMethod: paymentMethod,
      status: CommerceOrderStatus.paid,
      pickupCode: List.generate(6, (_) => random.nextInt(10)).join(),
      receiptNumber: 'CP-${now.year}-${suffix.substring(suffix.length - 8)}',
      createdAt: now,
      updatedAt: now,
      mercadoPagoId: 'TEST-${suffix.substring(suffix.length - 10)}',
    );
    final orders = await listOrders()
      ..add(order);
    await _saveOrders(orders);
    await saveProduct(
      product.copyWith(stock: product.stock - quantity),
      movementReason: 'Compra en línea ${order.receiptNumber}',
      movementType: InventoryMovementType.sale,
    );
    revision.value++;
    return order;
  }

  Future<void> updateOrderStatus(
    String orderId,
    CommerceOrderStatus status, {
    String? pickupCode,
  }) async {
    final orders = await listOrders();
    final index = orders.indexWhere((item) => item.id == orderId);
    if (index < 0) throw StateError('Pedido no encontrado.');
    final current = orders[index];
    if (status == CommerceOrderStatus.delivered &&
        pickupCode?.trim() != current.pickupCode) {
      throw StateError('El código de entrega no coincide.');
    }
    orders[index] = current.copyWith(status: status, updatedAt: DateTime.now());
    await _saveOrders(orders);
    revision.value++;
  }

  Future<double> get commissionPercent async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_commissionKey) ?? 5;
  }

  Future<void> setCommissionPercent(double value) async {
    if (value < 0 || value > 30) {
      throw ArgumentError.value(value, 'value', 'Debe estar entre 0 y 30.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_commissionKey, value);
    revision.value++;
  }

  Future<List<InventoryMovement>> listInventoryMovements(
    String workshopId, {
    String? productId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var items = _decodeList(
      prefs.getString(_movementsKey),
    ).map(InventoryMovement.fromJson);
    items = items.where((item) => item.workshopId == workshopId);
    if (productId != null) {
      items = items.where((item) => item.productId == productId);
    }
    return items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<PointOfSaleTicket>> listPointOfSaleTickets(
    String workshopId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _decodeList(prefs.getString(_pointOfSaleKey))
        .map(PointOfSaleTicket.fromJson)
        .where((item) => item.workshopId == workshopId)
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<PointOfSaleTicket> completePointOfSale({
    required String workshopId,
    required String workshopName,
    required Map<String, int> quantities,
    required String customerName,
    required String customerDocument,
    required String customerPhone,
    required String paymentMethod,
    int discountCents = 0,
  }) async {
    if (quantities.values.fold<int>(0, (a, b) => a + b) <= 0) {
      throw StateError('Agrega por lo menos un producto a la venta.');
    }
    final products = await listProducts(workshopId);
    final lines = <PointOfSaleLine>[];
    final updated = <CommerceProduct>[];
    for (final entry in quantities.entries.where((item) => item.value > 0)) {
      final productIndex = products.indexWhere((item) => item.id == entry.key);
      if (productIndex < 0) {
        throw StateError('Uno de los productos no existe.');
      }
      final product = products[productIndex];
      if (entry.value > product.stock) {
        throw StateError('No hay existencias suficientes de ${product.name}.');
      }
      lines.add(
        PointOfSaleLine(
          productId: product.id,
          productName: product.name,
          brand: product.brand,
          barcode: product.barcode,
          quantity: entry.value,
          unitPriceCents: product.priceCents,
          costPriceCents: product.costPriceCents,
        ),
      );
      updated.add(product.copyWith(stock: product.stock - entry.value));
    }
    final now = DateTime.now();
    final suffix = now.microsecondsSinceEpoch.toString();
    final ticket = PointOfSaleTicket(
      id: 'pos-$suffix',
      workshopId: workshopId,
      workshopName: workshopName,
      invoiceNumber: 'PV-${now.year}-${suffix.substring(suffix.length - 8)}',
      customerName: customerName.trim().isEmpty
          ? 'Consumidor final'
          : customerName.trim(),
      customerDocument: customerDocument.trim(),
      customerPhone: customerPhone.trim(),
      paymentMethod: paymentMethod,
      lines: lines,
      discountCents: discountCents,
      createdAt: now,
    );
    if (ticket.discountCents < 0 ||
        ticket.discountCents > ticket.subtotalCents) {
      throw StateError('El descuento no puede superar el subtotal.');
    }
    final prefs = await SharedPreferences.getInstance();
    final allProducts = _decodeList(
      prefs.getString(_productsKey),
    ).map(CommerceProduct.fromJson).toList();
    for (final product in updated) {
      final index = allProducts.indexWhere((item) => item.id == product.id);
      if (index >= 0) allProducts[index] = product;
      final quantity = quantities[product.id] ?? 0;
      await _appendMovement(
        InventoryMovement(
          id: 'movement-${product.id}-${now.microsecondsSinceEpoch}',
          workshopId: workshopId,
          productId: product.id,
          productName: product.name,
          type: InventoryMovementType.sale,
          quantityDelta: -quantity,
          balanceAfter: product.stock,
          reason: 'Venta presencial ${ticket.invoiceNumber}',
          createdAt: now,
          reference: ticket.invoiceNumber,
        ),
      );
    }
    await _saveProducts(allProducts);
    final sales = _decodeList(
      prefs.getString(_pointOfSaleKey),
    ).map(PointOfSaleTicket.fromJson).toList()..add(ticket);
    await prefs.setString(
      _pointOfSaleKey,
      jsonEncode(sales.map((item) => item.toJson()).toList()),
    );
    revision.value++;
    return ticket;
  }

  Future<void> _saveProducts(List<CommerceProduct> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _productsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveOrders(List<CommerceOrder> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ordersKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _appendMovement(InventoryMovement movement) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _decodeList(
      prefs.getString(_movementsKey),
    ).map(InventoryMovement.fromJson).toList()..add(movement);
    await prefs.setString(
      _movementsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  List<Map<String, dynamic>> _decodeList(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      return (jsonDecode(source) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool _isLegacyDemo(CommerceProduct item) =>
      item.id.endsWith('-spark') ||
      item.id.endsWith('-brake') ||
      item.id.endsWith('-tire') ||
      item.id.endsWith('-oil');

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}
