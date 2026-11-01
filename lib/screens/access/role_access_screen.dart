import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/client/client_profile.dart';
import '../../core/client/client_profile_repository.dart';
import '../../core/client/local_client_profile_store.dart';
import '../../core/networking/api_client.dart';
import '../../core/tenant/tenant_context.dart';
import '../auth/admin_login_screen.dart';
import '../auth/client_login_screen.dart';
import '../workshop_selection/client_workshop_selection_screen.dart';

class RoleAccessScreen extends StatefulWidget {
  const RoleAccessScreen({
    super.key,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
  });

  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<RoleAccessScreen> createState() => _RoleAccessScreenState();
}

class _RoleAccessScreenState extends State<RoleAccessScreen> {
  static const _backgroundAsset =
      'assets/images/workshop_login_background_v1.png';
  static const _accent = Color(0xFFFF5A00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x36000000),
                  Color(0xA6000000),
                ],
                stops: [0, .5, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                final isShort = constraints.maxHeight < 760;
                final useCompactLayout = !isWide || isShort;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 36 : 18,
                    vertical: useCompactLayout ? 16 : 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isWide ? 64 : 44),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: useCompactLayout ? 620 : 700,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: useCompactLayout ? 52 : 62,
                          ),
                          child: _NeutralAccessCard(
                            accentColor: _accent,
                            compact: useCompactLayout,
                            onAdmin: _goToAdminLogin,
                            onClient: _goToClientAccess,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _goToAdminLogin() {
    final brand = widget.brandController.value;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminLoginScreen(
          brandController: widget.brandController,
          authController: widget.authController,
          brand: brand,
          tenantContext: widget.tenantContext,
        ),
      ),
    );
  }

  Future<void> _goToClientAccess() async {
    final auth = AuthService();
    final localProfiles = LocalClientProfileStore();
    final user = auth.currentUser;
    ClientProfile? profile;
    if (user != null) {
      final accountType = user.userMetadata?['account_type']?.toString();
      if (accountType == 'client') {
        profile = await ClientProfileRepository().getCurrentProfile();
      } else {
        // Cambiar de portal tambien cambia de identidad. Una sesion de taller
        // nunca puede convertirse implicitamente en un perfil de cliente.
        await auth.signOut();
        await localProfiles.signOut();
      }
    } else if (!ApiClient.cloudEnabled) {
      profile = await localProfiles.loadActive();
    }
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => profile == null
            ? ClientLoginScreen(
                tenantContext: widget.tenantContext,
                brandController: widget.brandController,
                authController: widget.authController,
              )
            : ClientWorkshopSelectionScreen(
                profile: profile,
                tenantContext: widget.tenantContext,
                brandController: widget.brandController,
                authController: widget.authController,
              ),
      ),
    );
  }
}

class _NeutralAccessCard extends StatelessWidget {
  const _NeutralAccessCard({
    required this.accentColor,
    required this.compact,
    required this.onAdmin,
    required this.onClient,
  });

  final Color accentColor;
  final bool compact;
  final VoidCallback onAdmin;
  final VoidCallback onClient;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 18.0 : 30.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 25 : 32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                compact ? 76 : 84,
                horizontalPadding,
                compact ? 24 : 34,
              ),
              decoration: BoxDecoration(
                color: const Color(0xD9141518),
                borderRadius: BorderRadius.circular(compact ? 25 : 32),
                border: Border.all(color: const Color(0xBFE5E5E5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 34,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '¡Bienvenido!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 32 : 42,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 22),
                  Text(
                    'Selecciona cómo deseas ingresar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFF0F0F0),
                      fontSize: compact ? 17 : 23,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: compact ? 28 : 34),
                  _RoleButton(
                    accentColor: accentColor,
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'ADMINISTRADOR',
                    subtitle: 'Gestiona tu negocio',
                    primary: true,
                    compact: compact,
                    onTap: onAdmin,
                  ),
                  const SizedBox(height: 16),
                  _RoleButton(
                    accentColor: accentColor,
                    icon: Icons.person_outline_rounded,
                    title: 'CLIENTE',
                    subtitle: 'Accede a servicios',
                    compact: compact,
                    onTap: onClient,
                  ),
                  SizedBox(height: compact ? 22 : 28),
                  _FeatureRow(accentColor: accentColor, compact: compact),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: compact ? -56 : -66,
          child: _PlatformMark(
            accentColor: accentColor,
            diameter: compact ? 112 : 132,
          ),
        ),
      ],
    );
  }
}

class _PlatformMark extends StatelessWidget {
  const _PlatformMark({required this.accentColor, required this.diameter});

  final Color accentColor;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xF51B1C20),
        border: Border.all(color: accentColor, width: 3),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: .42), blurRadius: 28),
          const BoxShadow(
            color: Color(0x88000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.build_circle_outlined,
        color: Colors.white,
        size: diameter * .58,
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.onTap,
    this.primary = false,
  });

  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ingresar como $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: compact ? 98 : 120,
            padding: EdgeInsets.all(compact ? 12 : 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: primary ? accentColor : const Color(0xFF85878B),
              ),
              gradient: primary
                  ? const LinearGradient(
                      colors: [Color(0xFF22170F), Color(0xFFFF5A00)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xE52A2C30), Color(0xD1212327)],
                    ),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: .22),
                        blurRadius: 20,
                        offset: const Offset(0, 9),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 66 : 84,
                  height: compact ? 66 : 84,
                  decoration: BoxDecoration(
                    color: const Color(0x800B0C0E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: primary ? accentColor : const Color(0xFF73767B),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: primary ? accentColor : Colors.white,
                    size: compact ? 34 : 42,
                  ),
                ),
                SizedBox(width: compact ? 16 : 26),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 18 : 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFE6E6E6),
                          fontSize: compact ? 14 : 17,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: compact ? 34 : 42,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.accentColor, required this.compact});

  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.lock_outline_rounded, 'SEGURIDAD'),
      (Icons.verified_outlined, 'CONFIANZA'),
      (Icons.workspace_premium_outlined, 'CALIDAD'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < features.length; index++) ...[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 46 : 58,
                  height: compact ? 46 : 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor, width: 1.5),
                  ),
                  child: Icon(
                    features[index].$1,
                    color: accentColor,
                    size: compact ? 24 : 29,
                  ),
                ),
                const SizedBox(height: 9),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    features[index].$2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 10 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (index != features.length - 1)
            Container(
              width: 1,
              height: compact ? 62 : 74,
              color: const Color(0xFF686A6D),
            ),
        ],
      ],
    );
  }
}
