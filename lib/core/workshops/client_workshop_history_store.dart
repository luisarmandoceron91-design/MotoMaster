import 'dart:convert';

import '../networking/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientWorkshopHistoryStore {
  // Version 2 deliberately starts an explicit client history. Version 1
  // could contain legacy entries created before a client selected a workshop.
  static const _key = 'client_workshop_history_v2';
  static const _hiddenKey = 'client_workshop_hidden_v1';

  String _email(String value) => value.trim().toLowerCase();

  Future<Map<String, dynamic>> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<List<String>> list(String clientEmail) async {
    final data = await _read();
    final values = data[_email(clientEmail)];
    final List<String> local = values is List
        ? values.map((value) => value.toString()).toList()
        : <String>[];
    final user = ApiClient.cloudEnabled
        ? ApiClient().client.auth.currentUser
        : null;
    if (user == null) return local;
    try {
      // Importa una sola vez la lista creada por versiones anteriores.
      if (local.isNotEmpty) {
        await ApiClient().client.from('client_workshop_preferences').upsert([
          for (var index = 0; index < local.length; index++)
            {
              'client_id': user.id,
              'workshop_id': local[index],
              'hidden': false,
              'last_opened_at': DateTime.now()
                  .subtract(Duration(minutes: index))
                  .toUtc()
                  .toIso8601String(),
            },
        ]);
      }
      final rows = await ApiClient().client
          .from('client_workshop_preferences')
          .select('workshop_id')
          .eq('client_id', user.id)
          .eq('hidden', false)
          .order('last_opened_at', ascending: false);
      final cloud = rows
          .map((row) => row['workshop_id'].toString())
          .toList(growable: false);
      if (cloud.isNotEmpty || local.isEmpty) return cloud;
    } catch (_) {
      // La lista local es únicamente una caché disponible sin red.
    }
    return local;
  }

  Future<void> remember(String clientEmail, String workshopId) async {
    final preferences = await SharedPreferences.getInstance();
    final data = await _read();
    final email = _email(clientEmail);
    final ids = data[email] is List
        ? (data[email] as List).map((value) => value.toString()).toList()
        : <String>[];
    ids.remove(workshopId);
    ids.insert(0, workshopId);
    data[email] = ids.take(20).toList();
    await preferences.setString(_key, jsonEncode(data));
    final user = ApiClient.cloudEnabled
        ? ApiClient().client.auth.currentUser
        : null;
    if (user != null) {
      await ApiClient().client.from('client_workshop_preferences').upsert({
        'client_id': user.id,
        'workshop_id': workshopId,
        'hidden': false,
        'last_opened_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> remove(String clientEmail, String workshopId) async {
    final preferences = await SharedPreferences.getInstance();
    final data = await _read();
    final email = _email(clientEmail);
    final ids = data[email] is List
        ? (data[email] as List).map((value) => value.toString()).toList()
        : <String>[];
    ids.remove(workshopId);
    data[email] = ids;
    await preferences.setString(_key, jsonEncode(data));
  }

  Future<List<String>> listHidden(String clientEmail) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_hiddenKey);
    var local = const <String>[];
    try {
      if (encoded != null) {
        final data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
        final values = data[_email(clientEmail)];
        local = values is List
            ? values.map((value) => value.toString()).toSet().toList()
            : const [];
      }
      final user = ApiClient.cloudEnabled
          ? ApiClient().client.auth.currentUser
          : null;
      if (user == null) return local;
      final rows = await ApiClient().client
          .from('client_workshop_preferences')
          .select('workshop_id')
          .eq('client_id', user.id)
          .eq('hidden', true);
      return rows.map((row) => row['workshop_id'].toString()).toList();
    } catch (_) {
      return local;
    }
  }

  Future<void> hide(String clientEmail, String workshopId) async {
    final preferences = await SharedPreferences.getInstance();
    Map<String, dynamic> data = <String, dynamic>{};
    final encoded = preferences.getString(_hiddenKey);
    if (encoded != null) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      } catch (_) {}
    }
    final email = _email(clientEmail);
    final ids = data[email] is List
        ? (data[email] as List).map((value) => value.toString()).toSet()
        : <String>{};
    ids.add(workshopId);
    data[email] = ids.toList();
    await preferences.setString(_hiddenKey, jsonEncode(data));
    final user = ApiClient.cloudEnabled
        ? ApiClient().client.auth.currentUser
        : null;
    if (user != null) {
      await ApiClient().client.from('client_workshop_preferences').upsert({
        'client_id': user.id,
        'workshop_id': workshopId,
        'hidden': true,
        'last_opened_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> purgeWorkshop(String workshopId) async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in [_key, _hiddenKey]) {
      final encoded = preferences.getString(key);
      if (encoded == null) continue;
      try {
        final data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
        for (final entry in data.entries.toList()) {
          final values = entry.value is List
              ? (entry.value as List)
                    .map((value) => value.toString())
                    .where((value) => value != workshopId)
                    .toList()
              : <String>[];
          data[entry.key] = values;
        }
        await preferences.setString(key, jsonEncode(data));
      } catch (_) {}
    }
  }
}
