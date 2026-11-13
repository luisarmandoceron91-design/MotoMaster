import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/admin_access_service.dart';
import '../../core/auth/admin_oauth_intent_store.dart';
import '../../core/auth/auth_service.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/tenant/tenant_model.dart';
import '../../core/client/client_profile_repository.dart';
import '../../core/workshops/workshop_repository.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import '../access/role_access_screen.dart';
import '../auth/admin_login_screen.dart';
import '../auth/client_login_screen.dart';
import '../auth/new_password_screen.dart';
import '../workshop_selection/client_workshop_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
  });

  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rideController;
  late final Animation<double> _ride;

  @override
  void initState() {
    super.initState();
    _rideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
    _ride = CurvedAnimation(
      parent: _rideController,
      curve: Curves.easeInOutCubic,
    );
    _navigateToNext();
  }

  @override
  void dispose() {
    _rideController.dispose();
    super.dispose();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2700));
    if (!mounted) return;

    final pendingGoogle = await AdminOAuthIntentStore().pendingIntent();
    if (!mounted) return;
    final isPasswordRecovery =
        Uri.base.queryParameters['recovery'] == 'password';
    if (isPasswordRecovery && AuthService().isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NewPasswordScreen(
            onCompleted: (recoveryContext) {
              if (!mounted) return;
              Navigator.of(recoveryContext).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => _roleAccessScreen()),
                (_) => false,
              );
            },
          ),
        ),
      );
      return;
    }
    if (pendingGoogle == GoogleAccountIntent.administrator &&
        AuthService().isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminLoginScreen(
            tenantContext: widget.tenantContext,
            brandController: widget.brandController,
            authController: widget.authController,
            brand: widget.brandController.value,
            resumeGoogleSignIn: true,
          ),
        ),
      );
      return;
    }
    if (pendingGoogle == GoogleAccountIntent.client &&
        AuthService().isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ClientLoginScreen(
            tenantContext: widget.tenantContext,
            brandController: widget.brandController,
            authController: widget.authController,
            resumeGoogleSignIn: true,
          ),
        ),
      );
      return;
    }

    // Una recarga del navegador no debe obligar a autenticarse de nuevo.
    // Supabase conserva la sesión hasta que el usuario use Cerrar sesión.
    if (AuthService().isAuthenticated) {
      try {
        final role = await AdminAccessService().resolveRole();
        if (!mounted) return;
        if (role == AdminAccessRole.platformOwner) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => OwnerDashboardScreen(
                authController: widget.authController,
                tenantContext: widget.tenantContext,
                brandController: widget.brandController,
              ),
            ),
          );
          return;
        }
        if (role == AdminAccessRole.workshopOwner ||
            role == AdminAccessRole.workshopStaff) {
          // Una sesión puede reabrirse en otro computador con un tenant local
          // antiguo. El taller activo debe resolverse desde la membresía en la
          // nube, no desde SharedPreferences, para mostrar el mismo catálogo,
          // chat, equipo e inventario en todos los dispositivos.
          final managed = await WorkshopRepository().listManaged();
          if (managed.isEmpty) {
            throw StateError('No se encontró un taller administrativo activo.');
          }
          final currentId = widget.tenantContext.currentTenantId;
          final workshop = managed.firstWhere(
            (item) => item.id == currentId,
            orElse: () => managed.first,
          );
          await widget.tenantContext.setTenant(
            Tenant(tenantId: workshop.id, name: workshop.name),
          );
          widget.brandController.value = WorkshopBrand(
            name: workshop.name,
            tagline: workshop.tagline,
            logoIndex: workshop.logoIndex,
            accentColorValue: workshop.accentColorValue,
            customLogoBytes: workshop.logoBytes,
            customLogoFileName: workshop.logoFileName,
          );
          if (!mounted) return;
          final user = AuthService().currentUser;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => AdminDashboardScreen(
                brandController: widget.brandController,
                tenantContext: widget.tenantContext,
                userName: user?.userMetadata?['full_name']?.toString() ??
                    user?.email ??
                    'Administrador',
              ),
            ),
          );
          return;
        }
        final client = await ClientProfileRepository().getCurrentProfile();
        if (!mounted) return;
        if (client != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ClientWorkshopSelectionScreen(
                profile: client,
                tenantContext: widget.tenantContext,
                brandController: widget.brandController,
                authController: widget.authController,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Si la red está temporalmente caída, la pantalla de acceso conserva
        // las sesiones locales y permite reintentar sin borrar datos.
      }
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => _roleAccessScreen()));
  }

  RoleAccessScreen _roleAccessScreen() => RoleAccessScreen(
    tenantContext: widget.tenantContext,
    brandController: widget.brandController,
    authController: widget.authController,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            // Fondo panorámico del taller con las motos durante la carga.
            'assets/images/owner_service_bays_background_v1.png',
            fit: BoxFit.cover,
          ),
          const ColoredBox(color: Color(0xB3050709)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 150,
                        child: LayoutBuilder(
                          builder: (context, box) => AnimatedBuilder(
                            animation: _ride,
                            builder: (context, _) {
                              final progress = _ride.value;
                              final x =
                                  -100 + ((box.maxWidth + 200) * progress);
                              final y = math.sin(progress * math.pi * 8) * 2.5;
                              final edgeFade = (progress < .12)
                                  ? progress / .12
                                  : (progress > .88)
                                  ? (1 - progress) / .12
                                  : 1.0;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Transform.translate(
                                    offset: Offset(x - 58, 86 + y),
                                    child: Opacity(
                                      opacity: edgeFade.clamp(0, 1),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 2,
                                            color: const Color(0xFFFF6500),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: 34,
                                            height: 2,
                                            color: const Color(0x99FF6500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(x, 30 + y),
                                    child: Opacity(
                                      opacity: edgeFade.clamp(0, 1),
                                      child: const Icon(
                                        Icons.two_wheeler_rounded,
                                        size: 86,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xFFFF6500),
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _rideController,
                          curve: const Interval(.18, .7),
                        ),
                        child: const Text(
                          'GESTIÓN INTELIGENTE PARA TALLERES',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 190,
                        child: AnimatedBuilder(
                          animation: _rideController,
                          builder: (context, _) => LinearProgressIndicator(
                            value: _rideController.value,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(2),
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFFF6500),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
