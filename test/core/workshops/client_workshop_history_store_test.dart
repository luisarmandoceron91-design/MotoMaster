import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/workshops/client_workshop_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'quitar un taller lo elimina del historial y lo mantiene oculto',
    () async {
      final store = ClientWorkshopHistoryStore();
      const email = 'cliente@ejemplo.com';

      await store.remember(email, 'taller-1');
      await store.remove(email, 'taller-1');
      await store.hide(email, 'taller-1');

      expect(await store.list(email), isEmpty);
      expect(await store.listHidden(email), contains('taller-1'));
    },
  );

  test('ocultar dos veces no duplica el registro', () async {
    final store = ClientWorkshopHistoryStore();
    const email = 'cliente@ejemplo.com';

    await store.hide(email, 'taller-1');
    await store.hide(email, 'taller-1');

    expect(await store.listHidden(email), ['taller-1']);
  });
}
