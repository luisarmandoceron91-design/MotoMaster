import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/auth/local_workshop_admin_store.dart';
import 'package:moto_master/core/commerce/commerce_models.dart';
import 'package:moto_master/core/commerce/commerce_store.dart';
import 'package:moto_master/core/staff/workshop_mechanic_store.dart';
import 'package:moto_master/core/workshops/local_workshop_directory_store.dart';
import 'package:moto_master/core/workshops/workshop.dart';
import 'package:moto_master/core/workshops/workshop_data_purge_service.dart';
import 'package:moto_master/core/workshops/workshop_feedback_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'activar y suspender cambia inmediatamente el directorio del cliente',
    () async {
      final accounts = LocalWorkshopAdminStore();
      final directory = LocalWorkshopDirectoryStore();
      await accounts.register(
        password: 'ClaveSegura123',
        fullName: 'Administrador',
        email: 'admin@ciclo.com',
        phone: '3000000000',
      );
      await accounts.attachWorkshopToActiveAccount(
        tenantId: 'taller-ciclo',
        tenantName: 'Taller Ciclo',
      );
      await directory.upsert(
        const Workshop(
          id: 'taller-ciclo',
          name: 'Taller Ciclo',
          slug: 'taller-ciclo',
          tagline: '',
          accentColorValue: 0xFFFF6500,
          accessStatus: 'expired',
        ),
      );

      await accounts.setWorkshopAvailability(
        tenantId: 'taller-ciclo',
        enabled: true,
      );
      await directory.syncRegisteredAccounts(await accounts.listAccounts());
      expect((await directory.listActive()).single.accessStatus, 'active');

      await accounts.setWorkshopAvailability(
        tenantId: 'taller-ciclo',
        enabled: false,
      );
      await directory.syncRegisteredAccounts(await accounts.listAccounts());
      expect(await directory.listActive(), isEmpty);
    },
  );

  test(
    'eliminación definitiva borra cuenta, catálogo, equipo y opiniones',
    () async {
      const workshopId = 'taller-purgable';
      final accounts = LocalWorkshopAdminStore();
      await accounts.register(
        password: 'ClaveSegura123',
        fullName: 'Administrador',
        email: 'admin@purgable.com',
        phone: '3000000000',
      );
      await accounts.attachWorkshopToActiveAccount(
        tenantId: workshopId,
        tenantName: 'Taller Purgable',
      );
      await LocalWorkshopDirectoryStore().upsert(
        const Workshop(
          id: workshopId,
          name: 'Taller Purgable',
          slug: 'taller-purgable',
          tagline: '',
          accentColorValue: 0xFFFF6500,
          accessStatus: 'active',
          permanentAccess: true,
        ),
      );
      await CommerceStore().saveProduct(
        const CommerceProduct(
          id: 'producto-1',
          workshopId: workshopId,
          name: 'Aceite',
          category: 'Motor',
          description: '',
          priceCents: 5000000,
          stock: 2,
        ),
      );
      await WorkshopMechanicStore().save(
        const WorkshopMechanic(
          id: 'mecanico-1',
          workshopId: workshopId,
          name: 'Carlos',
          specialty: 'Motor',
        ),
      );
      await WorkshopFeedbackStore().add(
        WorkshopFeedback(
          id: 'opinion-1',
          workshopId: workshopId,
          clientName: 'Cliente',
          clientEmail: 'cliente@correo.com',
          mechanicName: 'Carlos',
          serviceType: 'Motor',
          rating: 5,
          comment: 'Excelente',
          createdAt: DateTime(2026, 10, 29),
        ),
      );
      await accounts.moveWorkshopToTrash(
        tenantId: workshopId,
        reason: 'Eliminación definitiva solicitada',
      );

      expect(await WorkshopDataPurgeService().purge(workshopId), isNull);
      expect(await accounts.listAccounts(), isEmpty);
      expect(await LocalWorkshopDirectoryStore().listAll(), isEmpty);
      expect(await CommerceStore().listProducts(workshopId), isEmpty);
      expect(await WorkshopMechanicStore().list(workshopId), isEmpty);
      expect(await WorkshopFeedbackStore().list(workshopId), isEmpty);
    },
  );
}
