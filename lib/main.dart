import 'core/auth/admin_auth_controller.dart';
import 'package:flutter/material.dart';

import 'core/branding/workshop_brand.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final brandController = WorkshopBrandController();
  final authController = AdminAuthController();
  await Future.wait([brandController.load(), authController.load()]);
  runApp(
    MotoMasterApp(
      brandController: brandController,
      authController: authController,
    ),
  );
}

class MotoMasterApp extends StatefulWidget {
  const MotoMasterApp({
    super.key,
    required this.brandController,
    required this.authController,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<MotoMasterApp> createState() => _MotoMasterAppState();
}

class _MotoMasterAppState extends State<MotoMasterApp> {
  @override
  void dispose() {
    widget.brandController.dispose();
    widget.authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moto Master',
      debugShowCheckedModeBanner: false,
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
        brandController: widget.brandController,
        authController: widget.authController,
      ),
    );
  }
}
