import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

class AuthService {
  AuthService({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isAuthenticated => currentUser != null;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String department,
    required String city,
    String accountType = 'client',
  }) {
    return _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'department': department.trim(),
        'city': city.trim(),
        'account_type': accountType,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<bool> signInWithGoogle() async {
    if (!await isGoogleProviderEnabled()) {
      throw const AuthException(
        'Google todavía no está habilitado en Supabase. Activa el proveedor Google para continuar.',
      );
    }
    final redirectTo = kIsWeb
        ? Uri.base.origin
        : 'io.supabase.motomaster://login-callback/';
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  Future<bool> isGoogleProviderEnabled() async {
    final response = await http.get(
      Uri.parse('${ApiClient.supabaseUrl}/auth/v1/settings'),
      headers: {'apikey': ApiClient.supabasePublishableKey},
    );
    if (response.statusCode != 200) {
      throw const AuthException(
        'No fue posible verificar la configuración de Google.',
      );
    }
    final settings = jsonDecode(response.body) as Map<String, dynamic>;
    final external = settings['external'];
    return external is Map && external['google'] == true;
  }

  Future<void> sendPasswordReset(String email) {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/?recovery=password'
        : 'io.supabase.motomaster://login-callback/?recovery=password';
    return _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: redirectTo,
    );
  }

  Future<void> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<UserResponse> updateProfileMetadata({
    required String accountType,
    required String fullName,
    required String phone,
    required String department,
    required String city,
  }) {
    return _client.auth.updateUser(
      UserAttributes(
        data: {
          'account_type': accountType,
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'department': department.trim(),
          'city': city.trim(),
        },
      ),
    );
  }

  Future<void> sendPhoneRecoveryCode(String phone) {
    return _client.auth.signInWithOtp(
      phone: phone.replaceAll(' ', ''),
      shouldCreateUser: false,
    );
  }

  Future<void> sendEmailRecoveryCode(String email) {
    return _client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: false,
      emailRedirectTo: kIsWeb
          ? Uri.base.origin
          : 'io.supabase.motomaster://login-callback/',
    );
  }

  Future<AuthResponse> verifyPhoneRecoveryCode({
    required String phone,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      phone: phone.replaceAll(' ', ''),
      token: code.trim(),
      type: OtpType.sms,
    );
  }

  Future<AuthResponse> verifyEmailRecoveryCode({
    required String email,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: code.trim(),
      type: OtpType.email,
    );
  }

  Future<void> updateEmail(String email) {
    return _client.auth.updateUser(
      UserAttributes(email: email.trim().toLowerCase()),
    );
  }

  Future<void> changeCredentials({
    required String currentPassword,
    required String newEmail,
    required String newPassword,
  }) async {
    final email = currentUser?.email;
    if (email == null) throw const AuthException('No hay una sesión activa.');
    await signIn(email: email, password: currentPassword);
    await _client.auth.updateUser(
      UserAttributes(
        email: newEmail.trim().toLowerCase(),
        password: newPassword,
      ),
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
