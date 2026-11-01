import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ClientWorkshopHistoryStore {
  static const _key = 'client_workshop_history_v1';
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
    return values is List
        ? values.map((value) => value.toString()).toList()
        : [];
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
    if (encoded == null) return const [];
    try {
      final data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      final values = data[_email(clientEmail)];
      return values is List
          ? values.map((value) => value.toString()).toSet().toList()
          : const [];
    } catch (_) {
      return const [];
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
