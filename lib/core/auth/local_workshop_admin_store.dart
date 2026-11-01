import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../security/password_kdf.dart';

enum WorkshopAccessState { trial, active, expired, suspended }

class LocalTrialExtensionRequest {
  const LocalTrialExtensionRequest({
    required this.accountEmail,
    required this.tenantId,
    required this.tenantName,
    required this.requestedDays,
    required this.reason,
    required this.requestedAt,
  });

  final String accountEmail;
  final String tenantId;
  final String tenantName;
  final int requestedDays;
  final String reason;
  final DateTime requestedAt;
}

class LocalWorkshopAdminAccount {
  const LocalWorkshopAdminAccount({
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.trialStartedAt,
    required this.trialEndsAt,
    required this.accessState,
    this.tenantId = '',
    this.tenantName = '',
    this.deletedAt,
    this.purgeAfter,
  });

  final String username;
  final String fullName;
  final String email;
  final String phone;
  final DateTime trialStartedAt;
  final DateTime trialEndsAt;
  final WorkshopAccessState accessState;
  final String tenantId;
  final String tenantName;
  final DateTime? deletedAt;
  final DateTime? purgeAfter;

  bool get hasWorkshop => tenantId.isNotEmpty;
  bool get canEnter =>
      accessState == WorkshopAccessState.active ||
      (accessState == WorkshopAccessState.trial &&
          DateTime.now().isBefore(trialEndsAt));

  Duration get trialRemaining {
    final remaining = trialEndsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Persistencia local multi-cuenta. Cada correo conserva su propia relación
/// con un taller y la marca se almacena por el tenantId asignado.
class LocalWorkshopAdminStore {
  static const bootstrapUsername = 'admin';
  static const bootstrapPassword = '123456';
  static const trialDuration = Duration(days: 3);

  static const _accountsKey = 'workshop_admin_accounts_v3';
  static const _activeEmailKey = 'active_workshop_admin_email_v3';
  static const _legacyAccountKey = 'workshop_admin_account_v2';
  static const _legacyTenantIdKey = 'active_tenant_id';
  static const _legacyTenantNameKey = 'active_tenant_name';

  bool isBootstrapCredential(String username, String password) =>
      username.trim().toLowerCase() == bootstrapUsername &&
      password == bootstrapPassword;

  Future<Map<String, dynamic>> _readAccounts(
    SharedPreferences preferences,
  ) async {
    final encoded = preferences.getString(_accountsKey);
    if (encoded != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      } catch (_) {}
    }

    final legacy = preferences.getString(_legacyAccountKey);
    if (legacy == null) return <String, dynamic>{};
    try {
      final account = Map<String, dynamic>.from(jsonDecode(legacy) as Map);
      final email = account['email']?.toString().trim().toLowerCase() ?? '';
      if (!email.contains('@')) return <String, dynamic>{};
      account['username'] = email;
      account['tenant_id'] =
          account['tenant_id']?.toString() ??
          preferences.getString(_legacyTenantIdKey) ??
          '';
      account['tenant_name'] =
          account['tenant_name']?.toString() ??
          preferences.getString(_legacyTenantNameKey) ??
          '';
      final migrated = <String, dynamic>{email: account};
      await preferences.setString(_accountsKey, jsonEncode(migrated));
      await preferences.setString(_activeEmailKey, email);
      return migrated;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<bool> _writeAccounts(
    SharedPreferences preferences,
    Map<String, dynamic> accounts,
  ) => preferences.setString(_accountsKey, jsonEncode(accounts));

  Future<LocalWorkshopAdminAccount?> loadAccount() async {
    final preferences = await SharedPreferences.getInstance();
    final activeEmail = preferences
        .getString(_activeEmailKey)
        ?.trim()
        .toLowerCase();
    if (activeEmail == null || activeEmail.isEmpty) return null;
    final accounts = await _readAccounts(preferences);
    final data = accounts[activeEmail];
    return data is Map ? _fromMap(Map<String, dynamic>.from(data)) : null;
  }

  Future<List<LocalWorkshopAdminAccount>> listAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    return accounts.values
        .whereType<Map>()
        .map((raw) => _fromMap(Map<String, dynamic>.from(raw)))
        .whereType<LocalWorkshopAdminAccount>()
        .toList();
  }

  Future<String?> register({
    required String password,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    if (!normalizedEmail.contains('@')) {
      return 'Ingresa un correo electrónico válido.';
    }
    if (normalizedPassword.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    if (accounts.containsKey(normalizedEmail)) {
      return 'Este correo ya está registrado. Inicia sesión.';
    }
    final now = DateTime.now();
    accounts[normalizedEmail] = {
      'username': normalizedEmail,
      'password_hash': PasswordKdf.hash(normalizedPassword),
      'full_name': fullName.trim(),
      'email': normalizedEmail,
      'phone': phone.trim(),
      'trial_started_at': now.toIso8601String(),
      'trial_ends_at': now.add(trialDuration).toIso8601String(),
      'access_state': WorkshopAccessState.trial.name,
      'tenant_id': '',
      'tenant_name': '',
    };
    if (!await _writeAccounts(preferences, accounts) ||
        !await preferences.setString(_activeEmailKey, normalizedEmail)) {
      return 'No fue posible guardar la cuenta en este dispositivo.';
    }

    // La cuenta acaba de ser escrita y la sesión activa ya quedó guardada.
    // Volver a llamar authenticate() aquí repetía PBKDF2 por segunda vez y en
    // Flutter web bloqueaba innecesariamente la transición a la configuración
    // del taller. La contraseña se verificará normalmente en futuros ingresos.
    return null;
  }

  Future<LocalWorkshopAdminAccount?> authenticate({
    required String username,
    required String password,
  }) async {
    final email = username.trim().toLowerCase();
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final raw = accounts[email];
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final storedHash = data['password_hash']?.toString() ?? '';
    if (!PasswordKdf.verify(password.trim(), storedHash)) {
      return null;
    }
    if (PasswordKdf.needsUpgrade(storedHash)) {
      data['password_hash'] = PasswordKdf.hash(password.trim());
      accounts[email] = data;
      await _writeAccounts(preferences, accounts);
    }
    await preferences.setString(_activeEmailKey, email);
    return _fromMap(data);
  }

  Future<String?> attachWorkshopToActiveAccount({
    required String tenantId,
    required String tenantName,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_activeEmailKey);
    if (email == null) return 'No existe una sesión administrativa activa.';
    final accounts = await _readAccounts(preferences);
    final raw = accounts[email];
    if (raw is! Map) return 'No encontramos la cuenta administrativa.';
    final data = Map<String, dynamic>.from(raw);
    data['tenant_id'] = tenantId;
    data['tenant_name'] = tenantName.trim();
    accounts[email] = data;
    return await _writeAccounts(preferences, accounts)
        ? null
        : 'No fue posible asociar el taller con esta cuenta.';
  }

  Future<String?> changeCredentials({
    required String currentPassword,
    required String newEmail,
    required String newPassword,
  }) async {
    final current = await loadAccount();
    if (current == null) return 'No existe una cuenta local activa.';
    if (await authenticate(
          username: current.email,
          password: currentPassword,
        ) ==
        null) {
      return 'La contraseña actual no es correcta.';
    }
    final email = newEmail.trim().toLowerCase();
    if (!email.contains('@')) return 'Ingresa un correo electrónico válido.';
    if (newPassword.isNotEmpty && newPassword.trim().length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    if (email != current.email && accounts.containsKey(email)) {
      return 'Ese correo ya pertenece a otra cuenta.';
    }
    final data = Map<String, dynamic>.from(accounts[current.email] as Map);
    data['username'] = email;
    data['email'] = email;
    if (newPassword.isNotEmpty) {
      data['password_hash'] = PasswordKdf.hash(newPassword.trim());
    }
    accounts.remove(current.email);
    accounts[email] = data;
    final saved = await _writeAccounts(preferences, accounts);
    await preferences.setString(_activeEmailKey, email);
    return saved ? null : 'No fue posible guardar las credenciales.';
  }

  Future<void> setAccessState(WorkshopAccessState state) async {
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_activeEmailKey);
    if (email == null) return;
    final accounts = await _readAccounts(preferences);
    final raw = accounts[email];
    if (raw is! Map) return;
    final data = Map<String, dynamic>.from(raw);
    data['access_state'] = state.name;
    accounts[email] = data;
    await _writeAccounts(preferences, accounts);
  }

  Future<WorkshopAccessState?> setWorkshopAvailability({
    required String tenantId,
    required bool enabled,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final entry = accounts.entries
        .where(
          (item) =>
              item.value is Map &&
              (item.value as Map)['tenant_id']?.toString() == tenantId,
        )
        .firstOrNull;
    if (entry == null) return null;

    final data = Map<String, dynamic>.from(entry.value as Map);
    WorkshopAccessState nextState;
    if (enabled) {
      nextState = WorkshopAccessState.active;
      data.remove('availability_previous_state');
    } else {
      final current = WorkshopAccessState.values.firstWhere(
        (state) => state.name == data['access_state']?.toString(),
        orElse: () => WorkshopAccessState.expired,
      );
      if (current != WorkshopAccessState.suspended) {
        data['availability_previous_state'] = current.name;
      }
      nextState = WorkshopAccessState.suspended;
    }
    data['access_state'] = nextState.name;
    accounts[entry.key] = data;
    final saved = await _writeAccounts(preferences, accounts);
    return saved ? nextState : null;
  }

  Future<String?> requestTrialExtension({
    required int requestedDays,
    required String reason,
  }) async {
    if (requestedDays < 1 || requestedDays > 30) {
      return 'Solicita entre 1 y 30 días adicionales.';
    }
    if (reason.trim().length < 8) {
      return 'Explica por qué necesitas más tiempo.';
    }
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_activeEmailKey);
    if (email == null) return 'No existe una sesión administrativa activa.';
    final accounts = await _readAccounts(preferences);
    final raw = accounts[email];
    if (raw is! Map) return 'No encontramos la cuenta administrativa.';
    final data = Map<String, dynamic>.from(raw);
    if ((data['tenant_id']?.toString() ?? '').isEmpty) {
      return 'Primero debes registrar tu taller.';
    }
    final previous = data['extension_request'];
    if (previous is Map && previous['status'] == 'pending') {
      return 'Ya tienes una solicitud pendiente de revisión.';
    }
    data['extension_request'] = {
      'status': 'pending',
      'requested_days': requestedDays,
      'reason': reason.trim(),
      'requested_at': DateTime.now().toUtc().toIso8601String(),
    };
    accounts[email] = data;
    return await _writeAccounts(preferences, accounts)
        ? null
        : 'No fue posible guardar la solicitud.';
  }

  Future<List<LocalTrialExtensionRequest>>
  listPendingTrialExtensionRequests() async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final requests = <LocalTrialExtensionRequest>[];
    for (final entry in accounts.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final request = data['extension_request'];
      if (request is! Map || request['status'] != 'pending') continue;
      final requestedAt = DateTime.tryParse(
        request['requested_at']?.toString() ?? '',
      );
      final days = int.tryParse(request['requested_days']?.toString() ?? '');
      if (requestedAt == null || days == null) continue;
      requests.add(
        LocalTrialExtensionRequest(
          accountEmail: entry.key,
          tenantId: data['tenant_id']?.toString() ?? '',
          tenantName: data['tenant_name']?.toString() ?? 'Taller',
          requestedDays: days,
          reason: request['reason']?.toString() ?? '',
          requestedAt: requestedAt,
        ),
      );
    }
    requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return requests;
  }

  Future<String?> decideTrialExtension({
    required String accountEmail,
    required bool approve,
    required int grantedDays,
    required String decisionReason,
  }) async {
    if (approve && (grantedDays < 1 || grantedDays > 90)) {
      return 'La ampliación debe estar entre 1 y 90 días.';
    }
    if (decisionReason.trim().length < 5) {
      return 'Escribe el motivo de la decisión.';
    }
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final email = accountEmail.trim().toLowerCase();
    final raw = accounts[email];
    if (raw is! Map) return 'La cuenta ya no existe.';
    final data = Map<String, dynamic>.from(raw);
    final request = data['extension_request'];
    if (request is! Map || request['status'] != 'pending') {
      return 'La solicitud ya fue atendida.';
    }
    final decision = Map<String, dynamic>.from(request);
    decision['status'] = approve ? 'approved' : 'rejected';
    decision['decision_reason'] = decisionReason.trim();
    decision['decided_at'] = DateTime.now().toUtc().toIso8601String();
    if (approve) {
      final currentEnd =
          DateTime.tryParse(data['trial_ends_at']?.toString() ?? '') ??
          DateTime.now();
      final now = DateTime.now();
      final base = currentEnd.isAfter(now) ? currentEnd : now;
      final newEnd = base.add(Duration(days: grantedDays));
      data['trial_ends_at'] = newEnd.toIso8601String();
      data['access_state'] = WorkshopAccessState.trial.name;
      decision['granted_days'] = grantedDays;
      decision['new_trial_end'] = newEnd.toUtc().toIso8601String();
    }
    data['extension_request'] = decision;
    accounts[email] = data;
    return await _writeAccounts(preferences, accounts)
        ? null
        : 'No fue posible guardar la decisión.';
  }

  Future<DateTime?> extendWorkshopTrial({
    required String tenantId,
    required int additionalDays,
  }) async {
    if (additionalDays < 1 || additionalDays > 90) return null;
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final entry = accounts.entries
        .where(
          (item) =>
              item.value is Map &&
              (item.value as Map)['tenant_id']?.toString() == tenantId,
        )
        .firstOrNull;
    if (entry == null) return null;
    final data = Map<String, dynamic>.from(entry.value as Map);
    if (data['deleted_at'] != null) return null;
    final now = DateTime.now();
    final currentEnd =
        DateTime.tryParse(data['trial_ends_at']?.toString() ?? '') ?? now;
    final base = currentEnd.isAfter(now) ? currentEnd : now;
    final newEnd = base.add(Duration(days: additionalDays));
    data['trial_ends_at'] = newEnd.toIso8601String();
    data['access_state'] = WorkshopAccessState.trial.name;
    accounts[entry.key] = data;
    return await _writeAccounts(preferences, accounts) ? newEnd : null;
  }

  Future<String?> moveWorkshopToTrash({
    required String tenantId,
    required String reason,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final entry = accounts.entries
        .where(
          (item) =>
              item.value is Map &&
              (item.value as Map)['tenant_id']?.toString() == tenantId,
        )
        .firstOrNull;
    if (entry == null) return 'No encontramos la cuenta de ese taller.';
    final data = Map<String, dynamic>.from(entry.value as Map);
    if (data['deleted_at'] != null) return 'El taller ya está en la papelera.';
    final now = DateTime.now();
    data['previous_access_state'] = data['access_state'];
    data['access_state'] = WorkshopAccessState.suspended.name;
    data['deleted_at'] = now.toIso8601String();
    data['purge_after'] = now.add(const Duration(days: 30)).toIso8601String();
    data['deletion_reason'] = reason.trim();
    accounts[entry.key] = data;
    return await _writeAccounts(preferences, accounts)
        ? null
        : 'No fue posible mover el taller a la papelera.';
  }

  Future<String?> restoreWorkshop({required String tenantId}) async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final entry = accounts.entries
        .where(
          (item) =>
              item.value is Map &&
              (item.value as Map)['tenant_id']?.toString() == tenantId,
        )
        .firstOrNull;
    if (entry == null) return 'No encontramos la cuenta de ese taller.';
    final data = Map<String, dynamic>.from(entry.value as Map);
    if (data['deleted_at'] == null) return 'El taller no está en la papelera.';
    var restored = WorkshopAccessState.values.firstWhere(
      (state) => state.name == data['previous_access_state']?.toString(),
      orElse: () => WorkshopAccessState.expired,
    );
    final trialEnd = DateTime.tryParse(data['trial_ends_at']?.toString() ?? '');
    if (restored == WorkshopAccessState.trial &&
        (trialEnd == null || !trialEnd.isAfter(DateTime.now()))) {
      restored = WorkshopAccessState.expired;
    }
    data['access_state'] = restored.name;
    data.remove('previous_access_state');
    data.remove('deleted_at');
    data.remove('purge_after');
    data.remove('deletion_reason');
    accounts[entry.key] = data;
    return await _writeAccounts(preferences, accounts)
        ? null
        : 'No fue posible recuperar el taller.';
  }

  Future<String?> deleteWorkshopPermanently({required String tenantId}) async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = await _readAccounts(preferences);
    final entry = accounts.entries
        .where(
          (item) =>
              item.value is Map &&
              (item.value as Map)['tenant_id']?.toString() == tenantId,
        )
        .firstOrNull;
    if (entry == null) return null;
    final data = Map<String, dynamic>.from(entry.value as Map);
    if (data['deleted_at'] == null) {
      return 'Primero mueve el taller a la papelera.';
    }
    accounts.remove(entry.key);
    if (preferences.getString(_activeEmailKey) == entry.key) {
      await preferences.remove(_activeEmailKey);
    }
    return await _writeAccounts(preferences, accounts)
        ? null
        : 'No fue posible eliminar definitivamente el taller.';
  }

  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeEmailKey);
  }

  LocalWorkshopAdminAccount? _fromMap(Map<String, dynamic> data) {
    final email = data['email']?.toString().trim().toLowerCase() ?? '';
    final started = DateTime.tryParse(
      data['trial_started_at']?.toString() ?? '',
    );
    var ends = DateTime.tryParse(data['trial_ends_at']?.toString() ?? '');
    if (!email.contains('@') || started == null || ends == null) return null;
    final policyEnd = started.add(trialDuration);
    if (ends.isBefore(policyEnd)) ends = policyEnd;
    var state = WorkshopAccessState.values.firstWhere(
      (item) => item.name == data['access_state']?.toString(),
      orElse: () => WorkshopAccessState.trial,
    );
    if (state == WorkshopAccessState.trial && !DateTime.now().isBefore(ends)) {
      state = WorkshopAccessState.expired;
    }
    return LocalWorkshopAdminAccount(
      username: email,
      fullName: data['full_name']?.toString() ?? '',
      email: email,
      phone: data['phone']?.toString() ?? '',
      trialStartedAt: started,
      trialEndsAt: ends,
      accessState: state,
      tenantId: data['tenant_id']?.toString() ?? '',
      tenantName: data['tenant_name']?.toString() ?? '',
      deletedAt: DateTime.tryParse(data['deleted_at']?.toString() ?? ''),
      purgeAfter: DateTime.tryParse(data['purge_after']?.toString() ?? ''),
    );
  }
}
