// Session persistence tests — the saved login must restore within the 1-day
// backend token life, expire after it, and vanish on logout.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:self/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> session({required Duration age}) => {
        'session_token': 'jwt-token',
        'session_cookie': 'token=jwt-token',
        'session_store_name': 'mandal clinic',
        'session_phone': '9999999999',
        'session_role': 'vendor',
        'session_saved_at':
            DateTime.now().subtract(age).millisecondsSinceEpoch,
      };

  setUp(AuthService.clearSession);

  test('fresh session restores with all fields', () async {
    SharedPreferences.setMockInitialValues(
        session(age: const Duration(hours: 1)));

    expect(await AuthService.restoreSession(), isTrue);
    expect(AuthService.authToken, 'jwt-token');
    expect(AuthService.sessionCookie, 'token=jwt-token');
    expect(AuthService.storeName, 'mandal clinic');
    expect(AuthService.phone, '9999999999');
    expect(AuthService.role, 'vendor');
  });

  test('session older than the 1-day token is rejected and wiped', () async {
    SharedPreferences.setMockInitialValues(
        session(age: const Duration(hours: 25)));

    expect(await AuthService.restoreSession(), isFalse);
    expect(AuthService.authToken, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_token'), isNull,
        reason: 'expired session must be deleted from storage');
  });

  test('no saved session → restore fails quietly', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AuthService.restoreSession(), isFalse);
  });

  test('clearSession wipes storage so next start needs a login', () async {
    SharedPreferences.setMockInitialValues(
        session(age: const Duration(minutes: 5)));
    expect(await AuthService.restoreSession(), isTrue);

    AuthService.clearSession();
    // clearSession clears storage asynchronously — give it a beat.
    await Future.delayed(const Duration(milliseconds: 50));

    expect(await AuthService.restoreSession(), isFalse);
    expect(AuthService.authToken, isNull);
  });
}
