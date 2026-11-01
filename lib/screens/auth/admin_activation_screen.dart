import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/local_workshop_admin_store.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/networking/api_client.dart';
import '../../core/security/password_policy.dart';
import '../../core/tenant/tenant_context.dart';
import '../admin_customization/admin_customization_screen.dart';

class AdminActivationScreen extends StatefulWidget {
  const AdminActivationScreen({
    super.key,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
    this.existingGoogleAccount = false,
  });

  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;
  final bool existingGoogleAccount;

  @override
  State<AdminActivationScreen> createState() => _AdminActivationScreenState();
}

class _AdminActivationScreenState extends State<AdminActivationScreen> {
  static const _accent = Color(0xFFFF6500);
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _localStore = LocalWorkshopAdminStore();

  bool _accepted = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingGoogleAccount) {
      final user = AuthService().currentUser;
      final metadata = user?.userMetadata;
      _name.text = (metadata?['full_name'] ?? metadata?['name'] ?? '')
          .toString();
      _email.text = user?.email ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canActivate => !_loading && _accepted;

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
              colors: [Color(0x85000000), Color(0x52000000), Color(0xB8000000)],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
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
                        const _ActivationMark(),
                        const SizedBox(height: 16),
                        const Text(
                          'Crear cuenta de administrador',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.existingGoogleAccount
                              ? 'Completa tus datos para iniciar la prueba gratuita de 3 días.'
                              : 'Crea tus credenciales personales. Tu prueba gratuita comienza al terminar el registro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFC7C9CC),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: .09),
                            border: Border.all(
                              color: _accent.withValues(alpha: .55),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.schedule_rounded, color: _accent),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '3 días de acceso gratis.',
                                  style: TextStyle(fontSize: 12, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _SectionTitle('Datos del administrador'),
                        const SizedBox(height: 12),
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
                          controller: _phone,
                          label: 'Número de celular',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              value == null ||
                                  value.replaceAll(RegExp(r'\D'), '').length < 7
                              ? 'Ingresa un número válido.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _email,
                          label: 'Correo electrónico',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          readOnly: widget.existingGoogleAccount,
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Ingresa un correo válido.'
                              : null,
                        ),
                        if (!widget.existingGoogleAccount) ...[
                          const SizedBox(height: 12),
                          _passwordField(
                            controller: _password,
                            label: 'Contraseña',
                            obscure: _obscurePassword,
                            onToggle: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _passwordField(
                            controller: _confirmation,
                            label: 'Confirmar contraseña',
                            obscure: _obscureConfirmation,
                            confirmation: true,
                            onToggle: () => setState(
                              () =>
                                  _obscureConfirmation = !_obscureConfirmation,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          value: _accepted,
                          onChanged: (value) =>
                              setState(() => _accepted = value ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: _accent,
                          title: const Text(
                            'Acepto los términos y la política de privacidad.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          _ActivationError(message: _error!),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _canActivate ? _activate : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: _loading
                                ? const SizedBox.square(
                                    dimension: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.verified_user_outlined),
                            label: Text(
                              widget.existingGoogleAccount
                                  ? 'Crear cuenta y comenzar prueba'
                                  : 'Crear cuenta y comenzar prueba',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Volver al acceso administrador'),
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
    bool readOnly = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    readOnly: readOnly,
    decoration: _decoration(label: label, icon: icon),
  );

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    bool confirmation = false,
  }) => TextFormField(
    controller: controller,
    obscureText: obscure,
    validator: (value) {
      final policyError = validateStrongPassword(value);
      if (policyError != null) return policyError;
      if (confirmation && value != _password.text) {
        return 'Las contraseñas no coinciden.';
      }
      return null;
    },
    decoration: _decoration(label: label, icon: Icons.lock_outline_rounded)
        .copyWith(
          suffixIcon: IconButton(
            tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
            onPressed: onToggle,
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
  );

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    bool highlighted = false,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: highlighted ? _accent : null),
    filled: true,
    fillColor: highlighted ? const Color(0xFF2B211B) : const Color(0xFF25272C),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: highlighted ? _accent : const Color(0xFF50535A),
      ),
    ),
  );

  Future<void> _activate() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Debes aceptar los términos para continuar.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final password = widget.existingGoogleAccount
          ? '${_email.text.trim()}-${DateTime.now().millisecondsSinceEpoch}'
          : _password.text;
      if (ApiClient.cloudEnabled && !widget.existingGoogleAccount) {
        final response = await AuthService().signUp(
          email: _email.text,
          password: password,
          fullName: _name.text,
          phone: _phone.text,
          department: '',
          city: '',
          accountType: 'admin',
        );
        if (response.session == null) {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirma tu correo'),
              content: Text(
                'Enviamos un enlace a ${_email.text.trim()}. Confírmalo y luego inicia sesión para configurar tu taller.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
      if (ApiClient.cloudEnabled && widget.existingGoogleAccount) {
        await AuthService().updateProfileMetadata(
          accountType: 'admin',
          fullName: _name.text,
          phone: _phone.text,
          department: '',
          city: '',
        );
      }
      final registrationError = await _localStore.register(
        password: password,
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
      );
      if (registrationError != null) throw StateError(registrationError);
      await widget.tenantContext.clear();
      widget.brandController.value = WorkshopBrand.newWorkshop;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminCustomizationScreen(
            brandController: widget.brandController,
            authController: widget.authController,
            tenantContext: widget.tenantContext,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _ActivationMark extends StatelessWidget {
  const _ActivationMark();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF6500).withValues(alpha: .12),
        border: Border.all(color: const Color(0xFFFF6500), width: 2),
      ),
      child: const Icon(
        Icons.person_add_alt_1_rounded,
        color: Color(0xFFFF6500),
        size: 34,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  );
}

class _ActivationError extends StatelessWidget {
  const _ActivationError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x22FF5252),
      border: Border.all(color: const Color(0xFFFF6B6B)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8C8C)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFFFC7C7)),
          ),
        ),
      ],
    ),
  );
}
