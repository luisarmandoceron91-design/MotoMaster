import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/local_workshop_admin_store.dart';
import '../networking/api_client.dart';
import 'local_workshop_directory_store.dart';
import 'workshop.dart';
import 'workshop_identity.dart';

class WorkshopRepository {
  WorkshopRepository({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;
  final LocalWorkshopDirectoryStore _local = LocalWorkshopDirectoryStore();

  bool get isAuthenticated =>
      !ApiClient.cloudEnabled || _client.auth.currentUser != null;

  Future<List<Workshop>> listActive() async {
    final accounts = await LocalWorkshopAdminStore().listAccounts();
    await _local.syncRegisteredAccounts(accounts);
    final localRecords = await _local.listAll();
    final localById = <String, Workshop>{
      for (final item in localRecords)
        if (item.hasPlatformAccess) item.id: item,
    };
    for (final account in accounts.where((item) => item.hasWorkshop)) {
      if (account.deletedAt != null || !account.canEnter) {
        localById.remove(account.tenantId);
        continue;
      }
      localById[account.tenantId] = _withCurrentAccountAccess(
        localById[account.tenantId],
        account,
      );
    }
    final localItems = canonicalWorkshops(localById.values);
    if (!ApiClient.cloudEnabled) return localItems;
    try {
      // Incluso autenticado se usa una RPC con columnas permitidas. Consultar
      // la tabla directamente podria exponer campos internos del taller.
      final rows = await _client
          .rpc('list_active_workshops')
          .timeout(const Duration(seconds: 5));
      final cloudItems = <Workshop>[
        for (final row in rows) _workshopFromRow(row),
      ];
      await _local.syncPublicDirectory(cloudItems);
      final merged = <String, Workshop>{
        for (final item in cloudItems) item.id: item,
        // The owner's latest local decision must win over a stale cloud copy.
        for (final item in localItems) item.id: item,
      };
      return canonicalWorkshops(
        merged.values.where((item) => item.hasPlatformAccess),
      );
    } catch (error) {
      if (_isConnectionFailure(error)) return localItems;
      rethrow;
    }
  }

  Workshop _withCurrentAccountAccess(
    Workshop? workshop,
    LocalWorkshopAdminAccount account,
  ) {
    final current =
        workshop ??
        Workshop(
          id: account.tenantId,
          name: account.tenantName.isEmpty
              ? 'Taller registrado'
              : account.tenantName,
          slug: account.tenantId,
          tagline: '',
          accentColorValue: 0xFFFF6500,
        );
    final data = current.toMap()
      ..['access_status'] = account.accessState.name
      ..['trial_started_at'] = account.trialStartedAt.toIso8601String()
      ..['trial_ends_at'] = account.trialEndsAt.toIso8601String()
      ..['permanent_access'] =
          account.accessState == WorkshopAccessState.active;
    return Workshop.fromMap(data, logoUrl: current.logoUrl);
  }

  Future<List<Workshop>> listManaged() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final memberships = await _client
        .from('workshop_members')
        .select('workshop_id')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .inFilter('role', ['owner', 'admin']);
    final ids = memberships.map((row) => row['workshop_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('workshops')
        .select()
        .inFilter('id', ids)
        .isFilter('deleted_at', null)
        .order('name');
    return rows.map(_workshopFromRow).toList();
  }

  Future<void> joinAsClient(String workshopId) async {
    if (!ApiClient.cloudEnabled) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('client_workshops').upsert({
      'workshop_id': workshopId,
      'client_id': user.id,
      'status': 'active',
    }, onConflict: 'workshop_id,client_id');
  }

  Future<List<String>> listJoinedIds() async {
    if (!ApiClient.cloudEnabled) return const [];
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('client_workshops')
        .select('workshop_id')
        .eq('client_id', user.id)
        .eq('status', 'active');
    return rows.map((row) => row['workshop_id'] as String).toList();
  }

  Future<void> leaveAsClient(String workshopId) async {
    if (!ApiClient.cloudEnabled) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('client_workshops')
        .update({'status': 'inactive'})
        .eq('workshop_id', workshopId)
        .eq('client_id', user.id);
  }

  Future<Workshop> create({
    required String name,
    required String slug,
    String tagline = '',
    int accentColor = 0xFFFF5A00,
    int logoIndex = 0,
    String department = '',
    String municipality = '',
    String neighborhood = '',
    String address = '',
    String phone = '',
    String email = '',
    Map<String, dynamic> openingHours = const {},
  }) async {
    final user = _client.auth.currentUser;
    if (!ApiClient.cloudEnabled || user == null) {
      final now = DateTime.now();
      final workshop = Workshop(
        id: 'local-${now.microsecondsSinceEpoch}',
        name: name.trim(),
        slug: slug.trim().toLowerCase(),
        tagline: tagline.trim(),
        accentColorValue: accentColor,
        logoIndex: logoIndex,
        department: department.trim(),
        municipality: municipality.trim(),
        neighborhood: neighborhood.trim(),
        address: address.trim(),
        phone: phone.trim(),
        email: email.trim().toLowerCase(),
        openingHours: openingHours,
        trialStartedAt: now,
        trialEndsAt: now.add(const Duration(days: 3)),
      );
      await _local.upsert(workshop);
      return workshop;
    }
    final response = await _client.rpc(
      'create_or_recover_trial_workshop',
      params: {
        'p_name': name.trim(),
        'p_slug': slug.trim().toLowerCase(),
        'p_tagline': tagline.trim(),
        'p_accent_color': accentColor,
        'p_department': department.trim(),
        'p_municipality': municipality.trim(),
        'p_neighborhood': neighborhood.trim(),
        'p_address': address.trim(),
        'p_phone': phone.trim(),
        'p_email': email.trim().toLowerCase(),
        'p_opening_hours': openingHours,
      },
    );
    final row = Map<String, dynamic>.from(response as Map);
    final workshop = _workshopFromRow(row);
    await _local.upsert(workshop);
    return workshop;
  }

  Future<void> save(Workshop workshop) async {
    await _local.upsert(workshop);
    if (!ApiClient.cloudEnabled || _client.auth.currentUser == null) return;

    String? logoPath = workshop.logoPath;
    if (workshop.logoBytes != null) {
      final extension = _safeLogoExtension(workshop.logoFileName);
      logoPath = '${workshop.id}/logo.$extension';
      await _client.storage
          .from('workshop-assets')
          .uploadBinary(
            logoPath,
            workshop.logoBytes!,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _logoContentType(extension),
            ),
          );
    }
    await _client
        .from('workshops')
        .update({
          'name': workshop.name,
          'tagline': workshop.tagline,
          'accent_color': workshop.accentColorValue,
          'logo_index': workshop.logoIndex,
          'logo_path': logoPath,
          'department': workshop.department,
          'municipality': workshop.municipality,
          'neighborhood': workshop.neighborhood,
          'address': workshop.address,
          'phone': workshop.phone,
          'email': workshop.email,
          'opening_hours': workshop.openingHours,
        })
        .eq('id', workshop.id);
  }

  Workshop _workshopFromRow(Map<String, dynamic> row) {
    final logoPath = row['logo_path'] as String?;
    final logoUrl = logoPath == null || logoPath.isEmpty
        ? null
        : _client.storage.from('workshop-assets').getPublicUrl(logoPath);
    return Workshop.fromMap(row, logoUrl: logoUrl);
  }

  String _safeLogoExtension(String? fileName) {
    final extension = fileName?.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'jpg',
      'webp' => 'webp',
      _ => 'png',
    };
  }

  String _logoContentType(String extension) => switch (extension) {
    'jpg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };

  bool _isConnectionFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed to fetch') ||
        message.contains('socketexception') ||
        message.contains('host desconocido') ||
        message.contains('network');
  }
}
