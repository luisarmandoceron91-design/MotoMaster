import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

class TrialExtensionService {
  TrialExtensionService({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;

  bool get hasCloudSession => _client.auth.currentUser != null;

  Future<void> request({
    required String workshopId,
    required int requestedDays,
    required String reason,
  }) async {
    if (!hasCloudSession) {
      throw StateError('No existe una sesión administrativa en la nube.');
    }
    await _client.rpc(
      'request_trial_extension',
      params: {
        'target_workshop_id': workshopId,
        'requested_days': requestedDays,
        'request_reason': reason.trim(),
      },
    );
  }
}
