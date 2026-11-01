import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class WorkshopMechanic {
  const WorkshopMechanic({
    required this.id,
    required this.workshopId,
    required this.name,
    required this.specialty,
    this.phone = '',
    this.bio = '',
    this.experienceYears = 0,
    this.photoBytes,
    this.available = true,
    this.active = true,
  });

  final String id;
  final String workshopId;
  final String name;
  final String specialty;
  final String phone;
  final String bio;
  final int experienceYears;
  final Uint8List? photoBytes;
  final bool available;
  final bool active;

  WorkshopMechanic copyWith({
    String? name,
    String? specialty,
    String? phone,
    String? bio,
    int? experienceYears,
    Uint8List? photoBytes,
    bool clearPhoto = false,
    bool? available,
    bool? active,
  }) => WorkshopMechanic(
    id: id,
    workshopId: workshopId,
    name: name ?? this.name,
    specialty: specialty ?? this.specialty,
    phone: phone ?? this.phone,
    bio: bio ?? this.bio,
    experienceYears: experienceYears ?? this.experienceYears,
    photoBytes: clearPhoto ? null : photoBytes ?? this.photoBytes,
    available: available ?? this.available,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'workshop_id': workshopId,
    'name': name,
    'specialty': specialty,
    'phone': phone,
    'bio': bio,
    'experience_years': experienceYears,
    'photo_base64': photoBytes == null ? null : base64Encode(photoBytes!),
    'available': available,
    'active': active,
  };

  factory WorkshopMechanic.fromMap(Map<String, dynamic> map) =>
      WorkshopMechanic(
        id: map['id']?.toString() ?? '',
        workshopId: map['workshop_id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        specialty: map['specialty']?.toString() ?? 'Mecánica general',
        phone: map['phone']?.toString() ?? '',
        bio: map['bio']?.toString() ?? '',
        experienceYears: (map['experience_years'] as num?)?.toInt() ?? 0,
        photoBytes: _decodePhoto(map['photo_base64']),
        available: map['available'] as bool? ?? true,
        active: map['active'] as bool? ?? true,
      );

  static Uint8List? _decodePhoto(Object? value) {
    if (value == null || value.toString().isEmpty) return null;
    try {
      return base64Decode(value.toString());
    } catch (_) {
      return null;
    }
  }
}

class WorkshopMechanicStore {
  static const _key = 'workshop_mechanics_v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<List<WorkshopMechanic>> list(
    String workshopId, {
    bool includeInactive = false,
  }) async {
    final items =
        (await _listAll())
            .where(
              (item) =>
                  item.workshopId == workshopId &&
                  (includeInactive || item.active),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<List<WorkshopMechanic>> available(String workshopId) async =>
      (await list(
        workshopId,
      )).where((item) => item.available).toList(growable: false);

  Future<void> save(WorkshopMechanic mechanic) async {
    final preferences = await SharedPreferences.getInstance();
    final items = [...await _listAll()];
    final index = items.indexWhere((item) => item.id == mechanic.id);
    index < 0 ? items.add(mechanic) : items[index] = mechanic;
    await preferences.setString(
      _key,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  Future<void> archive(WorkshopMechanic mechanic) =>
      save(mechanic.copyWith(active: false, available: false));

  Future<void> purgeWorkshop(String workshopId) async {
    final preferences = await SharedPreferences.getInstance();
    final items = [...await _listAll()]
      ..removeWhere((item) => item.workshopId == workshopId);
    await preferences.setString(
      _key,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  Future<List<WorkshopMechanic>> _listAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return const [];
    try {
      return (jsonDecode(encoded) as List)
          .whereType<Map>()
          .map(
            (item) => WorkshopMechanic.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
