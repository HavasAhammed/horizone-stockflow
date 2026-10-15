import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthProvider extends ChangeNotifier {
  static const String boxName = 'auth_box';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserEmail = 'user_email';
  static const String keyUserName = 'user_name';

  // Demo stock manager credentials
  static const String defaultEmail = 'user@gmail.com';
  static const String defaultPassword = 'user123';

  bool _isLoggedIn = false;
  String? _userEmail;
  String? _userName;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _loadSession();
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail ?? defaultEmail;
  String? get userName => _userName ?? 'Stock Manager';
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _loadSession() {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      _isLoggedIn = box.get(keyIsLoggedIn, defaultValue: false) as bool;
      _userEmail = box.get(keyUserEmail) as String?;
      _userName = box.get(keyUserName) as String?;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Small artificial delay for realistic smooth UI feedback
    await Future.delayed(const Duration(milliseconds: 600));

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      _errorMessage = 'Please enter both email and password';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (cleanEmail == defaultEmail && cleanPassword == defaultPassword) {
      _isLoggedIn = true;
      _userEmail = defaultEmail;
      _userName = 'Stock Manager';
      _errorMessage = null;

      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box(boxName);
        await box.put(keyIsLoggedIn, true);
        await box.put(keyUserEmail, _userEmail);
        await box.put(keyUserName, _userName);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid email or password. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userEmail = null;
    _userName = null;
    _errorMessage = null;

    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      await box.put(keyIsLoggedIn, false);
      await box.delete(keyUserEmail);
      await box.delete(keyUserName);
    }

    notifyListeners();
  }
}
