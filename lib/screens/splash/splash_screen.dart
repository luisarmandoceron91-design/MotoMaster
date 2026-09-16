import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../access/role_access_screen.dart';

/// Pantalla 1: Splash universal de Moto Master.
/// La imagen visual es un recurso incluido dentro del propio proyecto.
/// No se redibuja ni se agregan elementos por código.
class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    required this.brandController,
    required this.authController,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  static const String _asset =
      'assets/images/moto_master_splash_aprobada_v1.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder<void>(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  FadeTransition(
                    opacity: animation,
                    child: RoleAccessScreen(
                      brandController: brandController,
                      authController: authController,
                    ),
                  ),
              transitionDuration: const Duration(milliseconds: 360),
            ),
          );
        },
        child: SizedBox.expand(
          child: Image.asset(
            _asset,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
