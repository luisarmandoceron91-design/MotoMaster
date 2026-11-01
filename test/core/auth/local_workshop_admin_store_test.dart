import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_master/core/auth/local_workshop_admin_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('las credenciales iniciales solo identifican el primer acceso', () {
    final store = LocalWorkshopAdminStore();
    expect(store.isBootstrapCredential('admin', '123456'), isTrue);
    expect(store.isBootstrapCredential('ADMIN', '123456'), isTrue);
    expect(store.isBootstrapCredential('admin', 'otra'), isFalse);
  });

  test(
    'el registro crea credenciales personales y una prueba de 3 días',
    () async {
      final store = LocalWorkshopAdminStore();
      final before = DateTime.now();

      final error = await store.register(
        password: 'ClaveSegura123',
        fullName: 'Administrador Taller',
        email: 'admin@taller.com',
        phone: '3001234567',
      );

      expect(error, isNull);
      final activeAccount = await store.loadAccount();
      expect(activeAccount?.email, 'admin@taller.com');
      final account = await store.authenticate(
        username: 'admin@taller.com',
        password: 'ClaveSegura123',
      );
      expect(account, isNotNull);
      expect(account!.canEnter, isTrue);
      expect(
        account.trialEndsAt.difference(before).inHours,
        inInclusiveRange(71, 72),
      );
    },
  );

  test('un valor que no sea correo no puede quedar como usuario', () async {
    final store = LocalWorkshopAdminStore();
    final error = await store.register(
      password: 'ClaveSegura123',
      fullName: 'Administrador Taller',
      email: 'correo-invalido',
      phone: '3001234567',
    );
    expect(error, contains('correo'));
  });

  test('cada administrador conserva únicamente su propio taller', () async {
    final store = LocalWorkshopAdminStore();
    await store.register(
      password: 'ClaveTallerUno',
      fullName: 'Administrador Uno',
      email: 'uno@taller.com',
      phone: '3000000001',
    );
    await store.attachWorkshopToActiveAccount(
      tenantId: 'tenant-uno',
      tenantName: 'Taller Uno',
    );

    await store.register(
      password: 'ClaveTallerDos',
      fullName: 'Administrador Dos',
      email: 'dos@taller.com',
      phone: '3000000002',
    );
    await store.attachWorkshopToActiveAccount(
      tenantId: 'tenant-dos',
      tenantName: 'Taller Dos',
    );

    final first = await store.authenticate(
      username: 'uno@taller.com',
      password: 'ClaveTallerUno',
    );
    final second = await store.authenticate(
      username: 'dos@taller.com',
      password: 'ClaveTallerDos',
    );

    expect(first?.tenantId, 'tenant-uno');
    expect(first?.tenantName, 'Taller Uno');
    expect(second?.tenantId, 'tenant-dos');
    expect(second?.tenantName, 'Taller Dos');
  });

  test(
    'aprobar tiempo conserva el tenant y toda la identidad del taller',
    () async {
      final store = LocalWorkshopAdminStore();
      await store.register(
        password: 'ClaveTallerSeguro',
        fullName: 'Administradora Prueba',
        email: 'prueba@taller.com',
        phone: '3000000099',
      );
      await store.attachWorkshopToActiveAccount(
        tenantId: 'tenant-seguro',
        tenantName: 'Taller Seguro',
      );
      final before = await store.loadAccount();

      final requestError = await store.requestTrialExtension(
        requestedDays: 1,
        reason: 'Necesito terminar de probar la facturación',
      );
      final pending = await store.listPendingTrialExtensionRequests();
      final decisionError = await store.decideTrialExtension(
        accountEmail: 'prueba@taller.com',
        approve: true,
        grantedDays: 3,
        decisionReason: 'Ampliación autorizada para completar la prueba',
      );
      final after = await store.authenticate(
        username: 'prueba@taller.com',
        password: 'ClaveTallerSeguro',
      );

      expect(requestError, isNull);
      expect(pending, hasLength(1));
      expect(decisionError, isNull);
      expect(after?.tenantId, before?.tenantId);
      expect(after?.tenantName, before?.tenantName);
      expect(after!.trialEndsAt.isAfter(before!.trialEndsAt), isTrue);
      expect(after.canEnter, isTrue);
      expect(await store.listPendingTrialExtensionRequests(), isEmpty);
    },
  );

  test('la papelera recupera el mismo taller sin borrar sus datos', () async {
    final store = LocalWorkshopAdminStore();
    await store.register(
      password: 'ClaveRecuperable123',
      fullName: 'Administrador Recuperable',
      email: 'recuperable@taller.com',
      phone: '3000000088',
    );
    await store.attachWorkshopToActiveAccount(
      tenantId: 'tenant-recuperable',
      tenantName: 'Taller Recuperable',
    );

    final deleteError = await store.moveWorkshopToTrash(
      tenantId: 'tenant-recuperable',
      reason: 'Cuenta temporal creada durante las pruebas',
    );
    final deleted = (await store.listAccounts()).single;
    final restoreError = await store.restoreWorkshop(
      tenantId: 'tenant-recuperable',
    );
    final restored = await store.authenticate(
      username: 'recuperable@taller.com',
      password: 'ClaveRecuperable123',
    );

    expect(deleteError, isNull);
    expect(deleted.deletedAt, isNotNull);
    expect(deleted.accessState, WorkshopAccessState.suspended);
    expect(restoreError, isNull);
    expect(restored?.tenantId, 'tenant-recuperable');
    expect(restored?.tenantName, 'Taller Recuperable');
    expect(restored?.deletedAt, isNull);
    expect(restored?.canEnter, isTrue);
  });

  test('desactivar y reactivar conserva la cuenta y su taller', () async {
    final store = LocalWorkshopAdminStore();
    await store.register(
      password: 'ClaveDisponible123',
      fullName: 'Administrador Disponible',
      email: 'disponible@taller.com',
      phone: '3000000077',
    );
    await store.attachWorkshopToActiveAccount(
      tenantId: 'tenant-disponible',
      tenantName: 'Taller Disponible',
    );

    final suspendedState = await store.setWorkshopAvailability(
      tenantId: 'tenant-disponible',
      enabled: false,
    );
    final suspended = await store.authenticate(
      username: 'disponible@taller.com',
      password: 'ClaveDisponible123',
    );
    final restoredState = await store.setWorkshopAvailability(
      tenantId: 'tenant-disponible',
      enabled: true,
    );
    final restored = await store.authenticate(
      username: 'disponible@taller.com',
      password: 'ClaveDisponible123',
    );

    expect(suspendedState, WorkshopAccessState.suspended);
    expect(suspended?.canEnter, isFalse);
    expect(restoredState, WorkshopAccessState.active);
    expect(restored?.tenantId, 'tenant-disponible');
    expect(restored?.tenantName, 'Taller Disponible');
    expect(restored?.canEnter, isTrue);
  });
}
