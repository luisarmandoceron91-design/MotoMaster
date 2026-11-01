import 'package:flutter/foundation.dart';

enum InventoryMovementType { initial, purchase, adjustment, sale, returnItem }

@immutable
class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.workshopId,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantityDelta,
    required this.balanceAfter,
    required this.reason,
    required this.createdAt,
    this.reference = '',
  });

  final String id;
  final String workshopId;
  final String productId;
  final String productName;
  final InventoryMovementType type;
  final int quantityDelta;
  final int balanceAfter;
  final String reason;
  final DateTime createdAt;
  final String reference;

  Map<String, dynamic> toJson() => {
    'id': id,
    'workshop_id': workshopId,
    'product_id': productId,
    'product_name': productName,
    'type': type.name,
    'quantity_delta': quantityDelta,
    'balance_after': balanceAfter,
    'reason': reason,
    'created_at': createdAt.toIso8601String(),
    'reference': reference,
  };

  factory InventoryMovement.fromJson(Map<String, dynamic> json) =>
      InventoryMovement(
        id: json['id']?.toString() ?? '',
        workshopId: json['workshop_id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? '',
        type: InventoryMovementType.values.firstWhere(
          (item) => item.name == json['type'],
          orElse: () => InventoryMovementType.adjustment,
        ),
        quantityDelta: (json['quantity_delta'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
        reason: json['reason']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        reference: json['reference']?.toString() ?? '',
      );
}

@immutable
class PointOfSaleLine {
  const PointOfSaleLine({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.barcode,
    required this.quantity,
    required this.unitPriceCents,
    required this.costPriceCents,
  });

  final String productId;
  final String productName;
  final String brand;
  final String barcode;
  final int quantity;
  final int unitPriceCents;
  final int costPriceCents;

  int get totalCents => quantity * unitPriceCents;
  int get profitCents => quantity * (unitPriceCents - costPriceCents);

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'brand': brand,
    'barcode': barcode,
    'quantity': quantity,
    'unit_price_cents': unitPriceCents,
    'cost_price_cents': costPriceCents,
  };

  factory PointOfSaleLine.fromJson(Map<String, dynamic> json) =>
      PointOfSaleLine(
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? '',
        brand: json['brand']?.toString() ?? '',
        barcode: json['barcode']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitPriceCents: (json['unit_price_cents'] as num?)?.toInt() ?? 0,
        costPriceCents: (json['cost_price_cents'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class PointOfSaleTicket {
  const PointOfSaleTicket({
    required this.id,
    required this.workshopId,
    required this.workshopName,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerDocument,
    required this.customerPhone,
    required this.paymentMethod,
    required this.lines,
    required this.discountCents,
    required this.createdAt,
  });

  final String id;
  final String workshopId;
  final String workshopName;
  final String invoiceNumber;
  final String customerName;
  final String customerDocument;
  final String customerPhone;
  final String paymentMethod;
  final List<PointOfSaleLine> lines;
  final int discountCents;
  final DateTime createdAt;

  int get subtotalCents =>
      lines.fold(0, (total, item) => total + item.totalCents);
  int get totalCents => (subtotalCents - discountCents).clamp(0, subtotalCents);
  int get profitCents =>
      lines.fold(0, (total, item) => total + item.profitCents) - discountCents;
  int get totalUnits => lines.fold(0, (total, item) => total + item.quantity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'workshop_id': workshopId,
    'workshop_name': workshopName,
    'invoice_number': invoiceNumber,
    'customer_name': customerName,
    'customer_document': customerDocument,
    'customer_phone': customerPhone,
    'payment_method': paymentMethod,
    'lines': lines.map((item) => item.toJson()).toList(),
    'discount_cents': discountCents,
    'created_at': createdAt.toIso8601String(),
  };

  factory PointOfSaleTicket.fromJson(
    Map<String, dynamic> json,
  ) => PointOfSaleTicket(
    id: json['id']?.toString() ?? '',
    workshopId: json['workshop_id']?.toString() ?? '',
    workshopName: json['workshop_name']?.toString() ?? 'Taller',
    invoiceNumber: json['invoice_number']?.toString() ?? '',
    customerName: json['customer_name']?.toString() ?? 'Consumidor final',
    customerDocument: json['customer_document']?.toString() ?? '',
    customerPhone: json['customer_phone']?.toString() ?? '',
    paymentMethod: json['payment_method']?.toString() ?? 'Efectivo',
    lines: (json['lines'] as List? ?? const [])
        .map(
          (item) =>
              PointOfSaleLine.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    discountCents: (json['discount_cents'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

String inventoryMovementLabel(InventoryMovementType type) => switch (type) {
  InventoryMovementType.initial => 'Inventario inicial',
  InventoryMovementType.purchase => 'Entrada de mercancía',
  InventoryMovementType.adjustment => 'Ajuste manual',
  InventoryMovementType.sale => 'Venta presencial',
  InventoryMovementType.returnItem => 'Devolución',
};
