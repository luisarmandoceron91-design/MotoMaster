import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../admin_customization/admin_customization_screen.dart';
import 'password_recovery_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.brandController,
    required this.authController,
    required this.brand,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController authController;
  final WorkshopBrand brand;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _loginError;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.brand.accentColor;
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
                colors: [Color(0xE6000000), Color(0xCE000000)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xF01B1C20),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: accent.withValues(alpha: .9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xA8000000),
                          blurRadius: 32,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SecurityMark(accent: accent),
                          const SizedBox(height: 18),
                          const Text(
                            'Acceso administrador',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.brand.name,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.25,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _LoginField(
                            controller: _userController,
                            label: 'Usuario o correo',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => _clearLoginError(),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Ingresa tu usuario o correo.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _LoginField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _signIn(),
                            onChanged: (_) => _clearLoginError(),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Ingresa tu contraseña.'
                                : null,
                            suffix: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openPasswordRecovery,
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                              ),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          if (_loginError != null) ...[
                            _LoginError(message: _loginError!),
                            const SizedBox(height: 14),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: _signIn,
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.login_rounded),
                              label: const Text(
                                'Ingresar al panel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _LoginDivider(),
                          const SizedBox(height: 20),
                          _GoogleButton(onPressed: _showGoogleSetup),
                          AnimatedBuilder(
                            animation: widget.authController,
                            builder: (context, _) {
                              if (!widget
                                  .authController
                                  .isUsingInitialCredentials) {
                                return const SizedBox(height: 10);
                              }
                              return Column(
                                children: [
                                  const SizedBox(height: 22),
                                  _InitialAccessHint(accent: accent),
                                  const SizedBox(height: 14),
                                ],
                              );
                            },
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text('Volver a tipos de acceso'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFE9E9E9),
                            ),
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
  }

  void _clearLoginError() {
    if (_loginError != null) setState(() => _loginError = null);
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    final isValid = widget.authController.authenticate(
      username: _userController.text,
      password: _passwordController.text,
    );
    if (!isValid) {
      setState(
        () => _loginError =
            'Usuario o contraseña incorrectos. Inténtalo de nuevo.',
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminCustomizationScreen(
          brandController: widget.brandController,
          authController: widget.authController,
        ),
      ),
    );
  }

  void _openPasswordRecovery() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PasswordRecoveryScreen(
          brand: widget.brand,
          brandController: widget.brandController,
          authController: widget.authController,
        ),
      ),
    );
  }

  void _showGoogleSetup() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202126),
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Continuar con Google',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'El botón está listo en el flujo. Para iniciar sesión de verdad se debe conectar Google OAuth con el Client ID de tu proyecto y la API de Moto Master.',
              style: TextStyle(color: Color(0xFFD2D2D2), height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityMark extends StatelessWidget {
  const _SecurityMark({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    width: 68,
    height: 68,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: accent.withValues(alpha: .10),
      border: Border.all(color: accent, width: 2),
    ),
    child: Icon(Icons.admin_panel_settings_outlined, color: accent, size: 34),
  );
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    required this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autocorrect: false,
    enableSuggestions: !obscureText,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF24262B),
      contentPadding: const EdgeInsets.symmetric(vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4B4E55)),
      ),
    ),
  );
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x22FF5252),
      border: Border.all(color: const Color(0xFFFF6B6B)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8C8C)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFFFC7C7), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: Color(0xFF4B4E55))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'o continúa con',
          style: TextStyle(color: Color(0xFFBFC0C4), fontSize: 12),
        ),
      ),
      Expanded(child: Divider(color: Color(0xFF4B4E55))),
    ],
  );
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF5C5F67)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GoogleMark(),
          SizedBox(width: 12),
          Text(
            'Continuar con Google',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 25,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _InitialAccessHint extends StatelessWidget {
  const _InitialAccessHint({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .38)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded, color: Color(0xFFFF9B59)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Primer acceso\nUsuario: admin  •  Contraseña: 123456',
            style: TextStyle(
              color: Color(0xFFFFD8C0),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
