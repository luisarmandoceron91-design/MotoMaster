import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

enum AdminAccessRole {
  platformOwner,
  workshopOwner,
  workshopStaff,
  workshopSuspended,
  workshopExpired,
}

class AdminAccessService {
  AdminAccessService({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;

  Future<AdminAccessRole?> resolveRole() async {
    final value = await _client.rpc('resolve_admin_access');
    return switch (value) {
      'platform_owner' => AdminAccessRole.platformOwner,
      'workshop_owner' => AdminAccessRole.workshopOwner,
      'workshop_staff' => AdminAccessRole.workshopStaff,
      'workshop_suspended' => AdminAccessRole.workshopSuspended,
      'workshop_expired' => AdminAccessRole.workshopExpired,
      _ => null,
    };
  }
}
