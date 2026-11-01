import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/local_workshop_admin_store.dart';
import 'workshop.dart';

/// Public workshop data only. Account credentials and private administrator
/// details are deliberately stored elsewhere.
class LocalWorkshopDirectoryStore {
  static const _key = 'local_public_workshop_directory_v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<List<Workshop>> listActive() async {
    final all = [...await listAll()];
    final visible = all
        .where((workshop) => workshop.hasPlatformAccess)
        .toList();
    visible.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return visible;
  }

  Future<List<Workshop>> listAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return const [];
    try {
      final values = jsonDecode(encoded) as List;
      return values
          .whereType<Map>()
          .map((row) => Workshop.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(Workshop workshop) async {
    final preferences = await SharedPreferences.getInstance();
    final all = [...await listAll()];
    final index = all.indexWhere((item) => item.id == workshop.id);
    if (index < 0) {
      all.add(workshop);
    } else {
      all[index] = workshop;
    }
    await preferences.setString(
      _key,
      jsonEncode(all.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  /// Conserva en el registro compartido los talleres que llegaron desde el
  /// directorio público. Así el centro de control puede mostrar exactamente
  /// los mismos talleres aunque la sesión propietaria de la nube no esté
  /// disponible temporalmente.
  Future<void> syncPublicDirectory(Iterable<Workshop> workshops) async {
    final incoming = workshops.toList();
    if (incoming.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final all = [...await listAll()];
    var changed = false;
    for (final workshop in incoming) {
      final index = all.indexWhere((item) => item.id == workshop.id);
      if (index < 0) {
        all.add(workshop);
        changed = true;
        continue;
      }
      final current = all[index];
      final merged = Workshop.fromMap({
        ...current.toMap(),
        ...workshop.toMap(),
      }, logoUrl: workshop.logoUrl ?? current.logoUrl);
      if (jsonEncode(current.toMap()) == jsonEncode(merged.toMap()) &&
          current.logoUrl == merged.logoUrl) {
        continue;
      }
      all[index] = merged;
      changed = true;
    }
    if (!changed) return;
    await preferences.setString(
      _key,
      jsonEncode(all.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  Future<Workshop?> find(String id) async {
    final all = await listAll();
    for (final workshop in all) {
      if (workshop.id == id) return workshop;
    }
    return null;
  }

  Future<void> setAccessStatus(String id, String accessStatus) async {
    final workshop = await find(id);
    if (workshop == null) return;
    final data = workshop.toMap()..['access_status'] = accessStatus;
    await upsert(Workshop.fromMap(data, logoUrl: workshop.logoUrl));
  }

  Future<void> deletePermanently(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final all = [...await listAll()]..removeWhere((item) => item.id == id);
    await preferences.setString(
      _key,
      jsonEncode(all.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  Future<void> syncRegisteredAccounts(
    List<LocalWorkshopAdminAccount> accounts,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final all = [...await listAll()];
    var changed = false;
    for (final account in accounts.where((item) => item.hasWorkshop)) {
      final index = all.indexWhere((item) => item.id == account.tenantId);
      final accessStatus = account.deletedAt != null
          ? 'deleted'
          : account.accessState.name;
      if (index >= 0) {
        final current = all[index];
        final permanent = account.accessState == WorkshopAccessState.active;
        if (current.accessStatus == accessStatus &&
            current.trialStartedAt == account.trialStartedAt &&
            current.trialEndsAt == account.trialEndsAt &&
            current.permanentAccess == permanent) {
          continue;
        }
        final data = current.toMap()
          ..['access_status'] = accessStatus
          ..['trial_started_at'] = account.trialStartedAt.toIso8601String()
          ..['trial_ends_at'] = account.trialEndsAt.toIso8601String()
          ..['permanent_access'] = permanent;
        all[index] = Workshop.fromMap(data, logoUrl: current.logoUrl);
        changed = true;
        continue;
      }

      final tenantId = account.tenantId;
      final storedName = preferences.getString('brand_${tenantId}_name');
      final name = storedName?.trim().isNotEmpty == true
          ? storedName!.trim()
          : account.tenantName.trim();
      final logoBytes = preferences.getString('brand_${tenantId}_logo');
      all.add(
        Workshop.fromMap({
          'id': tenantId,
          'name': name.isEmpty ? 'Taller registrado' : name,
          'slug': _slug(name.isEmpty ? tenantId : name),
          'tagline': preferences.getString('brand_${tenantId}_tagline') ?? '',
          'accent_color':
              preferences.getInt('brand_${tenantId}_color') ?? 0xFFFF6200,
          'logo_index': preferences.getInt('brand_${tenantId}_index') ?? 0,
          'logo_bytes': logoBytes,
          'logo_file_name': preferences.getString('brand_${tenantId}_file'),
          'access_status': accessStatus,
          'trial_started_at': account.trialStartedAt.toIso8601String(),
          'trial_ends_at': account.trialEndsAt.toIso8601String(),
          'permanent_access': account.accessState == WorkshopAccessState.active,
        }),
      );
      changed = true;
    }
    if (!changed) return;
    await preferences.setString(
      _key,
      jsonEncode(all.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  String _slug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
