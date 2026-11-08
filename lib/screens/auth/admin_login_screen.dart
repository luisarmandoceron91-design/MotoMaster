import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/admin_auth_controller.dart';
import '../../core/auth/admin_access_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/admin_oauth_intent_store.dart';
import '../../core/auth/local_workshop_admin_store.dart';
import '../../core/branding/workshop_brand.dart';
import '../../core/networking/api_client.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/tenant/tenant_model.dart';
import '../../core/workshops/workshop.dart';
import '../../core/workshops/workshop_repository.dart';
import '../admin_customization/admin_customization_screen.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../owner/owner_profile_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import 'account_recovery_screen.dart';
import 'admin_activation_screen.dart';
import 'password_recovery_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.brandController,
    required this.authController,
    required this.brand,
    required this.tenantContext,
    this.resumeGoogleSignIn = false,
  });

  final WorkshopBrandController brandController;
  final AdminAuthController authController;
  final WorkshopBrand brand;
  final TenantContext tenantContext;
  final bool resumeGoogleSignIn;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const _cloudFeaturesEnabled = ApiClient.cloudEnabled;
  static const _googleSignInEnabled = ApiClient.cloudEnabled;
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loginError;
  final _localAdminStore = LocalWorkshopAdminStore();

  String get _ownerContact {
    final values = <String>{
      widget.authController.publicContact.trim(),
      widget.authController.phone.trim(),
      widget.authController.email.trim(),
    }..removeWhere((value) => value.isEmpty);
    return values.isEmpty ? 'contacto del desarrollador' : values.join(' · ');
  }

  String get _suspendedMessage =>
      'Este taller está cerrado temporalmente. Comunícate con el desarrollador '
      'de la aplicación para solicitar la activación: $_ownerContact.';

  @override
  void initState() {
    super.initState();
    if (widget.resumeGoogleSignIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeGoogle());
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6500);
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
                stops: [0, .5, 1],
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
                          const Text(
                            'PORTAL DE GESTIÓN',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _LoginField(
                            controller: _userController,
                            label: 'Usuario o correo electrónico',
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
                              onPressed: _isLoading ? null : _signIn,
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: _isLoading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: const Text(
                                'Ingresar al panel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _LoginDivider(),
                          const SizedBox(height: 20),
                          _GoogleButton(
                            onPressed: _googleSignInEnabled && !_isLoading
                                ? _continueWithGoogle
                                : null,
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _registerAdmin,
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 19,
                            ),
                            label: const Text('Crear cuenta de administrador'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: const BorderSide(color: accent),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.authController.authenticate(
      username: _userController.text,
      password: _passwordController.text,
    )) {
      await _connectOwnerCloudSession(_passwordController.text);
      await widget.authController.restoreOwnerProfileFromCloud();
      if (widget.authController.hasOwnerProfile) {
        _openOwnerDashboard();
      } else {
        _openOwnerProfile();
      }
      return;
    }
    if (_localAdminStore.isBootstrapCredential(
      _userController.text,
      _passwordController.text,
    )) {
      await _registerAdmin();
      return;
    }
    setState(() {
      _isLoading = true;
      _loginError = null;
    });
    try {
      final localAccount = _cloudFeaturesEnabled
          ? null
          : await _localAdminStore.authenticate(
              username: _userController.text,
              password: _passwordController.text,
            );
      if (localAccount != null) {
        if (!localAccount.canEnter) {
          final message =
              localAccount.accessState == WorkshopAccessState.suspended
              ? _suspendedMessage
              : 'El acceso de prueba venció. Solicita más tiempo al propietario de la plataforma.';
          setState(() => _loginError = message);
          return;
        }
        if (!localAccount.hasWorkshop) {
          await widget.tenantContext.clear();
          widget.brandController.value = WorkshopBrand.newWorkshop;
          if (mounted) _openCustomization();
          return;
        }
        await widget.tenantContext.setTenant(
          Tenant(
            tenantId: localAccount.tenantId,
            name: localAccount.tenantName,
          ),
        );
        await widget.brandController.load(localAccount.tenantId);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => AdminDashboardScreen(
                brandController: widget.brandController,
                userName: localAccount.fullName.isEmpty
                    ? localAccount.username
                    : localAccount.fullName,
                tenantContext: widget.tenantContext,
                localAdminStore: _localAdminStore,
              ),
            ),
          );
        }
        return;
      }
      if (!_cloudFeaturesEnabled) {
        setState(() => _loginError = 'Usuario o contraseña incorrectos.');
        return;
      }
      await AuthService().signIn(
        email: _userController.text,
        password: _passwordController.text,
      );
      final accessFuture = AdminAccessService().resolveRole();
      final workshopsFuture = WorkshopRepository().listManaged();
      final accessRole = await accessFuture;
      if (accessRole == AdminAccessRole.platformOwner) {
        await widget.authController.restoreOwnerProfileFromCloud();
        if (mounted) _openOwnerDashboard();
        return;
      }
      if (accessRole == AdminAccessRole.workshopSuspended) {
        await AuthService().signOut();
        if (mounted) {
          setState(() => _loginError = _suspendedMessage);
        }
        return;
      }
      if (accessRole == AdminAccessRole.workshopExpired) {
        await AuthService().signOut();
        if (mounted) {
          setState(
            () => _loginError =
                'El acceso de prueba venció. Solicita más tiempo al propietario de la plataforma.',
          );
        }
        return;
      }
      if (accessRole == null) {
        final user = AuthService().currentUser;
        final accountType = user?.userMetadata?['account_type']?.toString();
        if (user != null && accountType == 'admin') {
          final registrationError = await _localAdminStore.register(
            password: _passwordController.text,
            fullName:
                user.userMetadata?['full_name']?.toString() ??
                user.email ??
                'Administrador',
            email: user.email ?? _userController.text,
            phone: user.userMetadata?['phone']?.toString() ?? '',
          );
          if (registrationError != null &&
              !registrationError.toLowerCase().contains('registrad')) {
            throw StateError(registrationError);
          }
          await widget.tenantContext.clear();
          widget.brandController.value = WorkshopBrand.newWorkshop;
          if (mounted) _openCustomization();
          return;
        }
        await AuthService().signOut();
        if (mounted) {
          setState(
            () => _loginError =
                'Esta cuenta no tiene acceso administrativo activo.',
          );
        }
        return;
      }
      await _enterAdminPanel(preloadedWorkshops: await workshopsFuture);
    } catch (_) {
      if (mounted) {
        setState(() => _loginError = 'Correo o contraseña incorrectos.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectOwnerCloudSession(String password) async {
    if (!ApiClient.cloudEnabled) return;
    final auth = AuthService();
    try {
      if (auth.isAuthenticated) {
        final role = await AdminAccessService().resolveRole();
        if (role == AdminAccessRole.platformOwner) {
          await widget.authController.restoreOwnerProfileFromCloud();
          return;
        }
        await auth.signOut();
      }
      final ownerEmail = widget.authController.email.trim();
      if (ownerEmail.isEmpty) return;
      await auth.signIn(email: ownerEmail, password: password);
      final role = await AdminAccessService().resolveRole();
      if (role != AdminAccessRole.platformOwner) {
        await auth.signOut();
      } else {
        await widget.authController.restoreOwnerProfileFromCloud();
      }
    } catch (_) {
      if (auth.isAuthenticated) await auth.signOut();
    }
  }

  void _openOwnerProfile() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OwnerProfileScreen(
          authController: widget.authController,
          tenantContext: widget.tenantContext,
          brandController: widget.brandController,
        ),
      ),
    );
  }

  void _openOwnerDashboard() {
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

  Future<void> _enterAdminPanel({List<Workshop>? preloadedWorkshops}) async {
    final workshops =
        preloadedWorkshops ?? await WorkshopRepository().listManaged();
    if (workshops.isNotEmpty) {
      final workshop = workshops.first;
      await widget.tenantContext.setTenant(
        Tenant(tenantId: workshop.id, name: workshop.name),
      );
      widget.brandController.value = WorkshopBrand(
        name: workshop.name,
        tagline: workshop.tagline,
        logoIndex: workshop.logoIndex,
        accentColorValue: workshop.accentColorValue,
        customLogoBytes: workshop.logoBytes,
        customLogoFileName: workshop.logoFileName,
      );
      if (!mounted) return;
      final cloudUser = AuthService().currentUser;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminDashboardScreen(
            brandController: widget.brandController,
            userName:
                cloudUser?.userMetadata?['full_name']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? cloudUser!.userMetadata!['full_name'].toString()
                : cloudUser?.email ?? 'Administrador del taller',
            tenantContext: widget.tenantContext,
          ),
        ),
      );
      return;
    }
    await widget.tenantContext.clear();
    widget.brandController.value = WorkshopBrand.newWorkshop;
    if (mounted) _openCustomization();
  }

  void _openCustomization() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminCustomizationScreen(
          brandController: widget.brandController,
          authController: widget.authController,
          tenantContext: widget.tenantContext,
        ),
      ),
    );
  }

  Future<void> _registerAdmin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminActivationScreen(
          tenantContext: widget.tenantContext,
          brandController: widget.brandController,
          authController: widget.authController,
        ),
      ),
    );
  }

  Future<void> _openPasswordRecovery() async {
    final account = _userController.text.trim();
    if (account.isEmpty) {
      setState(() => _loginError = 'Escribe primero tu usuario.');
      return;
    }
    if (account.toLowerCase() == widget.authController.username.toLowerCase()) {
      if (!widget.authController.hasOwnerProfile) {
        setState(
          () => _loginError =
              'Primero inicia con la clave inicial y registra tu correo y celular.',
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PasswordRecoveryScreen(
            brand: widget.brand,
            brandController: widget.brandController,
            authController: widget.authController,
          ),
        ),
      );
      return;
    }
    if (!account.contains('@')) {
      setState(
        () => _loginError =
            'Los administradores de talleres ingresan y recuperan su cuenta mediante el correo registrado.',
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountRecoveryScreen(
          accountType: RecoveryAccountType.administrator,
          initialEmail: account,
        ),
      ),
    );
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isLoading = true;
      _loginError = null;
    });
    final intentStore = AdminOAuthIntentStore();
    try {
      await intentStore.markPending(GoogleAccountIntent.administrator);
      final started = await AuthService().signInWithGoogle();
      if (!started) {
        await intentStore.clear();
        if (mounted) {
          setState(
            () => _loginError = 'No fue posible abrir el acceso con Google.',
          );
        }
      }
    } catch (error) {
      await intentStore.clear();
      if (mounted) {
        final message = error is AuthException
            ? error.message
            : 'No fue posible conectar con Google.';
        setState(() => _loginError = message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resumeGoogle() async {
    final intentStore = AdminOAuthIntentStore();
    if (await intentStore.pendingIntent() !=
        GoogleAccountIntent.administrator) {
      return;
    }
    await intentStore.clear();
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loginError = null;
    });
    try {
      final accessRole = await AdminAccessService().resolveRole();
      if (accessRole == AdminAccessRole.platformOwner) {
        await widget.authController.restoreOwnerProfileFromCloud();
        _openOwnerDashboard();
        return;
      }
      if (accessRole == AdminAccessRole.workshopSuspended) {
        await AuthService().signOut();
        if (mounted) {
          setState(
            () => _loginError =
                'Este taller está desactivado. El propietario de la plataforma debe reactivarlo.',
          );
        }
        return;
      }
      if (accessRole == AdminAccessRole.workshopExpired) {
        await AuthService().signOut();
        if (mounted) {
          setState(
            () => _loginError =
                'El acceso de prueba venció. Solicita más tiempo al propietario de la plataforma.',
          );
        }
        return;
      }
      if (accessRole == AdminAccessRole.workshopOwner ||
          accessRole == AdminAccessRole.workshopStaff) {
        await _enterAdminPanel();
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminActivationScreen(
            tenantContext: widget.tenantContext,
            brandController: widget.brandController,
            authController: widget.authController,
            existingGoogleAccount: true,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _loginError = 'No se pudo verificar la cuenta de Google: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
  final VoidCallback? onPressed;
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
