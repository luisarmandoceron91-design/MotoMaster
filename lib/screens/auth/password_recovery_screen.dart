import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/security/password_policy.dart';

enum _RecoveryMethod { email, sms }

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.brand,
    required this.brandController,
    required this.authController,
  });

  final WorkshopBrand brand;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _destinationController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _RecoveryMethod _method = _RecoveryMethod.email;
  int _step = 0;
  String? _codeError;
  String? _resetError;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _destinationController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmationController.dispose();
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
          const ColoredBox(color: Color(0xE8000000)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xF01D1E22),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: accent.withValues(alpha: .82)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _step == 0
                          ? _requestBody(accent)
                          : _step == 1
                          ? _codeBody(accent)
                          : _resetBody(accent),
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

  Widget _requestBody(Color accent) {
    final isEmail = _method == _RecoveryMethod.email;
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('request'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onPressed: () => Navigator.of(context).pop()),
          const SizedBox(height: 12),
          Icon(Icons.lock_reset_outlined, color: accent, size: 44),
          const SizedBox(height: 18),
          const Text(
            'Recupera tu acceso',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text('Elige cómo quieres recibir el código de verificación.'),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MethodChoice(
                  selected: isEmail,
                  icon: Icons.email_outlined,
                  label: 'Correo',
                  accent: accent,
                  onTap: () => setState(() => _method = _RecoveryMethod.email),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodChoice(
                  selected: !isEmail,
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  accent: accent,
                  onTap: () => setState(() => _method = _RecoveryMethod.sms),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _destinationController,
            keyboardType: isEmail
                ? TextInputType.emailAddress
                : TextInputType.phone,
            inputFormatters: isEmail
                ? null
                : [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            decoration: InputDecoration(
              labelText: isEmail ? 'Correo electrónico' : 'Número de celular',
              prefixIcon: Icon(
                isEmail
                    ? Icons.alternate_email_rounded
                    : Icons.phone_android_outlined,
              ),
              filled: true,
              fillColor: const Color(0xFF292B30),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isEmail
                    ? 'Ingresa tu correo.'
                    : 'Ingresa tu número de celular.';
              }
              if (isEmail && !value.contains('@')) {
                return 'Ingresa un correo válido.';
              }
              if (!isEmail &&
                  value.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
                return 'Ingresa un número válido.';
              }
              if (!widget.authController.matchesRecoveryDestination(value)) {
                return isEmail
                    ? 'No coincide con el correo registrado.'
                    : 'No coincide con el celular registrado.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _sendCode,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              icon: Icon(
                isEmail ? Icons.email_outlined : Icons.send_to_mobile_outlined,
              ),
              label: Text(
                isEmail ? 'Enviar código al correo' : 'Enviar código por SMS',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Usa el correo o celular que guardaste en tu perfil de propietario.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .58),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBody(Color accent) {
    final via = _method == _RecoveryMethod.email
        ? 'correo electrónico'
        : 'celular';
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('code'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(
            onPressed: () => setState(() {
              _step = 0;
              _codeError = null;
            }),
          ),
          const SizedBox(height: 12),
          Icon(Icons.verified_user_outlined, color: accent, size: 44),
          const SizedBox(height: 18),
          const Text(
            'Verifica tu código',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Escribe el código de 6 dígitos enviado a tu $via.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
            style: const TextStyle(
              fontSize: 25,
              letterSpacing: 9,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: .28)),
              filled: true,
              fillColor: const Color(0xFF292B30),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              errorText: _codeError,
            ),
            validator: (value) => value == null || value.length != 6
                ? 'Ingresa los 6 dígitos.'
                : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _verifyCode,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.verified_outlined),
              label: const Text(
                'Verificar código',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _sendCode,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reenviar código'),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Modo de prueba: usa el código 123456.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFFE5E5E5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resetBody(Color accent) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('reset'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(
            onPressed: () => setState(() {
              _step = 1;
              _resetError = null;
            }),
          ),
          const SizedBox(height: 12),
          Icon(Icons.password_rounded, color: accent, size: 44),
          const SizedBox(height: 18),
          const Text(
            'Crea una nueva contraseña',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu usuario es ${widget.authController.username}. La nueva contraseña debe tener mínimo 6 caracteres.',
          ),
          const SizedBox(height: 22),
          _passwordField(
            controller: _newPasswordController,
            label: 'Nueva contraseña',
            obscure: _obscurePassword,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 14),
          _passwordField(
            controller: _confirmationController,
            label: 'Confirmar contraseña',
            obscure: _obscureConfirmation,
            confirmation: true,
            onToggle: () =>
                setState(() => _obscureConfirmation = !_obscureConfirmation),
          ),
          if (_resetError != null) ...[
            const SizedBox(height: 12),
            Text(
              _resetError!,
              style: const TextStyle(color: Color(0xFFFF8C8C)),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _saveNewPassword,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text(
                'Guardar nueva contraseña',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      if (confirmation && value != _newPasswordController.text) {
        return 'Las contraseñas no coinciden.';
      }
      return null;
    },
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFF292B30),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );

  void _sendCode() {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    setState(() {
      _step = 1;
      _codeError = null;
    });
  }

  void _verifyCode() {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.authController.verifyRecoveryCode(_codeController.text)) {
      setState(
        () => _codeError = 'El código no es válido. Inténtalo de nuevo.',
      );
      return;
    }
    setState(() {
      _step = 2;
      _codeError = null;
    });
  }

  Future<void> _saveNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await widget.authController.resetPasswordWithRecovery(
      code: _codeController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _resetError = error);
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Volver',
    onPressed: onPressed,
    icon: const Icon(Icons.arrow_back_rounded),
    style: IconButton.styleFrom(backgroundColor: const Color(0xFF2B2D33)),
  );
}

class _MethodChoice extends StatelessWidget {
  const _MethodChoice({
    required this.selected,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: .16)
              : const Color(0xFF292B30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : const Color(0xFF4B4E55),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? accent : Colors.white),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? accent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
