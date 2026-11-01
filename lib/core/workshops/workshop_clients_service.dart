import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

class WorkshopClientRecord {
  const WorkshopClientRecord({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.status,
    required this.joinedAt,
    required this.motorcycleCount,
    this.avatarUrl,
  });

  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String status;
  final DateTime? joinedAt;
  final int motorcycleCount;
  final String? avatarUrl;

  bool get isActive => status == 'active';
}

class WorkshopClientsService {
  WorkshopClientsService({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;

  Future<List<WorkshopClientRecord>> list(String workshopId) async {
    if (_client.auth.currentUser == null || workshopId.isEmpty) return const [];
    final response = await _client.rpc(
      'list_workshop_clients',
      params: {'target_workshop_id': workshopId},
    );
    final clients = (response as List)
        .map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return WorkshopClientRecord(
            userId: row['user_id'].toString(),
            fullName: row['full_name']?.toString() ?? 'Cliente',
            email: row['email']?.toString() ?? '',
            phone: row['phone']?.toString() ?? '',
            status: row['status']?.toString() ?? 'active',
            joinedAt: DateTime.tryParse(row['joined_at']?.toString() ?? ''),
            motorcycleCount: (row['motorcycle_count'] as num?)?.toInt() ?? 0,
          );
        })
        .where((client) => client.status != 'archived')
        .toList();
    if (clients.isEmpty) return clients;

    final profileRows = await _client
        .from('profiles')
        .select('user_id, avatar_path')
        .inFilter('user_id', clients.map((client) => client.userId).toList());
    final avatarPaths = <String, String>{
      for (final raw in profileRows)
        if ((raw['avatar_path']?.toString().trim() ?? '').isNotEmpty)
          raw['user_id'].toString(): raw['avatar_path'].toString(),
    };
    return Future.wait(
      clients.map((client) async {
        final path = avatarPaths[client.userId];
        String? avatarUrl;
        if (path != null) {
          try {
            avatarUrl = await _client.storage
                .from('profile-photos')
                .createSignedUrl(path, 3600);
          } catch (_) {}
        }
        return WorkshopClientRecord(
          userId: client.userId,
          fullName: client.fullName,
          email: client.email,
          phone: client.phone,
          status: client.status,
          joinedAt: client.joinedAt,
          motorcycleCount: client.motorcycleCount,
          avatarUrl: avatarUrl,
        );
      }),
    );
  }

  Future<void> removeFromList({
    required String workshopId,
    required String clientId,
  }) async {
    if (_client.auth.currentUser == null ||
        workshopId.isEmpty ||
        clientId.isEmpty) {
      return;
    }
    await _client
        .from('client_workshops')
        .update({'status': 'archived'})
        .eq('workshop_id', workshopId)
        .eq('client_id', clientId);
  }
}
