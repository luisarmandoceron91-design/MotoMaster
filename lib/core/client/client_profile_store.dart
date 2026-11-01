import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'client_profile.dart';

class ClientProfileStore {
  const ClientProfileStore();

  static const _registeredKey = 'client_profile_registered';
  static const _nameKey = 'client_profile_name';
  static const _emailKey = 'client_profile_email';
  static const _phoneKey = 'client_profile_phone';
  static const _departmentKey = 'client_profile_department';
  static const _cityKey = 'client_profile_city';
  static const _photoKey = 'client_profile_photo';
  static const _photoFileNameKey = 'client_profile_photo_file_name';

  Future<ClientProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_registeredKey) ?? false)) return null;

    final name = prefs.getString(_nameKey);
    final email = prefs.getString(_emailKey);
    final phone = prefs.getString(_phoneKey);
    if (name == null || email == null || phone == null) return null;

    final encodedPhoto = prefs.getString(_photoKey);
    return ClientProfile(
      fullName: name,
      email: email,
      phone: phone,
      department: prefs.getString(_departmentKey) ?? '',
      city: prefs.getString(_cityKey) ?? '',
      profilePhotoBytes: encodedPhoto == null
          ? null
          : base64Decode(encodedPhoto),
      profilePhotoFileName: prefs.getString(_photoFileNameKey),
    );
  }

  Future<void> save(ClientProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, profile.fullName);
    await prefs.setString(_emailKey, profile.email);
    await prefs.setString(_phoneKey, profile.phone);
    await prefs.setString(_departmentKey, profile.department);
    await prefs.setString(_cityKey, profile.city);

    if (profile.profilePhotoBytes == null) {
      await prefs.remove(_photoKey);
      await prefs.remove(_photoFileNameKey);
    } else {
      await prefs.setString(
        _photoKey,
        base64Encode(profile.profilePhotoBytes!),
      );
      await prefs.setString(
        _photoFileNameKey,
        profile.profilePhotoFileName ?? 'foto_perfil',
      );
    }

    await prefs.setBool(_registeredKey, true);
  }
}
