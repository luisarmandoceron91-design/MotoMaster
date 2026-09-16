import 'package:flutter/material.dart';

import '../../core/branding/workshop_brand.dart';

class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key, required this.brand});

  final WorkshopBrand brand;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF151619),
        title: Text(brand.name),
        actions: [
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
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101114), Color(0xFF202226)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Servicios para tu moto',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenido a ${brand.name}',
                      style: TextStyle(fontSize: 17, color: brand.accentColor),
                    ),
                    const SizedBox(height: 28),
                    _ClientAction(
                      icon: Icons.calendar_today_outlined,
                      title: 'Agendar servicio',
                      subtitle: 'Reserva una cita en pocos pasos',
                      accent: brand.accentColor,
                    ),
                    const SizedBox(height: 14),
                    _ClientAction(
                      icon: Icons.two_wheeler_outlined,
                      title: 'Mis servicios',
                      subtitle: 'Consulta el estado de tu motocicleta',
                      accent: brand.accentColor,
                    ),
                    const SizedBox(height: 14),
                    _ClientAction(
                      icon: Icons.receipt_long_outlined,
                      title: 'Historial',
                      subtitle: 'Revisa mantenimientos y facturas',
                      accent: brand.accentColor,
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

class _ClientAction extends StatelessWidget {
  const _ClientAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF202226),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {},
      ),
    );
  }
}
