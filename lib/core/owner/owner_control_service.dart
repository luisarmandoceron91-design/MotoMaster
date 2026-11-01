import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

class OwnerWorkshopRecord {
  const OwnerWorkshopRecord({
    required this.id,
    required this.name,
    required this.location,
    required this.plan,
    required this.status,
    required this.accessStatus,
    required this.createdAt,
    required this.trialEndsAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.purgeAfter,
    required this.administratorCount,
    required this.clientCount,
  });

  final String id;
  final String name;
  final String location;
  final String plan;
  final String status;
  final String accessStatus;
  final DateTime? createdAt;
  final DateTime? trialEndsAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final DateTime? purgeAfter;
  final int administratorCount;
  final int clientCount;

  bool get isDeleted => deletedAt != null;
}

class OwnerAccountRecord {
  const OwnerAccountRecord({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.workshopName,
    required this.status,
    required this.createdAt,
  });

  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String workshopName;
  final String status;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
}

class OwnerTrialExtensionRequest {
  const OwnerTrialExtensionRequest({
    required this.id,
    required this.workshopId,
    required this.workshopName,
    required this.requestedDays,
    required this.reason,
    required this.requestedAt,
  });

  final String id;
  final String workshopId;
  final String workshopName;
  final int requestedDays;
  final String reason;
  final DateTime requestedAt;
}

class OwnerControlService {
  OwnerControlService({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;

  bool get hasCloudSession => _client.auth.currentUser != null;

  Future<List<OwnerWorkshopRecord>> listWorkshops() async {
    if (!hasCloudSession) return const [];
    final response = await _client.rpc('owner_list_workshops');
    return (response as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final location =
          [row['municipality'], row['department'], row['neighborhood']]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(', ');
      return OwnerWorkshopRecord(
        id: row['id'] as String,
        name: row['name'] as String,
        location: location,
        plan: row['permanent_access'] == true
            ? 'Acceso permanente'
            : 'Prueba gratuita',
        status: row['status'] as String? ?? 'active',
        accessStatus: row['access_status'] as String? ?? 'trial',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        trialEndsAt: DateTime.tryParse(row['trial_ends_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
        deletedAt: DateTime.tryParse(row['deleted_at']?.toString() ?? ''),
        purgeAfter: DateTime.tryParse(row['purge_after']?.toString() ?? ''),
        administratorCount: (row['administrator_count'] as num?)?.toInt() ?? 0,
        clientCount: (row['client_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<OwnerAccountRecord>> listAccounts() async {
    if (!hasCloudSession) return const [];
    final response = await _client.rpc('owner_list_platform_accounts');
    return (response as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return OwnerAccountRecord(
        userId: row['user_id'].toString(),
        fullName: row['full_name']?.toString() ?? 'Usuario',
        email: row['email']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        role: row['account_role']?.toString() ?? 'Usuario',
        workshopName: row['workshop_name']?.toString() ?? '',
        status: row['account_status']?.toString() ?? 'active',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<List<OwnerTrialExtensionRequest>>
  listPendingTrialExtensionRequests() async {
    if (!hasCloudSession) return const [];
    final rows = await _client.rpc('owner_list_trial_extension_requests');
    return (rows as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return OwnerTrialExtensionRequest(
        id: row['request_id'] as String,
        workshopId: row['workshop_id'] as String,
        workshopName: row['workshop_name'] as String,
        requestedDays: row['requested_days'] as int,
        reason: row['request_reason'] as String,
        requestedAt: DateTime.parse(row['requested_at'] as String),
      );
    }).toList();
  }

  Future<void> setWorkshopStatus({
    required String workshopId,
    required String status,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    await _client.rpc(
      'owner_set_workshop_status',
      params: {
        'target_workshop_id': workshopId,
        'new_status': status,
        'change_reason': reason.trim(),
      },
    );
  }

  Future<void> setWorkshopAvailability({
    required String workshopId,
    required bool enabled,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    await _client.rpc(
      'owner_set_workshop_availability',
      params: {
        'target_workshop_id': workshopId,
        'enabled': enabled,
        'change_reason': reason.trim(),
      },
    );
  }

  Future<void> setWorkshopAccess({
    required String workshopId,
    required String accessStatus,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    await _client.rpc(
      'owner_set_workshop_access',
      params: {
        'target_workshop_id': workshopId,
        'new_access_status': accessStatus,
        'change_reason': reason.trim(),
      },
    );
  }

  Future<DateTime> extendWorkshopTrial({
    required String workshopId,
    required int additionalDays,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    final result = await _client.rpc(
      'owner_extend_workshop_trial',
      params: {
        'target_workshop_id': workshopId,
        'additional_days': additionalDays,
        'change_reason': reason.trim(),
      },
    );
    final value = result is String
        ? result
        : result is Map
        ? result['trial_ends_at']?.toString()
        : result?.toString();
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) {
      throw StateError('El servidor no devolvió la nueva fecha de prueba.');
    }
    return parsed;
  }

  Future<void> deleteWorkshop({
    required String workshopId,
    required String confirmationName,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    await _client.rpc(
      'owner_delete_workshop',
      params: {
        'target_workshop_id': workshopId,
        'confirmation_name': confirmationName.trim(),
        'deletion_reason': reason.trim(),
      },
    );
  }

  Future<void> restoreWorkshop({
    required String workshopId,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    await _client.rpc(
      'owner_restore_workshop',
      params: {
        'target_workshop_id': workshopId,
        'restore_reason': reason.trim(),
      },
    );
  }

  Future<void> purgeWorkshop({
    required String workshopId,
    required String confirmationName,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    await _client.rpc(
      'owner_purge_workshop',
      params: {
        'target_workshop_id': workshopId,
        'confirmation_name': confirmationName.trim(),
        'deletion_reason': reason.trim(),
      },
    );
  }

  Future<DateTime?> decideTrialExtension({
    required String requestId,
    required bool approve,
    required int grantedDays,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión propietaria en la nube.');
    }
    final result = await _client.rpc(
      'owner_decide_trial_extension',
      params: {
        'target_request_id': requestId,
        'approve_request': approve,
        'granted_days': grantedDays,
        'decision_reason': reason.trim(),
      },
    );
    if (!approve || result == null) return null;
    return DateTime.tryParse(result.toString());
  }
}
