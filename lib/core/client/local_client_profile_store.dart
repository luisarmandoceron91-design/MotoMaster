import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../security/password_kdf.dart';
import 'client_profile.dart';

class LocalClientProfileStore {
  static const _accountsKey = 'local_client_accounts_v2';
  static const _activeEmailKey = 'active_local_client_email_v2';
  static const _legacyProfileKey = 'local_client_profile';
  static const _legacyCredentialKey = 'local_client_credentials_v1';

  Future<Map<String, dynamic>> _readAccounts(
    SharedPreferences preferences,
  ) async {
    final encoded = preferences.getString(_accountsKey);
    if (encoded != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      } catch (_) {}
    }

    final profileJson = preferences.getString(_legacyProfileKey);
    if (profileJson == null) return <String, dynamic>{};
    try {
      final profile = Map<String, dynamic>.from(jsonDecode(profileJson) as Map);
      final email = profile['email']?.toString().trim().toLowerCase() ?? '';
      if (!email.contains('@')) return <String, dynamic>{};
      final credentialJson = preferences.getString(_legacyCredentialKey);
      if (credentialJson != null) {
        final credentials = Map<String, dynamic>.from(
          jsonDecode(credentialJson) as Map,
        );
        profile['password_hash'] = credentials['password_hash'];
      }
      final migrated = <String, dynamic>{email: profile};
      await preferences.setString(_accountsKey, jsonEncode(migrated));
      await preferences.setString(_activeEmailKey, email);
      return migrated;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<bool> _writeAccounts(
    SharedPreferences preferences,
    Map<String, dynamic> accounts,
  ) => preferences.setString(_accountsKey, jsonEncode(accounts));

  Future<void> save(ClientProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final email = profile.email.trim().toLowerCase();
    final previous = accounts[email] is Map
        ? Map<String, dynamic>.from(accounts[email] as Map)
        : <String, dynamic>{};
    accounts[email] = {
      ...previous,
      'user_id': profile.userId,
      'full_name': profile.fullName,
      'email': email,
      'phone': profile.phone,
      'department': profile.department,
      'city': profile.city,
      // Conservar la copia local si se actualizaron otros datos del perfil.
      // La foto principal vive en Supabase, pero esta copia permite verla
      // mientras se restablece una conexión o se renueva la URL firmada.
      'photo_file_name':
          profile.profilePhotoFileName ?? previous['photo_file_name'],
      'photo_bytes': profile.profilePhotoBytes == null
          ? previous['photo_bytes']
          : base64Encode(profile.profilePhotoBytes!),
    };
    await _writeAccounts(preferences, accounts);
    await preferences.setString(_activeEmailKey, email);
  }

  Future<ClientProfile?> load() => loadActive();

  Future<ClientProfile?> loadActive() async {
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_activeEmailKey);
    if (email == null) return null;
    final accounts = await _readAccounts(preferences);
    final raw = accounts[email];
    return raw is Map ? _profileFromMap(Map<String, dynamic>.from(raw)) : null;
  }

  Future<bool> saveCredentials({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final raw = accounts[normalizedEmail];
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'email': normalizedEmail};
    data['password_hash'] = PasswordKdf.hash(password.trim());
    accounts[normalizedEmail] = data;
    await preferences.setString(_activeEmailKey, normalizedEmail);
    return _writeAccounts(preferences, accounts);
  }

  Future<ClientProfile?> authenticate({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final raw = accounts[normalizedEmail];
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final storedHash = data['password_hash']?.toString() ?? '';
    if (!PasswordKdf.verify(password.trim(), storedHash)) {
      return null;
    }
    if (PasswordKdf.needsUpgrade(storedHash)) {
      data['password_hash'] = PasswordKdf.hash(password.trim());
      accounts[normalizedEmail] = data;
      await _writeAccounts(preferences, accounts);
    }
    final profile = _profileFromMap(data);
    if (profile != null) {
      await preferences.setString(_activeEmailKey, normalizedEmail);
    }
    return profile;
  }

  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeEmailKey);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_accountsKey);
    await preferences.remove(_activeEmailKey);
    await preferences.remove(_legacyProfileKey);
    await preferences.remove(_legacyCredentialKey);
  }

  ClientProfile? _profileFromMap(Map<String, dynamic> data) {
    final email = data['email']?.toString() ?? '';
    if (!email.contains('@')) return null;
    final photo = data['photo_bytes'] as String?;
    try {
      return ClientProfile(
        userId: data['user_id'] as String?,
        fullName: data['full_name'] as String? ?? '',
        email: email,
        phone: data['phone'] as String? ?? '',
        department: data['department'] as String? ?? '',
        city: data['city'] as String? ?? '',
        profilePhotoBytes: photo == null ? null : base64Decode(photo),
        profilePhotoFileName: data['photo_file_name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
