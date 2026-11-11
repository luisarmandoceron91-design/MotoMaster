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

    // Primero reutilizamos lo que ya está guardado. Así cada cliente tiene
    // un historial único con cada taller, visible desde todos sus equipos.
    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('workshop_id', workshopId)
        .eq('client_id', user.id)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    // Todo cliente que abre el soporte queda vinculado al taller antes de
    // crear la conversación. Sin este paso la política de seguridad puede
    // permitir un chat solo local y el administrador nunca lo ve.
    final membership = await _client
        .from('client_workshops')
        .select('status')
        .eq('workshop_id', workshopId)
        .eq('client_id', user.id)
        .maybeSingle();
    if (membership == null) {
      await _client.from('client_workshops').insert({
        'workshop_id': workshopId,
        'client_id': user.id,
        'status': 'active',
      });
    } else if (membership['status'] != 'active') {
      await _client
          .from('client_workshops')
          .update({'status': 'active'})
          .eq('workshop_id', workshopId)
          .eq('client_id', user.id);
    }

    try {
      final row = await _client
          .from('conversations')
          .insert({
            'workshop_id': workshopId,
            'client_id': user.id,
            'status': 'open',
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (_) {
      // Dos toques rápidos o dos dispositivos pueden crear el chat al mismo
      // tiempo. En ese caso tomamos la conversación creada por el otro.
      final concurrent = await _client
          .from('conversations')
          .select('id')
          .eq('workshop_id', workshopId)
          .eq('client_id', user.id)
          .maybeSingle();
      if (concurrent != null) return concurrent['id'] as String;
      rethrow;
    }
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

  /// El emisor puede retirar un mensaje con archivo que envió por error.
  /// La política de Supabase valida nuevamente que el mensaje le pertenece.
  Future<void> deleteOwnMessage({
    required String messageId,
    String? attachmentPath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final deleted = await _client
        .from('messages')
        .delete()
        .eq('id', messageId)
        .eq('sender_id', user.id)
        .select('attachment_path');
    if (deleted.isEmpty) {
      throw StateError('No tienes permiso para eliminar este mensaje.');
    }
    final path = deleted.first['attachment_path']?.toString().trim();
    final safePath = path?.isNotEmpty == true ? path : attachmentPath?.trim();
    if (safePath != null && safePath.isNotEmpty) {
      await _client.storage.from('chat-attachments').remove([safePath]);
    }
  }

  Future<String> signedAttachmentUrl(String path) =>
      _client.storage.from('chat-attachments').createSignedUrl(path, 3600);
}
