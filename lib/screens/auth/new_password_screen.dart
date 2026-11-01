import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/security/password_policy.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, required this.onCompleted});

  final ValueChanged<BuildContext> onCompleted;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  static const _accent = Color(0xFFFF6500);
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
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
        const ColoredBox(color: Color(0xA8080A0D)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C20),
                  border: Border.all(color: _accent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.password_rounded,
                        color: _accent,
                        size: 58,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nueva contraseña',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Usa al menos 6 caracteres. Puedes crear una contraseña más larga si lo prefieres.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFC7C9CC)),
                      ),
                      const SizedBox(height: 24),
                      _field(_password, 'Nueva contraseña'),
                      const SizedBox(height: 14),
                      _field(
                        _confirmation,
                        'Confirmar contraseña',
                        confirmation: true,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFF8C8C)),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                          ),
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text(
                            'Guardar contraseña',
                            style: TextStyle(fontWeight: FontWeight.w900),
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
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool confirmation = false,
  }) => TextFormField(
    controller: controller,
    obscureText: _obscure,
    validator: (value) {
      final policyError = validateStrongPassword(value);
      if (policyError != null) return policyError;
      if (confirmation && value != _password.text) {
        return 'Las contraseñas no coinciden.';
      }
      return null;
    },
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFF25272C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().updatePassword(_password.text);
      await AuthService().signOut();
      if (mounted) widget.onCompleted(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'El enlace venció o no fue posible guardar la contraseña.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
