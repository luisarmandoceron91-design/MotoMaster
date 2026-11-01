import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class WorkshopBrand {
  const WorkshopBrand({
    required this.name,
    required this.tagline,
    required this.logoIndex,
    required this.accentColorValue,
    this.customLogoBytes,
    this.customLogoFileName,
  });

  static const defaultBrand = WorkshopBrand(
    name: 'MOTO MASTER',
    tagline: 'Taller especializado',
    logoIndex: 0,
    accentColorValue: 0xFFFF6200,
  );

  static const newWorkshop = WorkshopBrand(
    name: 'TU TALLER',
    tagline: 'Describe brevemente tu negocio',
    logoIndex: 0,
    accentColorValue: 0xFFFF6200,
  );

  final String name;
  final String tagline;
  final int logoIndex;
  final int accentColorValue;
  final Uint8List? customLogoBytes;
  final String? customLogoFileName;

  Color get accentColor => Color(accentColorValue);
  bool get hasCustomLogo =>
      customLogoBytes != null && customLogoBytes!.isNotEmpty;
  IconData get logoIcon =>
      workshopLogoOptions[logoIndex.clamp(0, workshopLogoOptions.length - 1)];

  WorkshopBrand copyWith({
    String? name,
    String? tagline,
    int? logoIndex,
    int? accentColorValue,
    Uint8List? customLogoBytes,
    String? customLogoFileName,
    bool clearCustomLogo = false,
  }) {
    return WorkshopBrand(
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      logoIndex: logoIndex ?? this.logoIndex,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      customLogoBytes: clearCustomLogo
          ? null
          : customLogoBytes ?? this.customLogoBytes,
      customLogoFileName: clearCustomLogo
          ? null
          : customLogoFileName ?? this.customLogoFileName,
    );
  }
}

const List<IconData> workshopLogoOptions = [
  Icons.build_circle_outlined,
  Icons.motorcycle_outlined,
  Icons.handyman_outlined,
  Icons.settings_suggest_outlined,
  Icons.precision_manufacturing_outlined,
];

class WorkshopBrandController extends ValueNotifier<WorkshopBrand> {
  WorkshopBrandController() : super(WorkshopBrand.defaultBrand);

  Future<void> load(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    Uint8List? logoBytes;
    final encodedLogo = prefs.getString('brand_${tenantId}_logo');
    if (encodedLogo != null) {
      try {
        logoBytes = base64Decode(encodedLogo);
      } catch (_) {}
    }
    value = WorkshopBrand(
      name:
          prefs.getString('brand_${tenantId}_name') ??
          WorkshopBrand.defaultBrand.name,
      tagline:
          prefs.getString('brand_${tenantId}_tagline') ??
          WorkshopBrand.defaultBrand.tagline,
      logoIndex:
          prefs.getInt('brand_${tenantId}_index') ??
          WorkshopBrand.defaultBrand.logoIndex,
      accentColorValue:
          prefs.getInt('brand_${tenantId}_color') ??
          WorkshopBrand.defaultBrand.accentColorValue,
      customLogoBytes: logoBytes,
      customLogoFileName: prefs.getString('brand_${tenantId}_file'),
    );
  }

  Future<void> updateBrand({
    required String tenantId,
    String? name,
    String? tagline,
    int? logoIndex,
    int? accentColorValue,
    Uint8List? customLogoBytes,
    String? customLogoFileName,
    bool clearCustomLogo = false,
  }) async {
    value = value.copyWith(
      name: (name == null || name.trim().isEmpty)
          ? value.name
          : name.trim().toUpperCase(),
      tagline: (tagline == null || tagline.trim().isEmpty)
          ? value.tagline
          : tagline.trim(),
      logoIndex: logoIndex,
      accentColorValue: accentColorValue,
      customLogoBytes: customLogoBytes,
      customLogoFileName: customLogoFileName,
      clearCustomLogo: clearCustomLogo,
    );
    await _persist(tenantId);
  }

  Future<void> updateAccentColor(String tenantId, int color) async {
    value = value.copyWith(accentColorValue: color);
    await _persist(tenantId);
  }

  Future<void> _persist(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('brand_${tenantId}_name', value.name);
    await prefs.setString('brand_${tenantId}_tagline', value.tagline);
    await prefs.setInt('brand_${tenantId}_index', value.logoIndex);
    await prefs.setInt('brand_${tenantId}_color', value.accentColorValue);
    if (value.hasCustomLogo) {
      await prefs.setString(
        'brand_${tenantId}_logo',
        base64Encode(value.customLogoBytes!),
      );
      await prefs.setString(
        'brand_${tenantId}_file',
        value.customLogoFileName ?? 'logo_personalizado',
      );
    } else {
      await prefs.remove('brand_${tenantId}_logo');
      await prefs.remove('brand_${tenantId}_file');
    }
  }
}
