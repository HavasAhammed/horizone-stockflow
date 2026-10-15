import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository settingsRepository;

  AppSettings _settings = AppSettings();
  bool _isLoading = false;

  SettingsProvider({required this.settingsRepository});

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      _settings = await settingsRepository.getSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await settingsRepository.saveSettings(newSettings);
    notifyListeners();
  }
}
