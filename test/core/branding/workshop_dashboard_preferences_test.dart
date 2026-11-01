import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/branding/workshop_dashboard_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cada taller conserva su propia apariencia del dashboard', () async {
    const store = WorkshopDashboardPreferencesStore();
    await store.save(
      'taller-uno',
      const WorkshopDashboardPreferences(
        textScale: 1.2,
        brightness: .8,
        compactMode: true,
      ),
    );
    await store.save(
      'taller-dos',
      const WorkshopDashboardPreferences(textScale: .9, brightness: 1.1),
    );

    final first = await store.load('taller-uno');
    final second = await store.load('taller-dos');

    expect(first.textScale, 1.2);
    expect(first.brightness, .8);
    expect(first.compactMode, isTrue);
    expect(second.textScale, .9);
    expect(second.brightness, 1.1);
    expect(second.compactMode, isFalse);
  });
}
