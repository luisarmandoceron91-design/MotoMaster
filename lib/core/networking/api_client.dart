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

  bool _initialized = false;

  /// Cloud access is explicit so local development never waits for a dead
  /// endpoint before continuing.
  static const bool cloudEnabled = bool.fromEnvironment(
    'ENABLE_CLOUD_FEATURES',
    defaultValue: true,
  );

  Future<void> init() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
    _initialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;
}
