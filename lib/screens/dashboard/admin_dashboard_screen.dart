import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../settings/credential_settings_screen.dart';

/// Base temporal del panel administrativo. La autenticación real debe
/// reemplazar la validación visual del formulario por el servicio de backend.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.brandController,
    required this.authController,
    required this.userName,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController authController;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkshopBrand>(
      valueListenable: brandController,
      builder: (context, brand, _) => _DashboardScaffold(
        brand: brand,
        title: 'Panel administrativo',
        greeting: 'Hola, $userName',
        authController: authController,
        items: const [
          (
            Icons.calendar_month_outlined,
            'Agenda',
            'Organiza tus citas y servicios',
          ),
          (Icons.groups_2_outlined, 'Equipo', 'Administra técnicos y permisos'),
          (
            Icons.inventory_2_outlined,
            'Inventario',
            'Controla repuestos y existencias',
          ),
          (
            Icons.insights_outlined,
            'Reportes',
            'Consulta el rendimiento del taller',
          ),
        ],
      ),
    );
  }
}

class _DashboardScaffold extends StatelessWidget {
  const _DashboardScaffold({
    required this.brand,
    required this.title,
    required this.greeting,
    required this.authController,
    required this.items,
  });

  final WorkshopBrand brand;
  final String title;
  final String greeting;
  final AdminAuthController authController;
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF151619),
        title: Text(brand.name),
        actions: [
          IconButton(
            tooltip: 'Configuración de acceso',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CredentialSettingsScreen(
                  authController: authController,
                  brand: brand,
                ),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: SizedBox(
              width: 30,
              height: 30,
              child: brand.hasCustomLogo
                  ? ClipOval(
                      child: Image.memory(
                        brand.customLogoBytes!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(brand.logoIcon, color: brand.accentColor),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101114), Color(0xFF202226)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      greeting,
                      style: TextStyle(fontSize: 17, color: brand.accentColor),
                    ),
                    const SizedBox(height: 28),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth >= 680 ? 4 : 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: constraints.maxWidth >= 680
                            ? 1.35
                            : .92,
                      ),
                      itemBuilder: (_, index) => Card(
                        color: const Color(0xFF202226),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                items[index].$1,
                                color: brand.accentColor,
                                size: 32,
                              ),
                              const Spacer(),
                              Text(
                                items[index].$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                items[index].$3,
                                style: const TextStyle(
                                  color: Color(0xFFCACACA),
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
