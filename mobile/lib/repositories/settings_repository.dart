import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}

class HiveSettingsRepository implements SettingsRepository {
  static const String boxName = 'settings_box';
  static const String settingsKey = 'app_settings';

  Box get _box => Hive.box(boxName);

  @override
  Future<AppSettings> getSettings() async {
    final raw = _box.get(settingsKey);
    if (raw == null) {
      final defaultSettings = AppSettings();
      await saveSettings(defaultSettings);
      return defaultSettings;
    }
    final settings = AppSettings.fromMap(raw as Map);
    if (settings.lowStockThreshold == 10) {
      final updated = settings.copyWith(lowStockThreshold: 100);
      await saveSettings(updated);
      return updated;
    }
    return settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(settingsKey, settings.toMap());
  }
}
