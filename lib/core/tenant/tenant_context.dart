import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tenant_model.dart';

class TenantContext extends ValueNotifier<Tenant?> {
  TenantContext() : super(null);

  static const _tenantIdKey = 'active_tenant_id';
  static const _tenantNameKey = 'active_tenant_name';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_tenantIdKey);
    final name = prefs.getString(_tenantNameKey);

    if (id != null && name != null) {
      value = Tenant(tenantId: id, name: name);
    }
  }

  Future<void> setTenant(Tenant tenant) async {
    value = tenant;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tenantIdKey, tenant.tenantId);
    await prefs.setString(_tenantNameKey, tenant.name);
  }

  Future<void> clear() async {
    value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantIdKey);
    await prefs.remove(_tenantNameKey);
  }

  String get currentTenantId => value?.tenantId ?? '';
}
