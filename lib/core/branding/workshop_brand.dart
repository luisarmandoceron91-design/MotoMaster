import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identidad visible del taller actual. En producción estos valores deben
/// provenir del tenant autenticado; este controlador permite probar la
/// personalización de forma inmediata en la interfaz.
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

const List<IconData> workshopLogoOptions = <IconData>[
  Icons.build_circle_outlined,
  Icons.motorcycle_outlined,
  Icons.handyman_outlined,
  Icons.settings_suggest_outlined,
  Icons.precision_manufacturing_outlined,
];

class WorkshopBrandController extends ValueNotifier<WorkshopBrand> {
  WorkshopBrandController() : super(WorkshopBrand.defaultBrand);

  static const _nameKey = 'brand_name';
  static const _taglineKey = 'brand_tagline';
  static const _logoIndexKey = 'brand_logo_index';
  static const _accentKey = 'brand_accent_color';
  static const _customLogoKey = 'brand_custom_logo';
  static const _customLogoFileNameKey = 'brand_custom_logo_file_name';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    Uint8List? logoBytes;
    final encodedLogo = preferences.getString(_customLogoKey);
    if (encodedLogo != null) {
      try {
        logoBytes = base64Decode(encodedLogo);
      } on FormatException {
        await preferences.remove(_customLogoKey);
      }
    }
    value = WorkshopBrand(
      name: preferences.getString(_nameKey) ?? WorkshopBrand.defaultBrand.name,
      tagline:
          preferences.getString(_taglineKey) ??
          WorkshopBrand.defaultBrand.tagline,
      logoIndex:
          preferences.getInt(_logoIndexKey) ??
          WorkshopBrand.defaultBrand.logoIndex,
      accentColorValue:
          preferences.getInt(_accentKey) ??
          WorkshopBrand.defaultBrand.accentColorValue,
      customLogoBytes: logoBytes,
      customLogoFileName: preferences.getString(_customLogoFileNameKey),
    );
  }

  Future<void> updateBrand({
    String? name,
    String? tagline,
    int? logoIndex,
    int? accentColorValue,
    Uint8List? customLogoBytes,
    String? customLogoFileName,
    bool clearCustomLogo = false,
  }) async {
    value = value.copyWith(
      name: name == null || name.trim().isEmpty
          ? value.name
          : name.trim().toUpperCase(),
      tagline: tagline == null || tagline.trim().isEmpty
          ? value.tagline
          : tagline.trim(),
      logoIndex: logoIndex,
      accentColorValue: accentColorValue,
      customLogoBytes: customLogoBytes,
      customLogoFileName: customLogoFileName,
      clearCustomLogo: clearCustomLogo,
    );
    await _persist();
  }

  Future<void> updateAccentColor(int accentColorValue) async {
    value = value.copyWith(accentColorValue: accentColorValue);
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_nameKey, value.name);
    await preferences.setString(_taglineKey, value.tagline);
    await preferences.setInt(_logoIndexKey, value.logoIndex);
    await preferences.setInt(_accentKey, value.accentColorValue);
    if (value.hasCustomLogo) {
      await preferences.setString(
        _customLogoKey,
        base64Encode(value.customLogoBytes!),
      );
      await preferences.setString(
        _customLogoFileNameKey,
        value.customLogoFileName ?? 'logo_personalizado',
      );
    } else {
      await preferences.remove(_customLogoKey);
      await preferences.remove(_customLogoFileNameKey);
    }
  }
}
