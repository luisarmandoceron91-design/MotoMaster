import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../networking/api_client.dart';

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
    var all = await _listAll();
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      final localForWorkshop = all
          .where((item) => item.workshopId == workshopId)
          .toList(growable: false);
      // Importa copias antiguas cuando la sesión tiene rol de taller. Si la
      // sesión es de cliente, el rechazo de escritura no bloquea la lectura.
      if (localForWorkshop.isNotEmpty) {
        try {
          await ApiClient().client
              .from('workshop_mechanics')
              .upsert(localForWorkshop.map((item) => item.toMap()).toList());
        } catch (_) {
          // Un cliente no puede editar el equipo, pero sí debe poder verlo.
        }
      }
      try {
        final rows = await ApiClient().client
            .from('workshop_mechanics')
            .select()
            .eq('workshop_id', workshopId);
        final cloud = rows
            .map(
              (row) => WorkshopMechanic.fromMap(Map<String, dynamic>.from(row)),
            )
            .toList();
        all = {
          for (final mechanic in all) mechanic.id: mechanic,
          for (final mechanic in cloud) mechanic.id: mechanic,
        }.values.toList();
        await _saveAll(all);
      } catch (_) {
        // La copia local permite trabajar sin conexión; al recuperar red se
        // vuelve a leer la fuente oficial de la nube.
      }
    }
    final items =
        all
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
    final items = [...await _listAll()];
    final index = items.indexWhere((item) => item.id == mechanic.id);
    index < 0 ? items.add(mechanic) : items[index] = mechanic;
    await _saveAll(items);
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      await ApiClient().client
          .from('workshop_mechanics')
          .upsert(mechanic.toMap());
    }
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
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      await ApiClient().client
          .from('workshop_mechanics')
          .delete()
          .eq('workshop_id', workshopId);
    }
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

  Future<void> _saveAll(List<WorkshopMechanic> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }
}
