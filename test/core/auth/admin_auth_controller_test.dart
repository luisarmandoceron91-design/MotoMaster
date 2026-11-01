import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/auth/admin_auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists owner security, formats and appearance', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AdminAuthController();
    await controller.load();

    final presentationError = await controller.saveOwnerPresentation(
      fullName: 'Luis Armando Cerón',
      document: '1234567890',
      email: 'luis@example.com',
      phone: '+57 300 123 4567',
      professionalTitle: 'Arquitecto y desarrollador',
      publicContact: 'luis@example.com',
      documentCreditEnabled: true,
      twoFactorEnabled: false,
      documentFormats: const ['PDF', 'Correo'],
    );
    final appearanceError = await controller.saveOwnerAppearance(
      accentColorValue: 0xFF2979FF,
      textScale: 1.2,
      backgroundEnabled: true,
      backgroundOpacity: .8,
      compactMode: true,
    );

    expect(presentationError, isNull);
    expect(appearanceError, isNull);

    final restored = AdminAuthController();
    await restored.load();

    expect(restored.ownerTwoFactorEnabled, isFalse);
    expect(restored.ownerDocumentFormats, ['PDF', 'Correo']);
    expect(restored.ownerAccentColorValue, 0xFF2979FF);
    expect(restored.ownerTextScale, 1.2);
    expect(restored.ownerBackgroundOpacity, .8);
    expect(restored.ownerCompactMode, isTrue);
  });
}
