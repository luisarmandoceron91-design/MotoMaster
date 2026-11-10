import 'package:flutter/foundation.dart';

@immutable
class ClientProfile {
  const ClientProfile({
    this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.city,
    this.profilePhotoBytes,
    this.profilePhotoFileName,
    this.avatarPath,
    this.avatarUrl,
  });

  final String? userId;
  final String fullName;
  final String email;
  final String phone;
  final String department;
  final String city;
  final Uint8List? profilePhotoBytes;
  final String? profilePhotoFileName;
  final String? avatarPath;
  final String? avatarUrl;

  String get location =>
      [department, city].where((value) => value.trim().isNotEmpty).join(', ');

  Map<String, dynamic> toFormData() {
    return {
      'name': fullName,
      'email': email,
      'phone': phone,
      'department': department,
      'city': city,
      'profilePhotoBytes': profilePhotoBytes,
      'profilePhotoFileName': profilePhotoFileName,
      'avatarPath': avatarPath,
      'avatarUrl': avatarUrl,
    };
  }

  factory ClientProfile.fromDatabase(
    Map<String, dynamic> data, {
    String? avatarUrl,
    Uint8List? profilePhotoBytes,
    String? profilePhotoFileName,
  }) {
    return ClientProfile(
      userId: data['user_id'] as String?,
      fullName: data['full_name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      department: data['department'] as String? ?? '',
      city: data['city'] as String? ?? '',
      profilePhotoBytes: profilePhotoBytes,
      profilePhotoFileName: profilePhotoFileName,
      avatarPath: data['avatar_path'] as String?,
      avatarUrl: avatarUrl,
    );
  }
}
