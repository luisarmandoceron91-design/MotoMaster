import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../networking/api_client.dart';

class WorkshopFeedback {
  const WorkshopFeedback({
    required this.id,
    required this.workshopId,
    required this.clientName,
    required this.clientEmail,
    required this.mechanicName,
    required this.serviceType,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String workshopId;
  final String clientName;
  final String clientEmail;
  final String mechanicName;
  final String serviceType;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'workshop_id': workshopId,
    'client_name': clientName,
    'client_email': clientEmail,
    'mechanic_name': mechanicName,
    'service_type': serviceType,
    'rating': rating,
    'comment': comment,
    'created_at': createdAt.toIso8601String(),
  };

  factory WorkshopFeedback.fromMap(Map<String, dynamic> map) =>
      WorkshopFeedback(
        id: map['id']?.toString() ?? '',
        workshopId: map['workshop_id']?.toString() ?? '',
        clientName: map['client_name']?.toString() ?? 'Cliente',
        clientEmail: map['client_email']?.toString() ?? '',
        mechanicName: map['mechanic_name']?.toString() ?? 'Equipo del taller',
        serviceType: map['service_type']?.toString() ?? 'Servicio',
        rating: (map['rating'] as num?)?.toInt() ?? 0,
        comment: map['comment']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class WorkshopFeedbackStore {
  static const _key = 'workshop_feedback_v1';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<List<WorkshopFeedback>> list(String workshopId) async {
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      try {
        final rows = await ApiClient().client
            .from('workshop_feedback')
            .select()
            .eq('workshop_id', workshopId)
            .order('created_at', ascending: false);
        final cloud = (rows as List)
            .map((row) => WorkshopFeedback.fromMap(Map<String, dynamic>.from(row)))
            .toList();
        await _saveCloudCache(cloud);
        return cloud;
      } catch (_) {
        // Se muestra el último respaldo si no hay red momentáneamente.
      }
    }
    final all = await _listAll();
    final items = all.where((item) => item.workshopId == workshopId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> add(WorkshopFeedback feedback) async {
    final preferences = await SharedPreferences.getInstance();
    if (ApiClient.cloudEnabled && ApiClient().client.auth.currentUser != null) {
      await ApiClient().client.from('workshop_feedback').insert({
        'workshop_id': feedback.workshopId,
        'client_id': ApiClient().client.auth.currentUser!.id,
        'client_name': feedback.clientName,
        'client_email': feedback.clientEmail,
        'mechanic_name': feedback.mechanicName,
        'service_type': feedback.serviceType,
        'rating': feedback.rating,
        'comment': feedback.comment,
      });
    }
    final items = [...await _listAll(), feedback];
    await preferences.setString(
      _key,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
    revision.value++;
  }

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

  Future<List<WorkshopFeedback>> _listAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return const [];
    try {
      return (jsonDecode(encoded) as List)
          .whereType<Map>()
          .map(
            (item) => WorkshopFeedback.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCloudCache(List<WorkshopFeedback> cloud) async {
    final preferences = await SharedPreferences.getInstance();
    final local = await _listAll();
    final merged = <String, WorkshopFeedback>{
      for (final item in local) item.id: item,
      for (final item in cloud) item.id: item,
    };
    await preferences.setString(
      _key,
      jsonEncode(merged.values.map((item) => item.toMap()).toList()),
    );
  }
}
