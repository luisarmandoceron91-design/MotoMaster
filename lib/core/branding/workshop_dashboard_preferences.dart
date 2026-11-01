import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class WorkshopDashboardPreferences {
  const WorkshopDashboardPreferences({
    this.textScale = 1,
    this.brightness = 1,
    this.compactMode = false,
  });

  final double textScale;
  final double brightness;
  final bool compactMode;

  WorkshopDashboardPreferences copyWith({
    double? textScale,
    double? brightness,
    bool? compactMode,
  }) => WorkshopDashboardPreferences(
    textScale: textScale ?? this.textScale,
    brightness: brightness ?? this.brightness,
    compactMode: compactMode ?? this.compactMode,
  );
}

class WorkshopDashboardPreferencesStore {
  const WorkshopDashboardPreferencesStore();

  String _key(String workshopId, String setting) =>
      'dashboard_${workshopId}_$setting';

  Future<WorkshopDashboardPreferences> load(String workshopId) async {
    if (workshopId.isEmpty) return const WorkshopDashboardPreferences();
    final prefs = await SharedPreferences.getInstance();
    return WorkshopDashboardPreferences(
      textScale: (prefs.getDouble(_key(workshopId, 'text_scale')) ?? 1).clamp(
        .85,
        1.25,
      ),
      brightness: (prefs.getDouble(_key(workshopId, 'brightness')) ?? 1).clamp(
        .72,
        1.15,
      ),
      compactMode: prefs.getBool(_key(workshopId, 'compact')) ?? false,
    );
  }

  Future<void> save(
    String workshopId,
    WorkshopDashboardPreferences value,
  ) async {
    if (workshopId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble(
        _key(workshopId, 'text_scale'),
        value.textScale.clamp(.85, 1.25),
      ),
      prefs.setDouble(
        _key(workshopId, 'brightness'),
        value.brightness.clamp(.72, 1.15),
      ),
      prefs.setBool(_key(workshopId, 'compact'), value.compactMode),
    ]);
  }
}
