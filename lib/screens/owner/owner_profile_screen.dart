import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/tenant/tenant_context.dart';
import 'owner_dashboard_screen.dart';

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({
    super.key,
    required this.authController,
    required this.tenantContext,
    required this.brandController,
  });

  final AdminAuthController authController;
  final TenantContext tenantContext;
  final WorkshopBrandController brandController;

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  static const _accent = Color(0xFFFF6500);
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _document = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.authController.fullName;
    _document.text = widget.authController.document;
    _email.text = widget.authController.email;
    _phone.text = widget.authController.phone;
  }

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
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
              colors: [Color(0x88000000), Color(0x56000000), Color(0xC0000000)],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xF51A1C20),
                    border: Border.all(color: _accent),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xA8000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _OwnerMark(),
                        const SizedBox(height: 16),
                        Text(
                          widget.authController.hasOwnerProfile
                              ? 'Perfil del propietario'
                              : 'Registro del propietario',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Estos datos protegerán tu cuenta y permitirán recuperar el acceso por correo o celular.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFC7C9CC),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25272C),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF50535A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.badge_outlined, color: _accent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Usuario propietario',
                                      style: TextStyle(
                                        color: Color(0xFFBFC1C5),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      widget.authController.username,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.verified_user_outlined,
                                color: _accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _field(
                          controller: _name,
                          label: 'Nombre completo',
                          icon: Icons.person_outline_rounded,
                          validator: (value) =>
                              value == null || value.trim().length < 3
                              ? 'Ingresa tu nombre completo.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _document,
                          label: 'Documento de identidad (opcional)',
                          icon: Icons.assignment_ind_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (_) => null,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _email,
                          label: 'Correo de recuperación',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Ingresa un correo válido.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _phone,
                          label: 'Celular de recuperación',
                          icon: Icons.phone_android_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ]'),
                            ),
                          ],
                          validator: (value) =>
                              value == null ||
                                  value.replaceAll(RegExp(r'\D'), '').length < 7
                              ? 'Ingresa un celular válido.'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFF8C8C)),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              widget.authController.hasOwnerProfile
                                  ? 'Guardar cambios'
                                  : 'Guardar perfil del propietario',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Cerrar sesión'),
                        ),
                      ],
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFF25272C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF50535A)),
      ),
    ),
  );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.authController.saveOwnerProfile(
      fullName: _name.text,
      document: _document.text,
      email: _email.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil del propietario guardado correctamente.'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OwnerDashboardScreen(
            authController: widget.authController,
            tenantContext: widget.tenantContext,
            brandController: widget.brandController,
          ),
        ),
      );
    }
  }
}

class _OwnerMark extends StatelessWidget {
  const _OwnerMark();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF6500).withValues(alpha: .12),
        border: Border.all(color: const Color(0xFFFF6500), width: 2),
      ),
      child: const Icon(
        Icons.workspace_premium_outlined,
        color: Color(0xFFFF6500),
        size: 36,
      ),
    ),
  );
}
