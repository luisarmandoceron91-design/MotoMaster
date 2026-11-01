import 'package:flutter/foundation.dart';

@immutable
class Tenant {
  const Tenant({
    required this.tenantId,
    required this.name,
    this.status = TenantStatus.active,
  });

  final String tenantId;
  final String name;
  final TenantStatus status;

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      status: TenantStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TenantStatus.active,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenant_id': tenantId,
      'name': name,
      'status': status.name,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tenant && other.tenantId == tenantId;
  }

  @override
  int get hashCode => tenantId.hashCode;
}

enum TenantStatus { active, inactive, deleted }
