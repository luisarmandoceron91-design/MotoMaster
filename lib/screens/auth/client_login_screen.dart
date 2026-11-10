import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/admin_oauth_intent_store.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/client/client_profile_repository.dart';
import '../../core/client/client_profile.dart';
import '../../core/client/local_client_profile_store.dart';
import '../../core/networking/api_client.dart';
import '../../core/tenant/tenant_context.dart';
import '../workshop_selection/client_workshop_selection_screen.dart';
import 'account_recovery_screen.dart';
import 'client_registration/client_registration_screen.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({
    super.key,
    required this.tenantContext,
    required this.brandController,
    required this.authController,
    this.resumeGoogleSignIn = false,
  });

  final TenantContext tenantContext;
  final WorkshopBrandController brandController;
  final AdminAuthController authController;
  final bool resumeGoogleSignIn;

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  static const _googleSignInEnabled = ApiClient.cloudEnabled;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  final _profiles = ClientProfileRepository();
  final _localProfiles = LocalClientProfileStore();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.resumeGoogleSignIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeGoogle());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6A00);
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
                colors: [
                  Color(0x66000000),
                  Color(0x36000000),
                  Color(0xA6000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xF01B1C20),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: accent),
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
                          const _ClientMark(),
                          const SizedBox(height: 18),
                          const Text(
                            'Acceso cliente',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tu información estará disponible en todos tus dispositivos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFFBFC0C4)),
                          ),
                          const SizedBox(height: 26),
                          _field(
                            controller: _email,
                            label: 'Correo electrónico',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                value == null || !value.contains('@')
                                ? 'Ingresa un correo válido.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _field(
                            controller: _password,
                            label: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Ingresa tu contraseña.'
                                : null,
                            suffix: IconButton(
                              tooltip: _obscure
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFF9B9B)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _signIn,
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                              ),
                              icon: _loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: const Text(
                                'Ingresar',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _googleSignInEnabled && !_loading
                                ? _continueWithGoogle
                                : null,
                            icon: const _GoogleMark(),
                            label: const Text('Continuar con Google'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF5A5D64)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _createAccount,
                            child: const Text('Soy nuevo: crear cuenta'),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text('Volver a tipos de acceso'),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    // No reutilizar claves guardadas automáticamente en pantallas de acceso.
    autofillHints: obscureText ? const <String>[] : const [AutofillHints.username],
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF24262B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!ApiClient.cloudEnabled) {
        final localProfile = await _localProfiles.authenticate(
          email: _email.text,
          password: _password.text,
        );
        if (localProfile != null) {
          _openWorkshopSelection(localProfile);
          return;
        }
        if (mounted) {
          setState(() => _error = 'Correo o contraseña incorrectos.');
        }
        return;
      }
      final response = await _auth.signIn(
        email: _email.text,
        password: _password.text,
      );
      final user = response.user;
      if (user == null) throw StateError('No encontramos la sesión.');
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      if (metadata['account_type'] != 'client') {
        await _auth.signOut();
        throw const AuthException('Esta cuenta no corresponde a un cliente.');
      }
      final sessionProfile = ClientProfile(
        userId: user.id,
        fullName: metadata['full_name']?.toString() ?? 'Cliente',
        email: user.email ?? _email.text.trim().toLowerCase(),
        phone: metadata['phone']?.toString() ?? '',
        department: metadata['department']?.toString() ?? '',
        city: metadata['city']?.toString() ?? '',
      );
      // Cargar el perfil definitivo antes de navegar. De esta forma la foto
      // guardada en Storage se conserva al cerrar y volver a iniciar sesión.
      final profile = await _profiles.getCurrentProfile() ?? sessionProfile;
      await _localProfiles.save(profile);
      _openWorkshopSelection(profile);
    } on AuthException {
      if (mounted) setState(() => _error = 'Correo o contraseña incorrectos.');
    } catch (error) {
      if (mounted) setState(() => _error = 'No fue posible ingresar: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshProfileCache() async {
    try {
      final profile = await _profiles.getCurrentProfile();
      if (profile != null) await _localProfiles.save(profile);
    } catch (_) {
      // El perfil visible ya viene de la sesión; esta actualización no bloquea.
    }
  }

  void _openWorkshopSelection(ClientProfile profile) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ClientWorkshopSelectionScreen(
          profile: profile,
          tenantContext: widget.tenantContext,
          brandController: widget.brandController,
          authController: widget.authController,
        ),
      ),
    );
  }

  Future<void> _resetPassword() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AccountRecoveryScreen(
        accountType: RecoveryAccountType.client,
        initialEmail: _email.text,
      ),
    ),
  );

  Future<void> _continueWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final intentStore = AdminOAuthIntentStore();
    try {
      await intentStore.markPending(GoogleAccountIntent.client);
      final started = await _auth.signInWithGoogle();
      if (!started) {
        await intentStore.clear();
        if (mounted) {
          setState(() => _error = 'No fue posible abrir el acceso con Google.');
        }
      }
    } catch (error) {
      await intentStore.clear();
      if (mounted) {
        final message = error is AuthException
            ? error.message
            : 'No fue posible conectar con Google.';
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resumeGoogle() async {
    final intentStore = AdminOAuthIntentStore();
    if (await intentStore.pendingIntent() != GoogleAccountIntent.client) return;
    await intentStore.clear();
    final user = _auth.currentUser;
    if (user == null || !mounted) return;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final accountType = metadata['account_type']?.toString();
    if (accountType == 'admin') {
      await _auth.signOut();
      if (mounted) {
        setState(
          () => _error = 'Esta cuenta de Google pertenece a un administrador.',
        );
      }
      return;
    }
    if (accountType == 'client') {
      final profile = ClientProfile(
        userId: user.id,
        fullName: (metadata['full_name'] ?? metadata['name'] ?? 'Cliente')
            .toString(),
        email: user.email ?? '',
        phone: metadata['phone']?.toString() ?? '',
        department: metadata['department']?.toString() ?? '',
        city: metadata['city']?.toString() ?? '',
      );
      _openWorkshopSelection(profile);
      unawaited(_refreshProfileCache());
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ClientRegistrationScreen(
          tenantContext: widget.tenantContext,
          brandController: widget.brandController,
          authController: widget.authController,
          existingGoogleAccount: true,
        ),
      ),
    );
  }

  void _createAccount() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ClientRegistrationScreen(
        tenantContext: widget.tenantContext,
        brandController: widget.brandController,
        authController: widget.authController,
      ),
    ),
  );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontWeight: FontWeight.w900,
        fontSize: 15,
      ),
    ),
  );
}

class _ClientMark extends StatelessWidget {
  const _ClientMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 68,
    height: 68,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFFF6A00).withValues(alpha: .10),
      border: Border.all(color: const Color(0xFFFF6A00), width: 2),
    ),
    child: const Icon(
      Icons.person_outline_rounded,
      color: Color(0xFFFF6A00),
      size: 36,
    ),
  );
}
