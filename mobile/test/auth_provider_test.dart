import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/auth_provider.dart';

void main() {
  group('AuthProvider Tests', () {
    test('Initial state is not logged in with null error', () {
      final auth = AuthProvider();
      expect(auth.isLoggedIn, false);
      expect(auth.isLoading, false);
      expect(auth.errorMessage, null);
    });

    test('Valid credentials succeed with user@horizone.com and user123', () async {
      final auth = AuthProvider();
      final result = await auth.login('user@horizone.com', 'user123');

      expect(result, true);
      expect(auth.isLoggedIn, true);
      expect(auth.userEmail, 'user@horizone.com');
      expect(auth.userName, 'Stock Manager');
      expect(auth.errorMessage, null);
    });

    test('Case-insensitivity on email succeeds with user@horizone.com', () async {
      final auth = AuthProvider();
      final result = await auth.login('  USER@HORIZONE.COM  ', 'user123');

      expect(result, true);
      expect(auth.isLoggedIn, true);
      expect(auth.userEmail, 'user@horizone.com');
    });

    test('Invalid credentials fail and return descriptive error', () async {
      final auth = AuthProvider();
      final result = await auth.login('wrong@gmail.com', 'wrongpassword');

      expect(result, false);
      expect(auth.isLoggedIn, false);
      expect(auth.errorMessage, 'Invalid email or password. Please try again.');
    });

    test('Empty fields return error and do not log in', () async {
      final auth = AuthProvider();
      final result = await auth.login('', '');

      expect(result, false);
      expect(auth.isLoggedIn, false);
      expect(auth.errorMessage, 'Please enter both email and password');
    });

    test('Logout clears session state', () async {
      final auth = AuthProvider();
      await auth.login('user@horizone.com', 'user123');
      expect(auth.isLoggedIn, true);

      await auth.logout();
      expect(auth.isLoggedIn, false);
      expect(auth.errorMessage, null);
    });
  });
}
