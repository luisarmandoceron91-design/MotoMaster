import 'package:flutter/material.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/branding/workshop_brand.dart';

class CredentialSettingsScreen extends StatefulWidget {
  const CredentialSettingsScreen({
    super.key,
    required this.authController,
    required this.brand,
  });
  final AdminAuthController authController;
  final WorkshopBrand brand;
  @override
  State<CredentialSettingsScreen> createState() =>
      _CredentialSettingsScreenState();
}

class _CredentialSettingsScreenState extends State<CredentialSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newUser = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  @override
  void initState() {
    super.initState();
    _newUser.text = widget.authController.username;
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newUser.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.brand.accentColor;
    return Scaffold(
      appBar: AppBar(title: const Text('Credenciales de acceso')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_reset_outlined, color: accent, size: 42),
                  const SizedBox(height: 14),
                  const Text(
                    'Actualiza tus credenciales',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Confirma tu contraseña actual antes de cambiar usuario o contraseña.',
                  ),
                  const SizedBox(height: 26),
                  _SettingsField(
                    controller: _currentPassword,
                    label: 'Contraseña actual',
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  _SettingsField(controller: _newUser, label: 'Nuevo usuario'),
                  const SizedBox(height: 16),
                  _SettingsField(
                    controller: _newPassword,
                    label: 'Nueva contraseña',
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  _SettingsField(
                    controller: _confirmPassword,
                    label: 'Confirmar nueva contraseña',
                    obscureText: true,
                    validator: (value) => value != _newPassword.text
                        ? 'Las contraseñas no coinciden.'
                        : null,
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text(
                        'Guardar credenciales',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await widget.authController.changeCredentials(
      currentPassword: _currentPassword.text,
      newUsername: _newUser.text,
      newPassword: _newPassword.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Credenciales actualizadas.')));
    Navigator.pop(context);
  }
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    autocorrect: false,
    enableSuggestions: !obscureText,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF24262B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    ),
    validator:
        validator ??
        (value) => value == null || value.isEmpty
            ? 'Este campo es obligatorio.'
            : null,
  );
}
