import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jisfsfgbyvzjvyohqbuv.supabase.co',
  );
  static const _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable__k4G1sJ6Bighv8THq5fmNg_iVvXcC6C',
  );

  static String get supabaseUrl => _supabaseUrl;
  static String get supabasePublishableKey => _supabaseAnonKey;

  /// Se conserva durante el arranque web para terminar el flujo correcto
  /// (cliente o administrador) después de regresar desde Google.
  static String? _pendingGoogleIntent;
  static String? get pendingGoogleIntent => _pendingGoogleIntent;

  // Se captura antes de que el SDK intercambie el código y limpie la URL del
  // navegador. De esa forma el enlace del correo abre Nueva contraseña y no
  // termina por error en la selección de rol.
  static bool _pendingPasswordRecovery = false;
  static bool get pendingPasswordRecovery => _pendingPasswordRecovery;

  // La URL de recuperación solo es válida si el SDK logró crear una sesión.
  // Esto evita mostrar el formulario de contraseña cuando el enlace se abrió
  // desde otra aplicación o navegador y el intercambio PKCE no puede ocurrir.
  static bool _recoverySessionEstablished = false;
  static bool get recoverySessionEstablished => _recoverySessionEstablished;

  static void completePasswordRecovery() {
    _pendingPasswordRecovery = false;
    _recoverySessionEstablished = false;
  }

  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Cloud access is explicit so local development never waits for a dead
  /// endpoint before continuing.
  static const bool cloudEnabled = bool.fromEnvironment(
    'ENABLE_CLOUD_FEATURES',
    defaultValue: true,
  );

  Future<void> init() async {
    if (_initialized) return;
    final callbackUri = Uri.base;
    _pendingGoogleIntent = callbackUri.queryParameters['google_intent'];
    final callbackFragment = Uri.splitQueryString(callbackUri.fragment);
    _pendingPasswordRecovery =
        callbackUri.queryParameters['recovery'] == 'password' ||
        callbackUri.queryParameters['type'] == 'recovery' ||
        callbackFragment['type'] == 'recovery';
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
      // El SDK normalmente consume el callback internamente y limpia la URL
      // antes de que la aplicación conozca si el usuario eligió Cliente o
      // Administrador. Lo procesamos justo después para conservar ese dato.
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
      ),
    );
    if (kIsWeb && _isAuthCallback(callbackUri)) {
      try {
        final response = await Supabase.instance.client.auth.getSessionFromUrl(
          callbackUri,
        );
        if (_pendingPasswordRecovery) {
          _recoverySessionEstablished = response.session.user != null;
        }
      } catch (error) {
        _recoverySessionEstablished = false;
        debugPrint('No fue posible completar el retorno OAuth: $error');
      }
    }
    _initialized = true;
  }

  bool _isAuthCallback(Uri uri) {
    final fragment = Uri.splitQueryString(uri.fragment);
    return uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        fragment.containsKey('access_token') ||
        fragment.containsKey('error');
  }

  SupabaseClient get client => Supabase.instance.client;
}
