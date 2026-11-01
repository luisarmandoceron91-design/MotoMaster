import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';
import 'client_profile.dart';

class ClientProfileRepository {
  ClientProfileRepository({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  static const _bucket = 'profile-photos';
  final SupabaseClient _client;

  Future<ClientProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (data == null) return null;
    final avatarPath = data['avatar_path'] as String?;
    final avatarUrl = avatarPath == null
        ? null
        : await _client.storage.from(_bucket).createSignedUrl(avatarPath, 3600);
    return ClientProfile.fromDatabase(data, avatarUrl: avatarUrl);
  }

  Future<ClientProfile> save({
    required String fullName,
    required String email,
    required String phone,
    required String department,
    required String city,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    String? avatarPath;
    if (photoBytes != null) {
      final extension = _safeExtension(photoFileName);
      avatarPath = '${user.id}/avatar.$extension';
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            avatarPath,
            photoBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentType(extension),
            ),
          );
    }
    final data = await _client
        .from('profiles')
        .upsert({
          'user_id': user.id,
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone.trim(),
          'department': department.trim(),
          'city': city.trim(),
          'avatar_path': ?avatarPath,
        }, onConflict: 'user_id')
        .select()
        .single();
    final storedPath = data['avatar_path'] as String?;
    final avatarUrl = storedPath == null
        ? null
        : await _client.storage.from(_bucket).createSignedUrl(storedPath, 3600);
    return ClientProfile.fromDatabase(data, avatarUrl: avatarUrl);
  }

  String _safeExtension(String? fileName) {
    final extension = fileName?.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
  }

  String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
