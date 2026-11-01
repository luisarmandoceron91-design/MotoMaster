import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_master/core/commerce/commerce_models.dart';
import 'package:moto_master/core/commerce/commerce_store.dart';
import 'package:moto_master/core/commerce/inventory_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CommerceProduct makeProduct() => const CommerceProduct(
    id: 'product-1',
    workshopId: 'workshop-1',
    name: 'Producto publicado por el taller',
    category: 'Motor',
    description: 'Producto real del inventario.',
    priceCents: 10000000,
    stock: 4,
  );

  test(
    'a paid purchase updates stock and appears in all scoped views',
    () async {
      final store = CommerceStore();
      final product = makeProduct();
      await store.saveProduct(product);
      final order = await store.createSandboxPurchase(
        product: product,
        workshopName: 'Taller Uno',
        clientId: 'client-1',
        clientName: 'Diana',
        quantity: 1,
        paymentMethod: 'Mercado Pago',
      );

      expect(order.status, CommerceOrderStatus.paid);
      expect(order.platformFeeCents, (order.subtotalCents * .05).round());
      expect((await store.listOrders(workshopId: 'workshop-1')), hasLength(1));
      expect((await store.listOrders(clientId: 'client-1')), hasLength(1));
      final updated = (await store.listProducts(
        'workshop-1',
      )).firstWhere((item) => item.id == product.id);
      expect(updated.stock, product.stock - 1);
    },
  );

  test('pickup requires the correct one-time code', () async {
    final store = CommerceStore();
    final product = makeProduct();
    await store.saveProduct(product);
    final order = await store.createSandboxPurchase(
      product: product,
      workshopName: 'Taller Uno',
      clientId: 'client-1',
      clientName: 'Diana',
      quantity: 1,
      paymentMethod: 'PSE',
    );

    expect(
      () => store.updateOrderStatus(
        order.id,
        CommerceOrderStatus.delivered,
        pickupCode: '000000',
      ),
      throwsStateError,
    );
    await store.updateOrderStatus(
      order.id,
      CommerceOrderStatus.delivered,
      pickupCode: order.pickupCode,
    );
    final delivered = (await store.listOrders()).single;
    expect(delivered.status, CommerceOrderStatus.delivered);
  });

  test('finds products by name, brand, reference and barcode', () async {
    final store = CommerceStore();
    await store.saveProduct(
      const CommerceProduct(
        id: 'product-search',
        workshopId: 'workshop-1',
        name: 'Pastillas de freno delanteras',
        brand: 'Brembo',
        barcode: '7701234567890',
        sku: 'BRM-PF-01',
        category: 'Frenos',
        description: 'Juego completo',
        priceCents: 7990000,
        stock: 5,
      ),
    );

    expect(await store.findProducts('workshop-1', 'brembo'), hasLength(1));
    expect(await store.findProducts('workshop-1', 'BRM-PF'), hasLength(1));
    expect(
      (await store.findByBarcode('workshop-1', '7701234567890'))?.name,
      'Pastillas de freno delanteras',
    );
  });

  test('does not allow duplicate barcodes inside the same workshop', () async {
    final store = CommerceStore();
    await store.saveProduct(
      const CommerceProduct(
        id: 'first',
        workshopId: 'workshop-1',
        name: 'Producto uno',
        barcode: '123456789',
        category: 'Motor',
        description: '',
        priceCents: 10000,
        stock: 1,
      ),
    );

    expect(
      () => store.saveProduct(
        const CommerceProduct(
          id: 'second',
          workshopId: 'workshop-1',
          name: 'Producto dos',
          barcode: '123456789',
          category: 'Motor',
          description: '',
          priceCents: 20000,
          stock: 1,
        ),
      ),
      throwsStateError,
    );
  });

  test('a point of sale records many items, stock and history', () async {
    final store = CommerceStore();
    await store.saveProduct(
      const CommerceProduct(
        id: 'oil',
        workshopId: 'workshop-1',
        name: 'Aceite',
        brand: 'Motul',
        barcode: '111111',
        category: 'Motor',
        description: '',
        costPriceCents: 3000000,
        priceCents: 5000000,
        stock: 6,
      ),
    );
    await store.saveProduct(
      const CommerceProduct(
        id: 'filter',
        workshopId: 'workshop-1',
        name: 'Filtro',
        brand: 'K&N',
        barcode: '222222',
        category: 'Filtros',
        description: '',
        costPriceCents: 2000000,
        priceCents: 3500000,
        stock: 4,
      ),
    );

    final ticket = await store.completePointOfSale(
      workshopId: 'workshop-1',
      workshopName: 'Taller Uno',
      quantities: const {'oil': 2, 'filter': 1},
      customerName: 'Diana',
      customerDocument: '123',
      customerPhone: '3000000000',
      paymentMethod: 'Nequi',
      discountCents: 500000,
    );

    expect(ticket.lines, hasLength(2));
    expect(ticket.totalUnits, 3);
    expect(ticket.totalCents, 13000000);
    expect((await store.listPointOfSaleTickets('workshop-1')), hasLength(1));
    final products = await store.listProducts('workshop-1');
    expect(products.firstWhere((item) => item.id == 'oil').stock, 4);
    expect(products.firstWhere((item) => item.id == 'filter').stock, 3);
    final movements = await store.listInventoryMovements('workshop-1');
    expect(
      movements.where((item) => item.type == InventoryMovementType.sale),
      hasLength(2),
    );
  });

  test('conserva la imagen publicada del repuesto', () async {
    final store = CommerceStore();
    final product = CommerceProduct(
      id: 'product-image',
      workshopId: 'workshop-1',
      name: 'Bujía NGK',
      category: 'Motor',
      description: 'Bujía de iridio',
      priceCents: 2800000,
      stock: 8,
      imageBytes: Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]),
    );

    await store.saveProduct(product);
    final saved = (await store.listProducts('workshop-1')).single;

    expect(saved.imageBytes, product.imageBytes);
  });
}
