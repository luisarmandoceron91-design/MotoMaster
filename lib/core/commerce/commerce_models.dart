import 'dart:convert';

import 'package:flutter/foundation.dart';

enum CommerceOrderStatus {
  awaitingPayment,
  paid,
  preparing,
  readyForPickup,
  delivered,
  cancelled,
  refunded,
}

@immutable
class CommerceProduct {
  const CommerceProduct({
    required this.id,
    required this.workshopId,
    required this.name,
    required this.category,
    required this.description,
    required this.priceCents,
    required this.stock,
    this.brand = '',
    this.barcode = '',
    this.sku = '',
    this.costPriceCents = 0,
    this.minimumStock = 3,
    this.supplier = '',
    this.location = '',
    this.active = true,
    this.imagePath,
    this.imageBytes,
    this.imageGallery = const [],
  });

  final String id;
  final String workshopId;
  final String name;
  final String category;
  final String description;
  final int priceCents;
  final int stock;
  final String brand;
  final String barcode;
  final String sku;
  final int costPriceCents;
  final int minimumStock;
  final String supplier;
  final String location;
  final bool active;
  final String? imagePath;
  final Uint8List? imageBytes;

  /// Hasta cuatro fotografías del mismo producto, en el orden publicado.
  final List<Uint8List> imageGallery;

  List<Uint8List> get photos => imageGallery.isNotEmpty
      ? List.unmodifiable(imageGallery.take(4))
      : imageBytes == null
      ? const []
      : [imageBytes!];

  bool get available => active && stock > 0;
  bool get lowStock => stock <= minimumStock;

  CommerceProduct copyWith({
    String? name,
    String? category,
    String? description,
    int? priceCents,
    int? stock,
    String? brand,
    String? barcode,
    String? sku,
    int? costPriceCents,
    int? minimumStock,
    String? supplier,
    String? location,
    bool? active,
    String? imagePath,
    Uint8List? imageBytes,
    List<Uint8List>? imageGallery,
    bool clearImageBytes = false,
  }) => CommerceProduct(
    id: id,
    workshopId: workshopId,
    name: name ?? this.name,
    category: category ?? this.category,
    description: description ?? this.description,
    priceCents: priceCents ?? this.priceCents,
    stock: stock ?? this.stock,
    brand: brand ?? this.brand,
    barcode: barcode ?? this.barcode,
    sku: sku ?? this.sku,
    costPriceCents: costPriceCents ?? this.costPriceCents,
    minimumStock: minimumStock ?? this.minimumStock,
    supplier: supplier ?? this.supplier,
    location: location ?? this.location,
    active: active ?? this.active,
    imagePath: imagePath ?? this.imagePath,
    imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
    imageGallery: imageGallery ?? this.imageGallery,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'workshop_id': workshopId,
    'name': name,
    'category': category,
    'description': description,
    'price_cents': priceCents,
    'stock': stock,
    'brand': brand,
    'barcode': barcode,
    'sku': sku,
    'cost_price_cents': costPriceCents,
    'minimum_stock': minimumStock,
    'supplier': supplier,
    'location': location,
    'active': active,
    'image_path': imagePath,
    'image_base64': imageBytes == null ? null : base64Encode(imageBytes!),
    'image_gallery_base64': photos.map(base64Encode).toList(),
  };

  factory CommerceProduct.fromJson(Map<String, dynamic> json) =>
      CommerceProduct(
        id: json['id'].toString(),
        workshopId: json['workshop_id'].toString(),
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Otros',
        description: json['description']?.toString() ?? '',
        priceCents: (json['price_cents'] as num?)?.toInt() ?? 0,
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        brand: json['brand']?.toString() ?? '',
        barcode: json['barcode']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        costPriceCents: (json['cost_price_cents'] as num?)?.toInt() ?? 0,
        minimumStock: (json['minimum_stock'] as num?)?.toInt() ?? 3,
        supplier: json['supplier']?.toString() ?? '',
        location: json['location']?.toString() ?? '',
        active: json['active'] as bool? ?? true,
        imagePath: json['image_path']?.toString(),
        imageBytes: _decodeProductImage(json['image_base64']),
        imageGallery: _decodeProductGallery(json['image_gallery_base64']),
      );
}

List<Uint8List> _decodeProductGallery(dynamic value) {
  if (value is! List) return const [];
  return value.map(_decodeProductImage).whereType<Uint8List>().take(4).toList();
}

Uint8List? _decodeProductImage(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  try {
    return base64Decode(value.toString());
  } catch (_) {
    return null;
  }
}

@immutable
class CommerceOrder {
  const CommerceOrder({
    required this.id,
    required this.workshopId,
    required this.workshopName,
    required this.clientId,
    required this.clientName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceCents,
    required this.platformFeeCents,
    required this.paymentMethod,
    required this.status,
    required this.pickupCode,
    required this.receiptNumber,
    required this.createdAt,
    this.updatedAt,
    this.mercadoPagoId,
    this.dianInvoiceUrl,
    this.cufe,
  });

  final String id;
  final String workshopId;
  final String workshopName;
  final String clientId;
  final String clientName;
  final String productId;
  final String productName;
  final int quantity;
  final int unitPriceCents;
  final int platformFeeCents;
  final String paymentMethod;
  final CommerceOrderStatus status;
  final String pickupCode;
  final String receiptNumber;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? mercadoPagoId;
  final String? dianInvoiceUrl;
  final String? cufe;

  int get subtotalCents => unitPriceCents * quantity;
  int get workshopNetBeforeGatewayCents => subtotalCents - platformFeeCents;
  bool get paid => !{
    CommerceOrderStatus.awaitingPayment,
    CommerceOrderStatus.cancelled,
  }.contains(status);

  CommerceOrder copyWith({CommerceOrderStatus? status, DateTime? updatedAt}) =>
      CommerceOrder(
        id: id,
        workshopId: workshopId,
        workshopName: workshopName,
        clientId: clientId,
        clientName: clientName,
        productId: productId,
        productName: productName,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        platformFeeCents: platformFeeCents,
        paymentMethod: paymentMethod,
        status: status ?? this.status,
        pickupCode: pickupCode,
        receiptNumber: receiptNumber,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        mercadoPagoId: mercadoPagoId,
        dianInvoiceUrl: dianInvoiceUrl,
        cufe: cufe,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'workshop_id': workshopId,
    'workshop_name': workshopName,
    'client_id': clientId,
    'client_name': clientName,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price_cents': unitPriceCents,
    'platform_fee_cents': platformFeeCents,
    'payment_method': paymentMethod,
    'status': status.name,
    'pickup_code': pickupCode,
    'receipt_number': receiptNumber,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'mercado_pago_id': mercadoPagoId,
    'dian_invoice_url': dianInvoiceUrl,
    'cufe': cufe,
  };

  factory CommerceOrder.fromJson(Map<String, dynamic> json) => CommerceOrder(
    id: json['id'].toString(),
    workshopId: json['workshop_id'].toString(),
    workshopName: json['workshop_name']?.toString() ?? 'Taller',
    clientId: json['client_id'].toString(),
    clientName: json['client_name']?.toString() ?? 'Cliente',
    productId: json['product_id'].toString(),
    productName: json['product_name']?.toString() ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    unitPriceCents: (json['unit_price_cents'] as num?)?.toInt() ?? 0,
    platformFeeCents: (json['platform_fee_cents'] as num?)?.toInt() ?? 0,
    paymentMethod: json['payment_method']?.toString() ?? 'Mercado Pago',
    status: CommerceOrderStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => CommerceOrderStatus.awaitingPayment,
    ),
    pickupCode: json['pickup_code']?.toString() ?? '',
    receiptNumber: json['receipt_number']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    mercadoPagoId: json['mercado_pago_id']?.toString(),
    dianInvoiceUrl: json['dian_invoice_url']?.toString(),
    cufe: json['cufe']?.toString(),
  );
}

String commerceMoney(int cents) {
  final pesos = cents ~/ 100;
  final digits = pesos.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, digits.length);
    groups.insert(0, digits.substring(start, end));
  }
  return '\$${groups.join('.')}';
}

String commerceStatusLabel(CommerceOrderStatus status) => switch (status) {
  CommerceOrderStatus.awaitingPayment => 'Esperando pago',
  CommerceOrderStatus.paid => 'Pago aprobado',
  CommerceOrderStatus.preparing => 'Preparando',
  CommerceOrderStatus.readyForPickup => 'Listo para recoger',
  CommerceOrderStatus.delivered => 'Entregado',
  CommerceOrderStatus.cancelled => 'Cancelado',
  CommerceOrderStatus.refunded => 'Reembolsado',
};
