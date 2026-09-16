import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../dashboard/admin_dashboard_screen.dart';

/// Personalización protegida: solo se muestra después de validar la sesión del
/// administrador del taller.
class AdminCustomizationScreen extends StatefulWidget {
  const AdminCustomizationScreen({
    super.key,
    required this.brandController,
    required this.authController,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<AdminCustomizationScreen> createState() =>
      _AdminCustomizationScreenState();
}

class _AdminCustomizationScreenState extends State<AdminCustomizationScreen> {
  static const _colors = [
    0xFFFF6200,
    0xFF00B8D9,
    0xFF8E5BFF,
    0xFF20C77A,
    0xFFE83E8C,
  ];
  static const _maxLogoBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late int _logoIndex;
  late int _colorValue;
  Uint8List? _logoBytes;
  String? _logoFileName;
  bool _isPickingLogo = false;

  @override
  void initState() {
    super.initState();
    final brand = widget.brandController.value;
    _nameController = TextEditingController(text: brand.name);
    _taglineController = TextEditingController(text: brand.tagline);
    _logoIndex = brand.logoIndex;
    _colorValue = brand.accentColorValue;
    _logoBytes = brand.customLogoBytes;
    _logoFileName = brand.customLogoFileName;
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/workshop_login_background_v1.png',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE8000000), Color(0xC9000000)],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth >= 800 ? 48 : 20,
                  18,
                  constraints.maxWidth >= 800 ? 48 : 20,
                  32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 50,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: const Color(0xE8191A1E),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: accent.withValues(alpha: .75),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 28,
                                  offset: Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Volver',
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Personaliza tu taller',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Configura la identidad que verán tus clientes.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: .72,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _AdminPill(accent: accent),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  LayoutBuilder(
                                    builder: (context, layout) {
                                      final wide = layout.maxWidth >= 720;
                                      final details = _detailsForm(
                                        accent: accent,
                                      );
                                      final identity = _identityPicker(
                                        accent: accent,
                                      );
                                      return wide
                                          ? Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: details),
                                                const SizedBox(width: 28),
                                                Expanded(child: identity),
                                              ],
                                            )
                                          : Column(
                                              children: [
                                                details,
                                                const SizedBox(height: 28),
                                                identity,
                                              ],
                                            );
                                    },
                                  ),
                                  const SizedBox(height: 28),
                                  _LivePreview(accent: accent),
                                  const SizedBox(height: 28),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: _continueWithoutSaving,
                                        child: const Text('Omitir por ahora'),
                                      ),
                                      const Spacer(),
                                      FilledButton.icon(
                                        onPressed: _saveAndContinue,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: accent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 16,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle_outline_rounded,
                                        ),
                                        label: const Text(
                                          'Guardar y continuar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsForm({required Color accent}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          icon: Icons.storefront_outlined,
          title: 'Datos del negocio',
        ),
        const SizedBox(height: 16),
        _BrandTextField(
          controller: _nameController,
          label: 'Nombre del taller',
          icon: Icons.storefront_outlined,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Ingresa el nombre de tu taller.'
              : null,
        ),
        const SizedBox(height: 16),
        _BrandTextField(
          controller: _taglineController,
          label: 'Descripción corta',
          icon: Icons.short_text_rounded,
        ),
        const SizedBox(height: 24),
        const _SectionLabel(
          icon: Icons.palette_outlined,
          title: 'Color principal',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final colorValue in _colors)
              _ColorChoice(
                colorValue: colorValue,
                selected: _colorValue == colorValue,
                onTap: () => setState(() => _colorValue = colorValue),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Este color se aplica a botones, bordes y elementos destacados.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .58),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _identityPicker({required Color accent}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          icon: Icons.image_outlined,
          title: 'Logo del taller',
        ),
        const SizedBox(height: 16),
        Center(
          child: _LogoPreview(
            accent: accent,
            logoBytes: _logoBytes,
            icon: workshopLogoOptions[_logoIndex],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isPickingLogo ? null : _pickLogo,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _isPickingLogo
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: Text(
              _isPickingLogo
                  ? 'Abriendo archivos...'
                  : 'Cargar logo desde archivos',
            ),
          ),
        ),
        if (_logoFileName != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _logoFileName!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'O elige uno de los logos incluidos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < workshopLogoOptions.length; index++)
              ChoiceChip(
                label: Icon(
                  workshopLogoOptions[index],
                  color: _logoIndex == index
                      ? Colors.white
                      : const Color(0xFFC4C4C4),
                ),
                selected: _logoIndex == index && _logoBytes == null,
                selectedColor: accent,
                backgroundColor: const Color(0xFF292B30),
                onSelected: (_) => setState(() {
                  _logoIndex = index;
                  _logoBytes = null;
                  _logoFileName = null;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickLogo() async {
    setState(() => _isPickingLogo = true);
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || selection == null) return;
      final file = selection.files.single;
      if (file.bytes == null) {
        _showMessage(
          'No fue posible leer el logo seleccionado. Intenta nuevamente.',
        );
        return;
      }
      if (file.bytes!.lengthInBytes > _maxLogoBytes) {
        _showMessage('El logo debe pesar menos de 5 MB.');
        return;
      }
      setState(() {
        _logoBytes = file.bytes;
        _logoFileName = file.name;
      });
    } catch (_) {
      if (mounted) _showMessage('No se pudo abrir el selector de archivos.');
    } finally {
      if (mounted) setState(() => _isPickingLogo = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.brandController.updateBrand(
      name: _nameController.text,
      tagline: _taglineController.text,
      logoIndex: _logoIndex,
      accentColorValue: _colorValue,
      customLogoBytes: _logoBytes,
      customLogoFileName: _logoFileName,
      clearCustomLogo: _logoBytes == null,
    );
    _openDashboard();
  }

  void _continueWithoutSaving() => _openDashboard();

  void _openDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminDashboardScreen(
          brandController: widget.brandController,
          authController: widget.authController,
          userName: widget.authController.username,
        ),
      ),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _AdminPill extends StatelessWidget {
  const _AdminPill({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_outlined, color: accent, size: 18),
        const SizedBox(width: 6),
        const Text(
          'Administrador',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 9),
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _BrandTextField extends StatelessWidget {
  const _BrandTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    textCapitalization: TextCapitalization.words,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFF292B30),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });
  final int colorValue;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: 3,
        ),
      ),
      child: selected ? const Icon(Icons.check, color: Colors.white) : null,
    ),
  );
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.accent,
    required this.logoBytes,
    required this.icon,
  });
  final Color accent;
  final Uint8List? logoBytes;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 112,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF121317),
      border: Border.all(color: accent, width: 2),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: .40), blurRadius: 20),
      ],
    ),
    child: ClipOval(
      child: logoBytes == null
          ? Icon(icon, color: Colors.white, size: 55)
          : Image.memory(logoBytes!, fit: BoxFit.cover),
    ),
  );
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xA6111215),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 48,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vista previa',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'Los cambios se aplicarán a la bienvenida y al panel.',
                style: TextStyle(color: Color(0xFFCFCFCF), fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.visibility_outlined, color: accent),
      ],
    ),
  );
}
