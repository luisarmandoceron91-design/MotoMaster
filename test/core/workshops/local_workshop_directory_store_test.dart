import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_master/core/auth/local_workshop_admin_store.dart';
import 'package:moto_master/core/workshops/client_workshop_history_store.dart';
import 'package:moto_master/core/workshops/local_workshop_directory_store.dart';
import 'package:moto_master/core/workshops/workshop.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'publishes complete workshop details for the client directory',
    () async {
      final store = LocalWorkshopDirectoryStore();
      await store.upsert(
        Workshop(
          id: 'workshop-1',
          name: 'Taller Central',
          slug: 'taller-central',
          tagline: 'Servicio profesional',
          accentColorValue: 0xFFFF6500,
          accessStatus: 'active',
          permanentAccess: true,
          department: 'Nariño',
          municipality: 'Pasto',
          neighborhood: 'Centro',
          address: 'Calle 1 # 2-3',
          phone: '3001234567',
          email: 'contacto@taller.com',
          openingHours: const {
            'monday': {'open': '08:00', 'close': '18:00'},
          },
        ),
      );

      final workshops = await store.listActive();
      expect(workshops, hasLength(1));
      expect(workshops.single.locationLine, 'Nariño · Pasto · Centro');
      expect(workshops.single.phone, '3001234567');
      expect(workshops.single.email, 'contacto@taller.com');
    },
  );

  test('keeps workshop history isolated for each client', () async {
    final history = ClientWorkshopHistoryStore();
    await history.remember('uno@correo.com', 'workshop-1');
    await history.remember('dos@correo.com', 'workshop-2');

    expect(await history.list('uno@correo.com'), ['workshop-1']);
    expect(await history.list('dos@correo.com'), ['workshop-2']);

    await history.remove('uno@correo.com', 'workshop-1');
    expect(await history.list('uno@correo.com'), isEmpty);
    expect(await history.list('dos@correo.com'), ['workshop-2']);
  });

  test('hides a suspended workshop and restores all public data', () async {
    final store = LocalWorkshopDirectoryStore();
    final trialEnd = DateTime.now().add(const Duration(days: 3));
    await store.upsert(
      Workshop(
        id: 'workshop-toggle',
        name: 'Taller Recuperable',
        slug: 'taller-recuperable',
        tagline: 'Datos conservados',
        accentColorValue: 0xFFFF6500,
        phone: '3001234567',
        address: 'Calle 10 # 20-30',
        trialEndsAt: trialEnd,
      ),
    );

    await store.setAccessStatus('workshop-toggle', 'suspended');
    expect(await store.listActive(), isEmpty);

    await store.setAccessStatus('workshop-toggle', 'trial');
    final restored = (await store.listActive()).single;
    expect(restored.name, 'Taller Recuperable');
    expect(restored.phone, '3001234567');
    expect(restored.address, 'Calle 10 # 20-30');
    expect(restored.trialEndsAt, trialEnd);
  });

  test('publishes active legacy workshop accounts in the directory', () async {
    final accounts = LocalWorkshopAdminStore();
    await accounts.register(
      password: 'ClaveTaller123',
      fullName: 'Administrador Histórico',
      email: 'historico@taller.com',
      phone: '3000000000',
    );
    await accounts.attachWorkshopToActiveAccount(
      tenantId: 'legacy-workshop',
      tenantName: 'Taller Histórico',
    );
    await accounts.setWorkshopAvailability(
      tenantId: 'legacy-workshop',
      enabled: true,
    );

    final directory = LocalWorkshopDirectoryStore();
    await directory.syncRegisteredAccounts(await accounts.listAccounts());
    final workshops = await directory.listActive();

    expect(workshops, hasLength(1));
    expect(workshops.single.id, 'legacy-workshop');
    expect(workshops.single.name, 'Taller Histórico');
    expect(workshops.single.accessStatus, 'active');
    expect(workshops.single.phone, isEmpty);
    expect(workshops.single.email, isEmpty);
  });

  test(
    'hides an expired workshop until the platform owner activates it',
    () async {
      final store = LocalWorkshopDirectoryStore();
      await store.upsert(
        const Workshop(
          id: 'expired-workshop',
          name: 'Taller con acceso pendiente',
          slug: 'taller-acceso-pendiente',
          tagline: '',
          accentColorValue: 0xFFFF6500,
          accessStatus: 'expired',
        ),
      );

      final workshops = await store.listActive();
      expect(workshops, isEmpty);
    },
  );

  test(
    'keeps the client and owner directories on the same workshop set',
    () async {
      final store = LocalWorkshopDirectoryStore();
      final trialEndsAt = DateTime.now().add(const Duration(days: 3));
      final publicWorkshops = [
        Workshop(
          id: 'cloud-1',
          name: 'Taller Uno',
          slug: 'taller-uno',
          tagline: '',
          accentColorValue: 0xFFFF6500,
          accessStatus: 'active',
          permanentAccess: true,
        ),
        Workshop(
          id: 'cloud-2',
          name: 'Taller Dos',
          slug: 'taller-dos',
          tagline: '',
          accentColorValue: 0xFFFF6500,
          accessStatus: 'trial',
          trialEndsAt: trialEndsAt,
        ),
        Workshop(
          id: 'cloud-3',
          name: 'Taller Tres',
          slug: 'taller-tres',
          tagline: '',
          accentColorValue: 0xFFFF6500,
          accessStatus: 'trial',
          trialEndsAt: trialEndsAt,
        ),
      ];

      await store.syncPublicDirectory(publicWorkshops);
      await store.syncPublicDirectory(publicWorkshops);

      expect(await store.listAll(), hasLength(3));
      expect(await store.listActive(), hasLength(3));
    },
  );
}
