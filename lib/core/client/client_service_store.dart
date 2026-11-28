import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moto_master/core/networking/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const clientServiceStages = <String>[
  'Cita aceptada',
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
    this.requestedMechanicName = '',
    this.clientName = '',
    this.clientEmail = '',
    this.clientPhone = '',
    this.serviceReport = const ClientServiceReport(),
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

  /// Mecánico escogido por el cliente al solicitar la cita. Se conserva aun
  /// si luego el administrador debe reasignar el trabajo.
  final String requestedMechanicName;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final ClientServiceReport serviceReport;
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
    if (isCancelled || status == 'Completada') return false;
    return startsAt.difference(now ?? DateTime.now()) >=
        appointmentCancellationNotice;
  }

  ClientAppointment copyWith({
    String? id,
    String? status,
    String? notes,
    String? workshopId,
    String? clientId,
    String? serviceStage,
    String? mechanicName,
    String? requestedMechanicName,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    ClientServiceReport? serviceReport,
    DateTime? updatedAt,
  }) => ClientAppointment(
    id: id ?? this.id,
    motorcycleId: motorcycleId,
    motorcycleName: motorcycleName,
    serviceType: serviceType,
    date: date,
    time: time,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    workshopId: workshopId ?? this.workshopId,
    clientId: clientId ?? this.clientId,
    serviceStage: serviceStage ?? this.serviceStage,
    mechanicName: mechanicName ?? this.mechanicName,
    requestedMechanicName: requestedMechanicName ?? this.requestedMechanicName,
    clientName: clientName ?? this.clientName,
    clientEmail: clientEmail ?? this.clientEmail,
    clientPhone: clientPhone ?? this.clientPhone,
      serviceReport: serviceReport ?? this.serviceReport,
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
    'requested_mechanic_name': requestedMechanicName,
    'client_name': clientName,
    'client_email': clientEmail,
    'client_phone': clientPhone,
    'service_report': serviceReport.toMap(),
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
      requestedMechanicName: map['requested_mechanic_name']?.toString() ?? '',
      clientName:
          map['client_name']?.toString() ??
          profile['full_name']?.toString() ??
          '',
      clientEmail:
          map['client_email']?.toString() ?? profile['email']?.toString() ?? '',
      clientPhone:
          map['client_phone']?.toString() ?? profile['phone']?.toString() ?? '',
      serviceReport: ClientServiceReport.fromMap(
        map['service_report'] is Map
            ? Map<String, dynamic>.from(map['service_report'] as Map)
            : const <String, dynamic>{},
      ),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}

class ClientServiceReportLine {
  const ClientServiceReportLine({
    required this.name,
    this.brand = '',
    this.quantity = 1,
    this.unitPriceCents = 0,
  });

  final String name;
  final String brand;
  final int quantity;
  final int unitPriceCents;

  int get subtotalCents => quantity * unitPriceCents;

  Map<String, dynamic> toMap() => {
    'name': name,
    'brand': brand,
    'quantity': quantity,
    'unit_price_cents': unitPriceCents,
  };

  factory ClientServiceReportLine.fromMap(Map<String, dynamic> map) =>
      ClientServiceReportLine(
        name: map['name']?.toString() ?? '',
        brand: map['brand']?.toString() ?? '',
        quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 1,
        unitPriceCents:
            int.tryParse(map['unit_price_cents']?.toString() ?? '') ?? 0,
      );
}

class ClientServiceLaborLine {
  const ClientServiceLaborLine({required this.description, this.priceCents = 0});

  final String description;
  final int priceCents;

  Map<String, dynamic> toMap() => {
    'description': description,
    'price_cents': priceCents,
  };

  factory ClientServiceLaborLine.fromMap(Map<String, dynamic> map) =>
      ClientServiceLaborLine(
        description: map['description']?.toString() ?? '',
        priceCents: int.tryParse(map['price_cents']?.toString() ?? '') ?? 0,
      );
}

class ClientServiceReport {
  const ClientServiceReport({
    this.published = false,
    this.mileage = '',
    this.diagnosis = '',
    this.mechanicName = '',
    this.parts = const [],
    this.labor = const [],
    this.updatedAt,
  });

  final bool published;
  final String mileage;
  final String diagnosis;
  final String mechanicName;
  final List<ClientServiceReportLine> parts;
  final List<ClientServiceLaborLine> labor;
  final DateTime? updatedAt;

  int get partsSubtotalCents =>
      parts.fold(0, (sum, item) => sum + item.subtotalCents);
  int get laborSubtotalCents =>
      labor.fold(0, (sum, item) => sum + item.priceCents);
  int get totalCents => partsSubtotalCents + laborSubtotalCents;

  ClientServiceReport copyWith({
    bool? published,
    String? mileage,
    String? diagnosis,
    String? mechanicName,
    List<ClientServiceReportLine>? parts,
    List<ClientServiceLaborLine>? labor,
    DateTime? updatedAt,
  }) => ClientServiceReport(
    published: published ?? this.published,
    mileage: mileage ?? this.mileage,
    diagnosis: diagnosis ?? this.diagnosis,
    mechanicName: mechanicName ?? this.mechanicName,
    parts: parts ?? this.parts,
    labor: labor ?? this.labor,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'published': published,
    'mileage': mileage,
    'diagnosis': diagnosis,
    'mechanic_name': mechanicName,
    'parts': parts.map((item) => item.toMap()).toList(),
    'labor': labor.map((item) => item.toMap()).toList(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory ClientServiceReport.fromMap(Map<String, dynamic> map) =>
      ClientServiceReport(
        published: map['published'] == true,
        mileage: map['mileage']?.toString() ?? '',
        diagnosis: map['diagnosis']?.toString() ?? '',
        mechanicName: map['mechanic_name']?.toString() ?? '',
        parts: (map['parts'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => ClientServiceReportLine.fromMap(Map<String, dynamic>.from(item)))
            .where((item) => item.name.trim().isNotEmpty)
            .toList(),
        labor: (map['labor'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => ClientServiceLaborLine.fromMap(Map<String, dynamic>.from(item)))
            .where((item) => item.description.trim().isNotEmpty)
            .toList(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      );
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
            .order('created_at');
        final items = (rows as List)
            .map((row) => _motorcycleFromCloud(Map<String, dynamic>.from(row)))
            .toList();
        await _saveMotorcycles(preferences, workshopId, clientId, items);
        return items;
      } catch (_) {
        // Con nube activa no se debe presentar una copia antigua de otro
        // dispositivo como si fuese información vigente.
        return const [];
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
          // La moto pertenece al cliente, no a un taller concreto. Así queda
          // disponible al pedir cita en cualquier taller actual o futuro.
          'workshop_id': null,
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
        // La nube es la única fuente oficial cuando está configurada.
        return const [];
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
              'mechanic_name': saved.mechanicName,
              'requested_mechanic_name': saved.requestedMechanicName,
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
          item.time == saved.time &&
          saved.requestedMechanicName.trim().isNotEmpty &&
          (item.mechanicName == saved.requestedMechanicName ||
              item.requestedMechanicName == saved.requestedMechanicName),
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
    String? mechanicName,
    String? excludingAppointmentId,
  }) async {
    final cloud = _cloudClient(workshopId, null);
    if (cloud != null) {
      try {
        var query = cloud
            .from('appointments')
            .select('id')
            .eq('workshop_id', workshopId)
            .eq(
              'scheduled_at',
              _scheduledAtParts(date, time).toUtc().toIso8601String(),
            )
            .inFilter('status', ['requested', 'confirmed', 'in_progress']);
        final requested = mechanicName?.trim() ?? '';
        if (requested.isNotEmpty) {
          query = query.or(
            'mechanic_name.eq.${Uri.encodeComponent(requested)},requested_mechanic_name.eq.${Uri.encodeComponent(requested)}',
          );
        }
        final rows = await query.limit(1);
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
          item.time == time &&
          (mechanicName == null ||
              mechanicName.trim().isEmpty ||
              item.mechanicName == mechanicName ||
              item.requestedMechanicName == mechanicName),
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
        // Evita que el taller vea citas antiguas de un dispositivo local.
        return const [];
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
          : stage == 'Cita aceptada'
          ? 'Confirmada'
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
                  : stage == 'Cita aceptada'
                  ? 'confirmed'
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

  /// Registra novedades del diagnóstico sin reemplazar el motivo original
  /// indicado por el cliente. El taller y el cliente ven la misma bitácora.
  Future<void> addAppointmentNote(
    ClientAppointment appointment,
    String note,
  ) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    final stamp = DateTime.now();
    final line = '[${stamp.day.toString().padLeft(2, '0')}/${stamp.month.toString().padLeft(2, '0')} ${stamp.hour.toString().padLeft(2, '0')}:${stamp.minute.toString().padLeft(2, '0')}] $trimmed';
    final combined = appointment.notes.trim().isEmpty
        ? line
        : '${appointment.notes.trim()}\n$line';
    final updated = appointment.copyWith(notes: combined, updatedAt: stamp);
    final cloud = _cloudClient(appointment.workshopId, null);
    if (cloud != null && _isUuid(appointment.id)) {
      try {
        await cloud
            .from('appointments')
            .update({'notes': combined})
            .eq('id', appointment.id);
      } catch (_) {
        throw const AppointmentPersistenceException();
      }
    }
    final preferences = await SharedPreferences.getInstance();
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

  /// Guarda la orden detallada que el taller publica para que el cliente vea
  /// repuestos, mano de obra, mecánico y total desde cualquier dispositivo.
  Future<void> saveServiceReport(
    ClientAppointment appointment,
    ClientServiceReport report,
  ) async {
    final timestamp = DateTime.now();
    final updatedReport = report.copyWith(updatedAt: timestamp);
    final updated = appointment.copyWith(
      serviceReport: updatedReport,
      updatedAt: timestamp,
    );
    final cloud = _cloudClient(appointment.workshopId, null);
    if (cloud != null && _isUuid(appointment.id)) {
      try {
        await cloud
            .from('appointments')
            .update({'service_report': updatedReport.toMap()})
            .eq('id', appointment.id);
      } catch (_) {
        throw const AppointmentPersistenceException();
      }
    }
    final preferences = await SharedPreferences.getInstance();
    final global = await _listGlobalAppointments(preferences);
    final globalIndex = global.indexWhere((item) => item.id == appointment.id);
    if (globalIndex >= 0) global[globalIndex] = updated;
    await _saveGlobalAppointments(preferences, global);
    final scoped = [
      ...await listAppointments(appointment.workshopId, appointment.clientId),
    ];
    final scopedIndex = scoped.indexWhere((item) => item.id == appointment.id);
    if (scopedIndex >= 0) scoped[scopedIndex] = updated;
    await _saveAppointments(
      preferences,
      appointment.workshopId,
      appointment.clientId,
      scoped,
    );
    revision.value++;
  }

  /// El administrador confirma la solicitud. La actualización se realiza en
  /// Supabase y el trigger de notificaciones avisa al cliente.
  Future<void> decideAppointment(
    ClientAppointment appointment, {
    required bool accept,
  }) async {
    if (appointment.status != 'Solicitada' || !accept) return;
    const stage = 'Cita aceptada';
    const status = 'confirmed';
    final updated = appointment.copyWith(
      status: 'Confirmada',
      serviceStage: stage,
      updatedAt: DateTime.now(),
    );
    final cloud = _cloudClient(appointment.workshopId, null);
    if (cloud != null && _isUuid(appointment.id)) {
      try {
        await cloud
            .from('appointments')
            .update({'status': status, 'service_stage': stage})
            .eq('id', appointment.id);
      } catch (_) {
        throw const AppointmentPersistenceException();
      }
    }
    final preferences = await SharedPreferences.getInstance();
    final global = await _listGlobalAppointments(preferences);
    final globalIndex = global.indexWhere((item) => item.id == appointment.id);
    if (globalIndex >= 0) global[globalIndex] = updated;
    await _saveGlobalAppointments(preferences, global);
    final scoped = [
      ...await listAppointments(appointment.workshopId, appointment.clientId),
    ];
    final scopedIndex = scoped.indexWhere((item) => item.id == appointment.id);
    if (scopedIndex >= 0) scoped[scopedIndex] = updated;
    await _saveAppointments(
      preferences,
      appointment.workshopId,
      appointment.clientId,
      scoped,
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
      requestedMechanicName: row['requested_mechanic_name']?.toString() ?? '',
      serviceReport: ClientServiceReport.fromMap(
        row['service_report'] is Map
            ? Map<String, dynamic>.from(row['service_report'] as Map)
            : const <String, dynamic>{},
      ),
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
