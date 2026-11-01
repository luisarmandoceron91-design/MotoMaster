import 'package:shared_preferences/shared_preferences.dart';

enum GoogleAccountIntent { administrator, client }

class AdminOAuthIntentStore {
  static const _pendingKey = 'pending_admin_google_login';
  static const _pendingRoleKey = 'pending_google_login_role';

  Future<void> markPending([
    GoogleAccountIntent intent = GoogleAccountIntent.administrator,
  ]) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingRoleKey, intent.name);
    await preferences.remove(_pendingKey);
  }

  Future<GoogleAccountIntent?> pendingIntent() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_pendingRoleKey);
    if (stored != null) {
      return GoogleAccountIntent.values
          .where((value) => value.name == stored)
          .firstOrNull;
    }
    if (preferences.getBool(_pendingKey) ?? false) {
      return GoogleAccountIntent.administrator;
    }
    return null;
  }

  Future<bool> isPending() async => await pendingIntent() != null;

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingKey);
    await preferences.remove(_pendingRoleKey);
  }
}
