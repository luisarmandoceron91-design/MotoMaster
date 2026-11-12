import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moto_master/core/networking/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const clientServiceStages = <String>[
  'Cita solicitada',
  'Moto recibida',
  'En diagnóstico',
  'En reparación',
  'Pruebas finales',
  'Lista para entregar',
  'Entregada',
];

const appointmentCancellationNotice = Duration(hours: 24);

class AppointmentSlotUnavailableException implements Exception {
  const AppointmentSlotUnavailableException();
}

class AppointmentCancellationNotAllowedException implements Exception {
  const AppointmentCancellationNotAllowedException();
}

class AppointmentPersistenceException implements Exception {
  const AppointmentPersistenceException();
}

class AppointmentAlreadyExistsException implements Exception {
  const AppointmentAlreadyExistsException();
}

class ClientMotorcycle {
  const ClientMotorcycle({
    required this.id,
    required this.brand,
    required this.model,
    required this.plate,
    required this.year,
    required this.color,
  });

  final String id;
  final String brand;
  final String model;
  final String plate;
  final String year;
  final String color;

  String get displayName => '$brand $model';

  Map<String, dynamic> toMap() => {
    'id': id,
    'brand': brand,
    'model': model,
    'plate': plate,
    'year': year,
    'color': color,
  };

  factory ClientMotorcycle.fromMap(Map<String, dynamic> map) =>
      ClientMotorcycle(
        id: map['id']?.toString() ?? '',
        brand: map['brand']?.toString() ?? '',
        model: map['model']?.toString() ?? '',
        plate: map['plate']?.toString() ?? '',
        year: map['year']?.toString() ?? '',
        color: map['color']?.toString() ?? '',
      );
}

class ClientAppointment {
  const ClientAppointment({
    required this.id,
    required this.motorcycleId,
    required this.motorcycleName,
    required this.serviceType,
    required this.date,
    required this.time,
    required this.notes,
    this.status = 'Solicitada',
    this.workshopId = '',
    this.clientId = '',
    this.serviceStage = 'Cita solicitada',
    this.mechanicName = '',
    this.clientName = '',
    this.clientEmail = '',
    this.clientPhone = '',
    this.updatedAt,
  });

  final String id;
  final String motorcycleId;
  final String motorcycleName;
  final String serviceType;
  final DateTime date;
  final String time;
  final String notes;
  final String status;
  final String workshopId;
  final String clientId;
  final String serviceStage;
  final String mechanicName;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final DateTime? updatedAt;

  bool get isCancelled => status == 'Cancelada';
  bool get isOpen =>
      !isCancelled && status != 'Completada' && serviceStage != 'Entregada';

  DateTime get startsAt {
    final parts = time.split(':');
    final hour = parts.isEmpty ? 0 : int.tryParse(parts.first) ?? 0;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool canBeCancelled([DateTime? now]) {
    if (isCancelled || serviceStage != 'Cita solicitada') return false;
    return startsAt.difference(now ?? DateTime.now()) >=
        appointmentCancellationNotice;
  }

  ClientAppointment copyWith({
    String? id,
    String? status,
    String? workshopId,
    String? clientId,
    String? serviceStage,
    String? mechanicName,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    DateTime? updatedAt,
  }) => ClientAppointment(
    id: id ?? this.id,
    motorcycleId: motorcycleId,
    motorcycleName: motorcycleName,
    serviceType: serviceType,
    date: date,
    time: time,
    notes: notes,
    status: status ?? this.status,
    workshopId: workshopId ?? this.workshopId,
    clientId: clientId ?? this.clientId,
    serviceStage: serviceStage ?? this.serviceStage,
    mechanicName: mechanicName ?? this.mechanicName,
    clientName: clientName ?? this.clientName,
    clientEmail: clientEmail ?? this.clientEmail,
    clientPhone: clientPhone ?? this.clientPhone,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'motorcycle_id': motorcycleId,
    'motorcycle_name': motorcycleName,
    'service_type': serviceType,
    'date': date.toIso8601String(),
    'time': time,
    'notes': notes,
    'status': status,
    'workshop_id': workshopId,
    'client_id': clientId,
    'service_stage': serviceStage,
    'mechanic_name': mechanicName,
    'client_name': clientName,
    'client_email': clientEmail,
    'client_phone': clientPhone,
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory ClientAppointment.fromMap(Map<String, dynamic> map) {
    final rawProfile = map['client_profile'];
    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : const <String, dynamic>{};
    return ClientAppointment(
      id: map['id']?.toString() ?? '',
      motorcycleId: map['motorcycle_id']?.toString() ?? '',
      motorcycleName: map['motorcycle_name']?.toString() ?? '',
      serviceType: map['service_type']?.toString() ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      time: map['time']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Solicitada',
      workshopId: map['workshop_id']?.toString() ?? '',
      clientId: map['client_id']?.toString() ?? '',
      serviceStage: map['service_stage']?.toString() ?? 'Cita solicitada',
      mechanicName: map['mechanic_name']?.toString() ?? '',
      clientName:
          map['client_name']?.toString() ??
          profile['full_name']?.toString() ??
          '',
      clientEmail:
          map['client_email']?.toString() ?? profile['email']?.toString() ?? '',
      clientPhone:
          map['client_phone']?.toString() ?? profile['phone']?.toString() ?? '',
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}

class ClientServiceStore {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static const _globalAppointmentsKey = 'client_appointments_global_v1';

  String _scope(String workshopId, String clientId) {
    final raw = '${workshopId}_$clientId'.toLowerCase();
    return raw.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  Future<List<ClientMotorcycle>> listMotorcycles(
    String workshopId,
    String clientId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final cloud = _cloudClient(workshopId, clientId);
    if (cloud != null) {
      try {
        final rows = await cloud
            .from('motorcycles')
            .select()
            .eq('owner_id', clientId)
            .eq('workshop_id', workshopId)
            .order('created_at');
        final items = (rows as List)
            .map((row) => _motorcycleFromCloud(Map<String, dynamic>.from(row)))
            .toList();
        await _saveMotorcycles(preferences, workshopId, clientId, items);
        return items;
      } catch (_) {
        // La copia local se usa solo como respaldo cuando la red no responde.
      }
    }
    final encoded = preferences.getString(
      'client_motorcycles_${_scope(workshopId, clientId)}',
    );
    if (encoded == null) return const [];
    try {
      return (jsonDecode(encoded) as List)
          .whereType<Map>()
          .map(
            (item) => ClientMotorcycle.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveMotorcycle(
    String workshopId,
    String clientId,
    ClientMotorcycle motorcycle,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final items = [...await listMotorcycles(workshopId, clientId)];
    var saved = motorcycle;
    final cloud = _cloudClient(workshopId, clientId);
    if (cloud != null) {
      try {
        final payload = <String, dynamic>{
          'owner_id': clientId,
          'workshop_id': workshopId,
          'brand': motorcycle.brand.trim(),
          'model': motorcycle.model.trim(),
          'plate': motorcycle.plate.trim(),
          'model_year': int.tryParse(motorcycle.year),
          'color': motorcycle.color.trim(),
        };
        final row = _isUuid(motorcycle.id)
            ? await cloud
                  .from('motorcycles')
                  .update(payload)
                  .eq('id', motorcycle.id)
                  .select()
                  .single()
            : await cloud.from('motorcycles').insert(payload).select().single();
        saved = _motorcycleFromCloud(Map<String, dynamic>.from(row));
      } catch (_) {
        // Con nube habilitada no confirmamos una moto que no quedó guardada
        // en la cuenta; así estará disponible en todos los dispositivos.
        throw StateError('No fue posible guardar la moto en la nube.');
      }
    }
    final index = items.indexWhere(
      (item) => item.id == motorcycle.id || item.plate == motorcycle.plate,
    );
    if (index < 0) {
      items.add(saved);
    } else {
      items[index] = saved;
    }
    await _saveMotorcycles(preferences, workshopId, clientId, items);
    revision.value++;
  }

  Future<List<ClientAppointment>> listAppointments(
    String workshopId,
    String clientId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final cloud = _cloudClient(workshopId, clientId);
    if (cloud != null) {
      try {
        final rows = await cloud
            .from('appointments')
            .select()
            .eq('workshop_id', workshopId)
            .eq('client_id', clientId)
            .order('scheduled_at');
        final clientIds = (rows as List)
            .map((row) => row['client_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        List<dynamic> profiles = const [];
        if (clientIds.isNotEmpty) {
          try {
            profiles = await cloud
                .from('profiles')
                .select('user_id, full_name, email, phone')
                .inFilter('user_id', clientIds);
          } catch (_) {
            // Los datos de la cita siguen disponibles aunque el perfil no
            // pueda leerse temporalmente por una política de acceso.
          }
        }
        final profileById = <String, Map<String, dynamic>>{
          for (final row in profiles)
            row['user_id'].toString(): Map<String, dynamic>.from(row),
        };
        final items = (rows as List).map((row) {
          final item = Map<String, dynamic>.from(row);
          item['client_profile'] = profileById[item['client_id']?.toString()];
          return _appointmentFromCloud(item);
        }).toList();
        await _saveAppointments(preferences, workshopId, clientId, items);
        await _mergeGlobalAppointments(preferences, items);
        return items;
      } catch (_) {
        // Continúa con la última copia local si la nube no está disponible.
      }
    }
    final encoded = preferences.getString(
      'client_appointments_${_scope(workshopId, clientId)}',
    );
    if (encoded == null) return const [];
    try {
      final items = (jsonDecode(encoded) as List)
          .whereType<Map>()
          .map(
            (item) =>
                ClientAppointment.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
      items.sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date == 0 ? a.time.compareTo(b.time) : date;
      });
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAppointment(
    String workshopId,
    String clientId,
    ClientAppointment appointment,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    var saved = appointment.copyWith(
      workshopId: workshopId,
      clientId: clientId,
      updatedAt: DateTime.now(),
    );
    final cloud = _cloudClient(workshopId, clientId);
    if (cloud != null) {
      try {
        if (_isUuid(saved.motorcycleId)) {
          final existing = await cloud
              .from('appointments')
              .select('id')
              .eq('workshop_id', workshopId)
              .eq('client_id', clientId)
              .eq('motorcycle_id', saved.motorcycleId)
              .inFilter('status', ['requested', 'confirmed', 'in_progress'])
              .limit(1);
          if ((existing as List).isNotEmpty) {
            throw const AppointmentAlreadyExistsException();
          }
        }
        final row = await cloud
            .from('appointments')
            .insert({
              'workshop_id': workshopId,
              'client_id': clientId,
              'motorcycle_id': _isUuid(saved.motorcycleId)
                  ? saved.motorcycleId
                  : null,
              'scheduled_at': _scheduledAt(saved).toUtc().toIso8601String(),
              'service_type': saved.serviceType,
              'motorcycle_name': saved.motorcycleName,
              'service_stage': saved.serviceStage,
              'reason': saved.notes,
              'status': 'requested',
            })
            .select('id')
            .single();
        saved = saved.copyWith(id: row['id']?.toString());
      } on AppointmentAlreadyExistsException {
        rethrow;
      } on PostgrestException catch (error) {
        if (error.code == '23505') {
          throw const AppointmentSlotUnavailableException();
        }
        throw const AppointmentPersistenceException();
      } catch (_) {
        throw const AppointmentPersistenceException();
      }
    }
    final global = await _listGlobalAppointments(preferences);
    final occupied = global.any(
      (item) =>
          !item.isCancelled &&
          item.id != saved.id &&
          item.workshopId == workshopId &&
          _sameDay(item.date, saved.date) &&
          item.time == saved.time,
    );
    if (occupied) throw const AppointmentSlotUnavailableException();

    final items = [...await listAppointments(workshopId, clientId)];
    items.add(saved);
    await preferences.setString(
      'client_appointments_${_scope(workshopId, clientId)}',
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
    global.removeWhere((item) => item.id == saved.id);
    global.add(saved);
    await _saveGlobalAppointments(preferences, global);
    revision.value++;
  }

  Future<bool> isSlotAvailable(
    String workshopId,
    DateTime date,
    String time, {
    String? excludingAppointmentId,
  }) async {
    final cloud = _cloudClient(workshopId, null);
    if (cloud != null) {
      try {
        final rows = await cloud
            .from('appointments')
            .select('id')
            .eq('workshop_id', workshopId)
            .eq(
              'scheduled_at',
              _scheduledAtParts(date, time).toUtc().toIso8601String(),
            )
            .neq('status', 'cancelled')
            .limit(1);
        if ((rows as List).isNotEmpty) return false;
      } catch (_) {
        // The final insert remains the authoritative atomic conflict check.
      }
    }
    final preferences = await SharedPreferences.getInstance();
    final global = await _listGlobalAppointments(preferences);
    return !global.any(
      (item) =>
          !item.isCancelled &&
          item.id != excludingAppointmentId &&
          item.workshopId == workshopId &&
          _sameDay(item.date, date) &&
          item.time == time,
    );
  }

  Future<void> cancelAppointment(ClientAppointment appointment) async {
    if (!appointment.canBeCancelled()) {
      throw const AppointmentCancellationNotAllowedException();
    }
    final cloud = _cloudClient(appointment.workshopId, appointment.clientId);
    if (cloud != null && _isUuid(appointment.id)) {
      try {
        await cloud
            .from('appointments')
            .update({'status': 'cancelled'})
            .eq('id', appointment.id);
      } on PostgrestException catch (error) {
        if (error.code == 'P0001') {
          throw const AppointmentCancellationNotAllowedException();
        }
        throw const AppointmentPersistenceException();
      } catch (_) {
        throw const AppointmentPersistenceException();
      }
    }
    final preferences = await SharedPreferences.getInstance();
    final updated = appointment.copyWith(
      status: 'Cancelada',
      serviceStage: 'Cita cancelada',
      updatedAt: DateTime.now(),
    );
    final global = await _listGlobalAppointments(preferences);
    final globalIndex = global.indexWhere((item) => item.id == appointment.id);
    if (globalIndex >= 0) global[globalIndex] = updated;
    await _saveGlobalAppointments(preferences, global);

    final scoped = [
      ...await listAppointments(appointment.workshopId, appointment.clientId),
    ];
    final scopedIndex = scoped.indexWhere((item) => item.id == appointment.id);
    if (scopedIndex >= 0) scoped[scopedIndex] = updated;
    await preferences.setString(
      'client_appointments_${_scope(appointment.workshopId, appointment.clientId)}',
      jsonEncode(scoped.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  Future<List<ClientAppointment>> listWorkshopAppointments(
    String workshopId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final cloud = _cloudClient(workshopId, null);
    if (cloud != null) {
      try {
        final rows = await cloud
            .from('appointments')
            .select()
            .eq('workshop_id', workshopId)
            .order('scheduled_at');
        final clientIds = (rows as List)
            .map((row) => row['client_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        List<dynamic> profiles = const [];
        if (clientIds.isNotEmpty) {
          try {
            profiles = await cloud
                .from('profiles')
                .select('user_id, full_name, email, phone')
                .inFilter('user_id', clientIds);
          } catch (_) {
            // El panel conserva las citas incluso si falla la información
            // complementaria del perfil del cliente.
          }
        }
        final profileById = <String, Map<String, dynamic>>{
          for (final row in profiles)
            row['user_id'].toString(): Map<String, dynamic>.from(row),
        };
        final items = (rows as List).map((row) {
          final item = Map<String, dynamic>.from(row);
          item['client_profile'] = profileById[item['client_id']?.toString()];
          return _appointmentFromCloud(item);
        }).toList();
        await _mergeGlobalAppointments(preferences, items);
        return items;
      } catch (_) {
        // Se muestra el último estado descargado si falla la conexión.
      }
    }
    final items = await _listGlobalAppointments(preferences);
    return items.where((item) => item.workshopId == workshopId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> updateAppointmentStage(
    ClientAppointment appointment,
    String stage, {
    String? mechanicName,
  }) async {
    if (appointment.isCancelled || !clientServiceStages.contains(stage)) return;
    final preferences = await SharedPreferences.getInstance();
    final updated = appointment.copyWith(
      serviceStage: stage,
      status: stage == 'Entregada'
          ? 'Completada'
          : stage == 'Cita solicitada'
          ? 'Solicitada'
          : 'En proceso',
      mechanicName: mechanicName,
      updatedAt: DateTime.now(),
    );
    final cloud = _cloudClient(appointment.workshopId, null);
    if (cloud != null && _isUuid(appointment.id)) {
      try {
        await cloud
            .from('appointments')
            .update({
              'service_stage': updated.serviceStage,
              'mechanic_name': updated.mechanicName,
              'status': stage == 'Entregada'
                  ? 'completed'
                  : stage == 'Cita solicitada'
                  ? 'requested'
                  : 'in_progress',
            })
            .eq('id', updated.id);
      } catch (_) {
        throw const AppointmentPersistenceException();
      }
    }
    final global = await _listGlobalAppointments(preferences);
    final globalIndex = global.indexWhere((item) => item.id == appointment.id);
    if (globalIndex >= 0) global[globalIndex] = updated;
    await _saveGlobalAppointments(preferences, global);

    final scoped = [
      ...await listAppointments(appointment.workshopId, appointment.clientId),
    ];
    final scopedIndex = scoped.indexWhere((item) => item.id == appointment.id);
    if (scopedIndex >= 0) scoped[scopedIndex] = updated;
    await preferences.setString(
      'client_appointments_${_scope(appointment.workshopId, appointment.clientId)}',
      jsonEncode(scoped.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

  Future<void> purgeWorkshop(String workshopId) async {
    final preferences = await SharedPreferences.getInstance();
    final safeId = workshopId.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    for (final key
        in preferences
            .getKeys()
            .where(
              (key) =>
                  (key.startsWith('client_motorcycles_') ||
                      key.startsWith('client_appointments_')) &&
                  key.contains(safeId),
            )
            .toList()) {
      await preferences.remove(key);
    }
    final global = await _listGlobalAppointments(preferences)
      ..removeWhere((item) => item.workshopId == workshopId);
    await _saveGlobalAppointments(preferences, global);
    revision.value++;
  }

  Future<List<ClientAppointment>> _listGlobalAppointments(
    SharedPreferences preferences,
  ) async {
    final encoded = preferences.getString(_globalAppointmentsKey);
    if (encoded == null) return <ClientAppointment>[];
    try {
      return (jsonDecode(encoded) as List)
          .whereType<Map>()
          .map(
            (item) =>
                ClientAppointment.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return <ClientAppointment>[];
    }
  }

  Future<void> _saveGlobalAppointments(
    SharedPreferences preferences,
    List<ClientAppointment> items,
  ) => preferences.setString(
    _globalAppointmentsKey,
    jsonEncode(items.map((item) => item.toMap()).toList()),
  );

  Future<void> _saveMotorcycles(
    SharedPreferences preferences,
    String workshopId,
    String clientId,
    List<ClientMotorcycle> items,
  ) => preferences.setString(
    'client_motorcycles_${_scope(workshopId, clientId)}',
    jsonEncode(items.map((item) => item.toMap()).toList()),
  );

  Future<void> _saveAppointments(
    SharedPreferences preferences,
    String workshopId,
    String clientId,
    List<ClientAppointment> items,
  ) => preferences.setString(
    'client_appointments_${_scope(workshopId, clientId)}',
    jsonEncode(items.map((item) => item.toMap()).toList()),
  );

  Future<void> _mergeGlobalAppointments(
    SharedPreferences preferences,
    List<ClientAppointment> items,
  ) async {
    final global = await _listGlobalAppointments(preferences);
    for (final item in items) {
      global.removeWhere((existing) => existing.id == item.id);
      global.add(item);
    }
    await _saveGlobalAppointments(preferences, global);
  }

  ClientMotorcycle _motorcycleFromCloud(Map<String, dynamic> row) =>
      ClientMotorcycle(
        id: row['id']?.toString() ?? '',
        brand: row['brand']?.toString() ?? '',
        model: row['model']?.toString() ?? '',
        plate: row['plate']?.toString() ?? '',
        year: row['model_year']?.toString() ?? '',
        color: row['color']?.toString() ?? '',
      );

  ClientAppointment _appointmentFromCloud(Map<String, dynamic> row) {
    final scheduled = DateTime.tryParse(row['scheduled_at']?.toString() ?? '');
    return ClientAppointment(
      id: row['id']?.toString() ?? '',
      motorcycleId: row['motorcycle_id']?.toString() ?? '',
      motorcycleName: row['motorcycle_name']?.toString() ?? '',
      serviceType: row['service_type']?.toString() ?? '',
      date: scheduled?.toLocal() ?? DateTime.now(),
      time: scheduled == null
          ? ''
          : '${scheduled.toLocal().hour.toString().padLeft(2, '0')}:${scheduled.toLocal().minute.toString().padLeft(2, '0')}',
      notes: row['reason']?.toString() ?? '',
      status: _appointmentStatus(row['status']?.toString()),
      workshopId: row['workshop_id']?.toString() ?? '',
      clientId: row['client_id']?.toString() ?? '',
      serviceStage: row['service_stage']?.toString() ?? 'Cita solicitada',
      mechanicName: row['mechanic_name']?.toString() ?? '',
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  String _appointmentStatus(String? value) => switch (value) {
    'cancelled' => 'Cancelada',
    'confirmed' => 'Confirmada',
    'in_progress' => 'En proceso',
    'completed' => 'Completada',
    _ => 'Solicitada',
  };

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  DateTime _scheduledAt(ClientAppointment appointment) =>
      _scheduledAtParts(appointment.date, appointment.time);

  DateTime _scheduledAtParts(DateTime date, String time) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  SupabaseClient? _cloudClient(String workshopId, String? clientId) {
    if (!ApiClient.cloudEnabled || !_isUuid(workshopId)) return null;
    try {
      final client = ApiClient().client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      if (clientId != null && _isUuid(clientId) && userId != clientId) {
        return null;
      }
      return client;
    } catch (_) {
      return null;
    }
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}
