import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

@immutable
class Workshop {
  const Workshop({
    required this.id,
    required this.name,
    required this.slug,
    required this.tagline,
    required this.accentColorValue,
    this.logoIndex = 0,
    this.logoPath,
    this.logoUrl,
    this.logoBytes,
    this.logoFileName,
    this.department = '',
    this.municipality = '',
    this.neighborhood = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.rating = 0,
    this.reviewCount = 0,
    this.openingHours = const {},
    this.accessStatus = 'trial',
    this.trialStartedAt,
    this.trialEndsAt,
    this.permanentAccess = false,
  });

  final String id;
  final String name;
  final String slug;
  final String tagline;
  final int accentColorValue;
  final int logoIndex;
  final String? logoPath;
  final String? logoUrl;
  final Uint8List? logoBytes;
  final String? logoFileName;
  final String department;
  final String municipality;
  final String neighborhood;
  final String address;
  final String phone;
  final String email;
  final double rating;
  final int reviewCount;
  final Map<String, dynamic> openingHours;
  final String accessStatus;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final bool permanentAccess;

  Color get accentColor => Color(accentColorValue);

  String get locationLine => [
    department,
    municipality,
    neighborhood,
  ].where((part) => part.trim().isNotEmpty).join(' · ');

  bool get isOpenNow => isOpenAt(DateTime.now());

  bool get hasPlatformAccess =>
      permanentAccess ||
      accessStatus == 'active' ||
      (accessStatus == 'trial' &&
          trialEndsAt != null &&
          DateTime.now().isBefore(trialEndsAt!));

  bool isOpenAt(DateTime dateTime) {
    const weekdayKeys = <int, String>{
      DateTime.monday: 'monday',
      DateTime.tuesday: 'tuesday',
      DateTime.wednesday: 'wednesday',
      DateTime.thursday: 'thursday',
      DateTime.friday: 'friday',
      DateTime.saturday: 'saturday',
      DateTime.sunday: 'sunday',
    };
    final schedule = openingHours[weekdayKeys[dateTime.weekday]];
    if (schedule is! Map || schedule['closed'] == true) return false;
    final opens = _minutes(schedule['open']?.toString());
    final closes = _minutes(schedule['close']?.toString());
    if (opens == null || closes == null) return false;
    final current = dateTime.hour * 60 + dateTime.minute;
    return closes >= opens
        ? current >= opens && current < closes
        : current >= opens || current < closes;
  }

  static int? _minutes(String? value) {
    final pieces = value?.split(':');
    if (pieces == null || pieces.length != 2) return null;
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'slug': slug,
    'tagline': tagline,
    'accent_color': accentColorValue,
    'logo_index': logoIndex,
    'logo_path': logoPath,
    'logo_bytes': logoBytes == null ? null : base64Encode(logoBytes!),
    'logo_file_name': logoFileName,
    'department': department,
    'municipality': municipality,
    'neighborhood': neighborhood,
    'address': address,
    'phone': phone,
    'email': email,
    'rating': rating,
    'review_count': reviewCount,
    'opening_hours': openingHours,
    'access_status': accessStatus,
    'trial_started_at': trialStartedAt?.toIso8601String(),
    'trial_ends_at': trialEndsAt?.toIso8601String(),
    'permanent_access': permanentAccess,
  };

  factory Workshop.fromMap(Map<String, dynamic> data, {String? logoUrl}) =>
      Workshop(
        id: data['id'] as String,
        name: data['name'] as String,
        slug: data['slug'] as String,
        tagline: data['tagline'] as String? ?? '',
        accentColorValue: (data['accent_color'] as num?)?.toInt() ?? 0xFFFF5A00,
        logoIndex: (data['logo_index'] as num?)?.toInt() ?? 0,
        logoPath: data['logo_path'] as String?,
        logoUrl: logoUrl,
        logoBytes: _decodeLogo(data['logo_bytes']),
        logoFileName: data['logo_file_name'] as String?,
        department: data['department'] as String? ?? '',
        municipality: data['municipality'] as String? ?? '',
        neighborhood: data['neighborhood'] as String? ?? '',
        address: data['address'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        email: data['email'] as String? ?? '',
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (data['review_count'] as num?)?.toInt() ?? 0,
        openingHours: Map<String, dynamic>.from(
          data['opening_hours'] as Map? ?? const {},
        ),
        accessStatus: data['access_status'] as String? ?? 'trial',
        trialStartedAt: DateTime.tryParse(
          data['trial_started_at']?.toString() ?? '',
        ),
        trialEndsAt: DateTime.tryParse(data['trial_ends_at']?.toString() ?? ''),
        permanentAccess: data['permanent_access'] as bool? ?? false,
      );

  static Uint8List? _decodeLogo(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}
