import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

class ChatRepository {
  ChatRepository({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<String> openConversation({required String workshopId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final row = await _client
        .from('conversations')
        .upsert({
          'workshop_id': workshopId,
          'client_id': user.id,
          'status': 'open',
        }, onConflict: 'workshop_id,client_id')
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> openWorkshopConversation({
    required String workshopId,
    required String clientId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final row = await _client
        .from('conversations')
        .upsert({
          'workshop_id': workshopId,
          'client_id': clientId,
          'status': 'open',
        }, onConflict: 'workshop_id,client_id')
        .select('id')
        .single();
    return row['id'] as String;
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Stream<List<Map<String, dynamic>>> watchWorkshopConversations(
    String workshopId,
  ) {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('workshop_id', workshopId)
        .order('last_message_at', ascending: false)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<void> markConversationRead(String conversationId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', user.id)
        .isFilter('read_at', null);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'body': body.trim(),
    });
    // Un trigger de base de datos actualiza last_message_at. El cliente no
    // recibe permiso para editar otros campos de la conversacion.
  }

  Future<void> sendAttachment({
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String body = '',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final safeName = fileName.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final path =
        '$conversationId/${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from('chat-attachments')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'body': body.trim(),
        'attachment_path': path,
      });
    } catch (_) {
      await _client.storage.from('chat-attachments').remove([path]);
      rethrow;
    }
  }

  Future<String> signedAttachmentUrl(String path) =>
      _client.storage.from('chat-attachments').createSignedUrl(path, 3600);
}
