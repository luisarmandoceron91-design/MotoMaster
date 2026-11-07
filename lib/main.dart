import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/auth/admin_auth_controller.dart';
import 'core/branding/workshop_brand.dart';
import 'core/tenant/tenant_context.dart';
import 'core/networking/api_client.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  await apiClient.init();

  final tenantContext = TenantContext();
  final brandController = WorkshopBrandController();
  final authController = AdminAuthController();

  await tenantContext.load();
  await brandController.load(tenantContext.currentTenantId);
  await authController.load();
  await authController.restoreOwnerProfileFromCloud();

  runApp(
    MotoMasterApp(
      tenantContext: tenantContext,
      brandController: brandController,
      authController: authController,
    ),
  );
}

class MotoMasterApp extends StatefulWidget {
  const MotoMasterApp({
    super.key,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
  });

  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<MotoMasterApp> createState() => _MotoMasterAppState();
}

class _MotoMasterAppState extends State<MotoMasterApp> {
  @override
  void dispose() {
    widget.tenantContext.dispose();
    widget.brandController.dispose();
    widget.authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moto Master',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6A00),
          secondary: Color(0xFFFF6A00),
          surface: Color(0xFF111111),
        ),
      ),
      home: SplashScreen(
        tenantContext: widget.tenantContext,
        brandController: widget.brandController,
        authController: widget.authController,
      ),
    );
  }
}
