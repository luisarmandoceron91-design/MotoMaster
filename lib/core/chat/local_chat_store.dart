import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class LocalChatMessage {
  const LocalChatMessage({
    required this.id,
    required this.workshopId,
    required this.workshopName,
    required this.clientName,
    required this.clientEmail,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String workshopId;
  final String workshopName;
  final String clientName;
  final String clientEmail;
  final String sender;
  final String body;
  final DateTime createdAt;

  bool get sentByClient => sender == 'client';
  bool get sentByWorkshop => sender == 'workshop';

  Map<String, dynamic> toMap() => {
    'id': id,
    'workshop_id': workshopId,
    'workshop_name': workshopName,
    'client_name': clientName,
    'client_email': clientEmail,
    'sender': sender,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  factory LocalChatMessage.fromMap(Map<String, dynamic> data) =>
      LocalChatMessage(
        id: data['id']?.toString() ?? '',
        workshopId: data['workshop_id']?.toString() ?? '',
        workshopName: data['workshop_name']?.toString() ?? '',
        clientName: data['client_name']?.toString() ?? 'Cliente',
        clientEmail: data['client_email']?.toString() ?? '',
        sender: data['sender']?.toString() ?? 'client',
        body: data['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(data['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

@immutable
class LocalChatConversation {
  const LocalChatConversation({
    required this.workshopId,
    required this.workshopName,
    required this.clientName,
    required this.clientEmail,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  final String workshopId;
  final String workshopName;
  final String clientName;
  final String clientEmail;
  final String lastMessage;
  final DateTime lastMessageAt;
}

/// Chat local compartido entre las pantallas de cliente y administrador.
/// Cada consulta se limita siempre al identificador del taller.
class LocalChatStore {
  static const _key = 'local_workshop_chat_v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  String _email(String value) => value.trim().toLowerCase();

  Future<List<LocalChatMessage>> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return <LocalChatMessage>[];
    try {
      final values = jsonDecode(encoded) as List;
      return values
          .whereType<Map>()
          .map(
            (item) => LocalChatMessage.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (_) {
      return <LocalChatMessage>[];
    }
  }

  Future<void> _write(List<LocalChatMessage> messages) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(messages.map((message) => message.toMap()).toList()),
    );
    revision.value++;
  }

  Future<List<LocalChatMessage>> listMessages({
    required String workshopId,
    required String clientEmail,
  }) async {
    final email = _email(clientEmail);
    final messages = await _read();
    return messages
        .where(
          (message) =>
              message.workshopId == workshopId &&
              _email(message.clientEmail) == email,
        )
        .toList();
  }

  Future<List<LocalChatConversation>> listConversations(
    String workshopId,
  ) async {
    final messages = (await _read())
        .where((message) => message.workshopId == workshopId)
        .toList();
    final byClient = <String, List<LocalChatMessage>>{};
    for (final message in messages) {
      byClient.putIfAbsent(_email(message.clientEmail), () => []).add(message);
    }
    final conversations = <LocalChatConversation>[
      for (final entry in byClient.entries)
        if (entry.value.isNotEmpty)
          LocalChatConversation(
            workshopId: workshopId,
            workshopName: entry.value.last.workshopName,
            clientName: entry.value.last.clientName,
            clientEmail: entry.value.last.clientEmail,
            lastMessage: entry.value.last.body,
            lastMessageAt: entry.value.last.createdAt,
          ),
    ];
    conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return conversations;
  }

  Future<void> sendClientMessage({
    required String workshopId,
    required String workshopName,
    required String clientName,
    required String clientEmail,
    required String body,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) return;
    final messages = await _read();
    final email = _email(clientEmail);
    final conversation = messages.where(
      (message) =>
          message.workshopId == workshopId &&
          _email(message.clientEmail) == email,
    );
    final hasAutomaticGreeting = conversation.any(
      (message) => message.sender == 'automatic',
    );
    final now = DateTime.now();
    messages.add(
      LocalChatMessage(
        id: 'client-${now.microsecondsSinceEpoch}',
        workshopId: workshopId,
        workshopName: workshopName.trim(),
        clientName: clientName.trim(),
        clientEmail: email,
        sender: 'client',
        body: cleanBody,
        createdAt: now,
      ),
    );
    if (!hasAutomaticGreeting) {
      messages.add(
        LocalChatMessage(
          id: 'automatic-${now.microsecondsSinceEpoch}',
          workshopId: workshopId,
          workshopName: workshopName.trim(),
          clientName: clientName.trim(),
          clientEmail: email,
          sender: 'automatic',
          body:
              '¡Hola! Bienvenido a ${workshopName.trim()}, ¿en qué podemos ayudarte?',
          createdAt: now.add(const Duration(milliseconds: 1)),
        ),
      );
    }
    await _write(messages);
  }

  Future<void> sendWorkshopMessage({
    required String workshopId,
    required String workshopName,
    required String clientName,
    required String clientEmail,
    required String body,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) return;
    final messages = await _read();
    final now = DateTime.now();
    messages.add(
      LocalChatMessage(
        id: 'workshop-${now.microsecondsSinceEpoch}',
        workshopId: workshopId,
        workshopName: workshopName.trim(),
        clientName: clientName.trim(),
        clientEmail: _email(clientEmail),
        sender: 'workshop',
        body: cleanBody,
        createdAt: now,
      ),
    );
    await _write(messages);
  }

  Future<void> purgeWorkshop(String workshopId) async {
    final messages = await _read();
    await _write(
      messages.where((message) => message.workshopId != workshopId).toList(),
    );
  }
}
