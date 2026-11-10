import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/local_workshop_admin_store.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/security/password_policy.dart';

class CredentialSettingsScreen extends StatefulWidget {
  const CredentialSettingsScreen({
    super.key,
    required this.brand,
    this.localAdminStore,
    this.passwordOnly = false,
  });
  final WorkshopBrand brand;
  final LocalWorkshopAdminStore? localAdminStore;
  /// Cuando se abre desde Perfil solo muestra el flujo claro y seguro para
  /// renovar la contraseña, sin confundirlo con recuperación de cuenta.
  final bool passwordOnly;
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
    _newUser.text = AuthService().currentUser?.email ?? '';
    _loadLocalUser();
  }

  Future<void> _loadLocalUser() async {
    if (AuthService().currentUser != null) return;
    final account = await widget.localAdminStore?.loadAccount();
    if (mounted && account != null) {
      setState(() => _newUser.text = account.username);
    }
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
      appBar: AppBar(title: Text(widget.passwordOnly ? 'Cambiar contraseña' : 'Credenciales de acceso')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: .38,
            child: Image.asset(
              'assets/images/workshop_login_background_v1.png',
              fit: BoxFit.cover,
            ),
          ),
          const ColoredBox(color: Color(0xA8080A0D)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: const Color(0xF21A1D22),
                    border: Border.all(color: accent.withValues(alpha: .72)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_reset_outlined,
                          color: accent,
                          size: 42,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.passwordOnly ? 'Cambia tu contraseña' : 'Actualiza tus credenciales',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.passwordOnly
                              ? 'Confirma tu contraseña actual y crea una nueva clave segura para proteger tu cuenta.'
                              : 'Tu correo es tu usuario de acceso. Confirma tu contraseña actual antes de cambiarlo.',
                        ),
                        const SizedBox(height: 26),
                        _SettingsField(
                          controller: _currentPassword,
                          label: 'Contraseña actual',
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        if (!widget.passwordOnly) ...[
                          _SettingsField(
                            controller: _newUser,
                            label: 'Correo electrónico de acceso',
                          ),
                          const SizedBox(height: 16),
                        ],
                        _SettingsField(
                          controller: _newPassword,
                          label: 'Nueva contraseña',
                          obscureText: true,
                          validator: validateStrongPassword,
                        ),
                        const SizedBox(height: 16),
                        _SettingsField(
                          controller: _confirmPassword,
                          label: 'Confirmar nueva contraseña',
                          obscureText: true,
                          validator: (value) => value != _newPassword.text
                              ? 'Las contraseñas no coinciden.'
                              : validateStrongPassword(value),
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
                            label: Text(
                              widget.passwordOnly ? 'Actualizar contraseña' : 'Guardar credenciales',
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
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final auth = AuthService();
      final cloudAccount = auth.currentUser != null;
      if (cloudAccount) {
        await auth.changeCredentials(
          currentPassword: _currentPassword.text,
          newEmail: _newUser.text,
          newPassword: _newPassword.text,
        );
      } else if (widget.localAdminStore != null) {
        final error = await widget.localAdminStore!.changeCredentials(
          currentPassword: _currentPassword.text,
          newEmail: _newUser.text,
          newPassword: _newPassword.text,
        );
        if (error != null) throw StateError(error);
      } else {
        throw StateError('No hay una sesión activa.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible actualizar: $error')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.passwordOnly
              ? 'Contraseña actualizada correctamente. Tus próximas sesiones usarán la nueva clave.'
              : 'Contraseña actualizada. Si cambiaste el correo, confirma el enlace enviado por seguridad.',
        ),
      ),
    );
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
