import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../auth/admin_login_screen.dart';
import '../dashboard/client_dashboard_screen.dart';
import 'theme_color_dialog.dart';

class RoleAccessScreen extends StatefulWidget {
  const RoleAccessScreen({
    super.key,
    required this.brandController,
    required this.authController,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<RoleAccessScreen> createState() => _RoleAccessScreenState();
}

class _RoleAccessScreenState extends State<RoleAccessScreen> {
  static const _backgroundAsset =
      'assets/images/workshop_login_background_v1.png';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorkshopBrand>(
      valueListenable: widget.brandController,
      builder: (context, brand, _) {
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(_backgroundAsset, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xBB000000),
                      Color(0x77000000),
                      Color(0xEB000000),
                    ],
                    stops: [0, .45, 1],
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 48 : 20,
                        16,
                        isWide ? 48 : 28,
                        28,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 44,
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: _CustomizeButton(
                                accentColor: brand.accentColor,
                                onPressed: () => _openCustomizer(brand),
                              ),
                            ),
                            SizedBox(height: isWide ? 16 : 8),
                            _BrandHero(brand: brand, compact: isWide),
                            const SizedBox(height: 26),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: _GlassAccessCard(
                                brand: brand,
                                onAdmin: () => _goToAdminLogin(brand),
                                onClient: () => _goToClientDashboard(brand),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToAdminLogin(WorkshopBrand brand) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminLoginScreen(
          brandController: widget.brandController,
          authController: widget.authController,
          brand: brand,
        ),
      ),
    );
  }

  void _goToClientDashboard(WorkshopBrand brand) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientDashboardScreen(brand: brand),
      ),
    );
  }

  Future<void> _openCustomizer(WorkshopBrand brand) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ThemeColorDialog(
        brand: brand,
        onSave: widget.brandController.updateAccentColor,
      ),
    );
  }
}

class _CustomizeButton extends StatelessWidget {
  const _CustomizeButton({required this.accentColor, required this.onPressed});

  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.palette_outlined, color: accentColor),
      label: const Text('Colores'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF7A7A7A)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.brand, required this.compact});

  final WorkshopBrand brand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BrandMark(brand: brand, diameter: compact ? 126 : 108),
        const SizedBox(height: 12),
        Text(
          brand.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 44 : 31,
            height: .98,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: brand.accentColor, blurRadius: 16)],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 42, height: 1, color: brand.accentColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                brand.tagline.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFE4E4E4),
                  fontSize: 13,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(width: 42, height: 1, color: brand.accentColor),
          ],
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.brand, required this.diameter});

  final WorkshopBrand brand;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xE6141517),
        border: Border.all(color: brand.accentColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: brand.accentColor.withValues(alpha: .55),
            blurRadius: 28,
          ),
        ],
      ),
      child: brand.hasCustomLogo
          ? ClipOval(
              child: Image.memory(
                brand.customLogoBytes!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            )
          : Icon(brand.logoIcon, color: Colors.white, size: diameter * .56),
    );
  }
}

class _GlassAccessCard extends StatelessWidget {
  const _GlassAccessCard({
    required this.brand,
    required this.onAdmin,
    required this.onClient,
  });

  final WorkshopBrand brand;
  final VoidCallback onAdmin;
  final VoidCallback onClient;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xC916171A),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xBFFFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 26,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Transform.translate(
                offset: const Offset(0, -62),
                child: _BrandMark(brand: brand, diameter: 86),
              ),
              Transform.translate(
                offset: const Offset(0, -50),
                child: Column(
                  children: [
                    const Text(
                      '¡Bienvenido a!',
                      style: TextStyle(color: Color(0xFFE7E7E7), fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      brand.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: brand.accentColor,
                        fontSize: 31,
                        height: 1,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Selecciona cómo deseas ingresar',
                      style: TextStyle(color: Color(0xFFE3E3E3), fontSize: 16),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Column(
                  children: [
                    _RoleButton(
                      accentColor: brand.accentColor,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'ADMINISTRADOR',
                      subtitle: 'Gestiona tu taller y equipo',
                      primary: true,
                      onTap: onAdmin,
                    ),
                    const SizedBox(height: 14),
                    _RoleButton(
                      accentColor: brand.accentColor,
                      icon: Icons.person_outline_rounded,
                      title: 'CLIENTE',
                      subtitle: 'Acceso rápido y servicios',
                      onTap: onClient,
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -12),
                child: _FeatureRow(accentColor: brand.accentColor),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: brand.accentColor),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'TU MOTO EN LAS MEJORES MANOS',
                      style: TextStyle(
                        color: Color(0xFFCECECE),
                        fontSize: 10,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: brand.accentColor),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    required this.onTap,
    this.primary = false,
  });

  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
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
            height: 112,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: primary ? accentColor : const Color(0xFF929292),
              ),
              gradient: primary
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF201710),
                        accentColor.withValues(alpha: .92),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xD7232528), Color(0xB8232528)],
                    ),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: .32),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: primary ? accentColor : const Color(0xFF7B7B7B),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: primary ? accentColor : Colors.white,
                    size: 39,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFE1E1E1),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 38,
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
  const _FeatureRow({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.lock_outline_rounded, 'SEGURIDAD', 'Tus datos protegidos'),
      (Icons.verified_outlined, 'CONFIANZA', 'Servicio profesional'),
      (Icons.workspace_premium_outlined, 'CALIDAD', 'Repuestos originales'),
    ];
    return Row(
      children: [
        for (var index = 0; index < features.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor),
                  ),
                  child: Icon(features[index].$1, color: accentColor, size: 25),
                ),
                const SizedBox(height: 8),
                Text(
                  features[index].$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  features[index].$3,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCDCDCD),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (index != features.length - 1)
            Container(width: 1, height: 66, color: const Color(0xFF626262)),
        ],
      ],
    );
  }
}

class _BrandCustomizationDialog extends StatefulWidget {
  const _BrandCustomizationDialog({required this.brand, required this.onSave});

  final WorkshopBrand brand;
  final void Function({
    required String name,
    required String tagline,
    required int logoIndex,
    required int accentColorValue,
  })
  onSave;

  @override
  State<_BrandCustomizationDialog> createState() =>
      _BrandCustomizationDialogState();
}

class _BrandCustomizationDialogState extends State<_BrandCustomizationDialog> {
  static const _colors = [
    0xFFFF6200,
    0xFF00B8D9,
    0xFF8E5BFF,
    0xFF20C77A,
    0xFFE83E8C,
  ];
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late int _logoIndex;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.brand.name);
    _taglineController = TextEditingController(text: widget.brand.tagline);
    _logoIndex = widget.brand.logoIndex;
    _colorValue = widget.brand.accentColorValue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_colorValue);
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1B1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Personaliza tu taller'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogField(
                controller: _nameController,
                label: 'Nombre del negocio',
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 16),
              _DialogField(
                controller: _taglineController,
                label: 'Descripción corta',
                icon: Icons.short_text_rounded,
              ),
              const SizedBox(height: 22),
              const Text(
                'Logo del taller',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (
                    var index = 0;
                    index < workshopLogoOptions.length;
                    index++
                  )
                    ChoiceChip(
                      label: Icon(
                        workshopLogoOptions[index],
                        color: _logoIndex == index
                            ? Colors.white
                            : const Color(0xFFBDBDBD),
                      ),
                      selected: _logoIndex == index,
                      selectedColor: accent,
                      backgroundColor: const Color(0xFF282A2E),
                      onSelected: (_) => setState(() => _logoIndex = index),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Color principal',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  for (final colorValue in _colors)
                    InkWell(
                      onTap: () => setState(() => _colorValue = colorValue),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorValue == colorValue
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _colorValue == colorValue
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Los cambios se reflejan inmediatamente en esta sesión. Conecta este controlador al perfil del tenant para guardarlos en tu backend.',
                style: TextStyle(
                  color: Color(0xFFBABABA),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () {
            widget.onSave(
              name: _nameController.text,
              tagline: _taglineController.text,
              logoIndex: _logoIndex,
              accentColorValue: _colorValue,
            );
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(backgroundColor: accent),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF25272B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
