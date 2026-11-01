import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/auth/admin_auth_controller.dart';
import 'package:moto_master/core/branding/workshop_brand.dart';
import 'package:moto_master/core/networking/api_client.dart';
import 'package:moto_master/core/tenant/tenant_context.dart';
import 'package:moto_master/screens/owner/owner_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el menu del centro de control no desborda en pantalla baja', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient().init();
    tester.view.physicalSize = const Size(704, 584);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AdminAuthController();
    await auth.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: OwnerDashboardScreen(
          authController: auth,
          tenantContext: TenantContext(),
          brandController: WorkshopBrandController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('CONTROL'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pump(const Duration(seconds: 51));
    await tester.pump(const Duration(seconds: 7));
  });
}
