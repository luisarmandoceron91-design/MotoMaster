import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/staff/workshop_mechanic_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('separa mecánicos por taller y muestra solo disponibles', () async {
    final store = WorkshopMechanicStore();
    await store.save(
      const WorkshopMechanic(
        id: 'm1',
        workshopId: 'taller-1',
        name: 'Carlos',
        specialty: 'Motor',
      ),
    );
    await store.save(
      const WorkshopMechanic(
        id: 'm2',
        workshopId: 'taller-1',
        name: 'Laura',
        specialty: 'Electricidad',
        available: false,
      ),
    );
    await store.save(
      const WorkshopMechanic(
        id: 'm3',
        workshopId: 'taller-2',
        name: 'Miguel',
        specialty: 'Frenos',
      ),
    );

    expect((await store.list('taller-1')).map((item) => item.name), [
      'Carlos',
      'Laura',
    ]);
    expect((await store.available('taller-1')).single.name, 'Carlos');
  });

  test('retirar conserva historial pero oculta al cliente', () async {
    final store = WorkshopMechanicStore();
    const mechanic = WorkshopMechanic(
      id: 'm1',
      workshopId: 'taller-1',
      name: 'Carlos',
      specialty: 'Motor',
    );
    await store.save(mechanic);
    await store.archive(mechanic);

    expect(await store.list('taller-1'), isEmpty);
    final history = await store.list('taller-1', includeInactive: true);
    expect(history.single.active, isFalse);
    expect(history.single.available, isFalse);
  });

  test('conserva foto y perfil profesional del mecánico', () async {
    final store = WorkshopMechanicStore();
    await store.save(
      WorkshopMechanic(
        id: 'm1',
        workshopId: 'taller-1',
        name: 'Ana',
        specialty: 'Diagnóstico electrónico',
        bio: 'Especialista en motocicletas de alto cilindraje.',
        experienceYears: 8,
        photoBytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    );

    final mechanic = (await store.list('taller-1')).single;
    expect(mechanic.bio, contains('alto cilindraje'));
    expect(mechanic.experienceYears, 8);
    expect(mechanic.photoBytes, [1, 2, 3, 4]);
  });
}
