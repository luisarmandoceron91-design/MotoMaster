import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';
import '../workshops/workshop_clients_service.dart';

/// Datos que necesita el administrador para mostrar una conversación en la
/// bandeja del taller. Todo se calcula desde Supabase: no depende de la copia
/// guardada en el teléfono o computador que esté usando el administrador.
class WorkshopChatPreview {
  const WorkshopChatPreview({
    required this.conversationId,
    required this.clientId,
    required this.clientName,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
    this.avatarUrl,
  });

  final String conversationId;
  final String clientId;
  final String clientName;
  final String lastMessage;
  final DateTime? updatedAt;
  final int unreadCount;
  final String? avatarUrl;
}

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
        // El stream de Realtime puede llegar en distinto orden según el
        // dispositivo. Ordenamos nuevamente para que la conversación nunca
        // invierta mensajes ni haga que parezcan desaparecer al actualizar.
        .map((rows) {
          final messages = rows
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
          messages.sort(
            (a, b) => (a['created_at']?.toString() ?? '').compareTo(
              b['created_at']?.toString() ?? '',
            ),
          );
          return messages;
        });
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

  /// Completa la lista de conversaciones del taller con el perfil real del
  /// cliente, el último mensaje y los mensajes que aún no ha leído el taller.
  /// Se llama cada vez que cambia el stream de conversaciones, por eso la
  /// bandeja queda igual en celular, tableta y computador.
  Future<List<WorkshopChatPreview>> workshopPreviews({
    required String workshopId,
    required List<Map<String, dynamic>> conversations,
  }) async {
    if (conversations.isEmpty) return const [];
    final ids = conversations
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return const [];

    // El panel de chat no debe quedar vacío si un perfil antiguo no puede
    // consultarse. Las conversaciones y sus mensajes siguen siendo la fuente
    // oficial y se muestran con el nombre genérico mientras llega el perfil.
    List<WorkshopClientRecord> clients = const [];
    try {
      clients = await WorkshopClientsService(client: _client).list(workshopId);
    } catch (_) {}
    final clientsById = {for (final client in clients) client.userId: client};
    List<dynamic> rows = const [];
    try {
      rows = await _client
          .from('messages')
          .select(
            'conversation_id, sender_id, body, attachment_path, read_at, created_at',
          )
          .inFilter('conversation_id', ids)
          .order('created_at', ascending: false);
    } catch (_) {}
    final currentId = currentUserId;
    final latest = <String, Map<String, dynamic>>{};
    final unread = <String, int>{};
    for (final raw in rows) {
      final message = Map<String, dynamic>.from(raw);
      final conversationId = message['conversation_id']?.toString() ?? '';
      if (conversationId.isEmpty) continue;
      latest.putIfAbsent(conversationId, () => message);
      if (message['sender_id']?.toString() != currentId &&
          message['read_at'] == null) {
        unread.update(conversationId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return conversations
        .map((conversation) {
          final conversationId = conversation['id']?.toString() ?? '';
          final clientId = conversation['client_id']?.toString() ?? '';
          final client = clientsById[clientId];
          final message = latest[conversationId];
          final body = message?['body']?.toString().trim() ?? '';
          final hasAttachment =
              (message?['attachment_path']?.toString().trim() ?? '').isNotEmpty;
          return WorkshopChatPreview(
            conversationId: conversationId,
            clientId: clientId,
            clientName: client?.fullName.trim().isNotEmpty == true
                ? client!.fullName
                : 'Cliente',
            avatarUrl: client?.avatarUrl,
            lastMessage: body.isNotEmpty
                ? body
                : hasAttachment
                ? 'Adjunto enviado'
                : 'Sin mensajes todavía',
            updatedAt: DateTime.tryParse(
              message?['created_at']?.toString() ??
                  conversation['last_message_at']?.toString() ??
                  '',
            ),
            unreadCount: unread[conversationId] ?? 0,
          );
        })
        .toList(growable: false);
  }

  Future<void> markConversationRead(String conversationId) async {
    if (_client.auth.currentUser == null) return;
    // Una falla al marcar como leído nunca debe impedir abrir el chat.
    try {
      await _client.rpc(
        'mark_conversation_read',
        params: {'target_conversation_id': conversationId},
      );
    } catch (_) {}
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
