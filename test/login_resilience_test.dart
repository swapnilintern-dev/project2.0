// AuthService.login must never throw and never surface internals.
//
// Sign-in is the one call every role goes through, and it used to have no
// timeout and an unguarded `jsonDecode(...) as Map`. A cold/crashed Render
// instance answers with an HTML error page, which made the decode throw; the
// sign-in screen caught it and printed the raw exception to the user. These
// tests pin the contract the screen now relies on: every failure comes back as
// a map with success:false and a showable message, and connectivity failures
// are additionally flagged so the screen can skip the agent/outlet retries.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:self/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.clearSession();
  });

  Future<Map<String, dynamic>> loginWith(http.Client client) =>
      AuthService.login(
        mobileNo: '9999999999',
        password: 'secret',
        client: client,
      );

  /// No message the user sees may contain exception or stack-trace text.
  void expectShowable(Map<String, dynamic> result) {
    expect(result['success'], isFalse);
    final message = result['message']?.toString() ?? '';
    expect(message, isNotEmpty);
    expect(
      message.toLowerCase(),
      isNot(anyOf(
        contains('exception'),
        contains('formatexception'),
        contains('#0 '),
        contains('<html'),
      )),
      reason: 'the sign-in snackbar renders this string verbatim',
    );
  }

  test('an HTML error page is reported, not thrown', () async {
    final client = MockClient((_) async => http.Response(
          '<html><head><title>502 Bad Gateway</title></head></html>',
          502,
          headers: {'content-type': 'text/html'},
        ));

    final result = await loginWith(client);

    expectShowable(result);
    expect(result['networkError'], isTrue);
  });

  test('an empty body is reported, not thrown', () async {
    final client = MockClient((_) async => http.Response('', 200));

    expectShowable(await loginWith(client));
  });

  test('valid JSON that is not an object is reported, not thrown', () async {
    final client =
        MockClient((_) async => http.Response(jsonEncode(['nope']), 200));

    expectShowable(await loginWith(client));
  });

  test('a connection failure is flagged as a network error', () async {
    final client = MockClient(
        (_) async => throw http.ClientException('Connection refused'));

    final result = await loginWith(client);

    expectShowable(result);
    expect(
      result['networkError'],
      isTrue,
      reason: 'the sign-in screen skips the agent/outlet logins on this flag',
    );
  });

  test('a failed login does not persist a session', () async {
    final client = MockClient((_) async => http.Response('boom', 500));

    await loginWith(client);

    expect(AuthService.authToken, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_token'), isNull);
  });

  test('a rejected password is NOT flagged as a network error', () async {
    // The server reached us and said no — the screen must still fall through to
    // the delivery-agent and outlet collections, which live behind the same host.
    final client = MockClient((_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Data mismatch'}),
          401,
        ));

    final result = await loginWith(client);

    expect(result['success'], isFalse);
    expect(result['networkError'], isNot(isTrue));
  });

  test('a successful login still captures token, role and session', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'success': true,
            'token': 'jwt-abc',
            'role': 'marketing head',
            'store_name': 'Mandal Clinic',
          }),
          200,
        ));

    final result = await loginWith(client);

    expect(result['success'], isTrue);
    expect(AuthService.authToken, 'jwt-abc');
    expect(AuthService.role, 'marketing head');
    expect(AuthService.storeName, 'Mandal Clinic');
  });

  test('a server that never answers becomes a retryable message', () async {
    // The 45-second bound itself is not worth 45 seconds of test time; what
    // matters is that the TimeoutException it raises is caught and mapped
    // rather than escaping to the sign-in screen.
    final client =
        MockClient((_) async => throw TimeoutException('no response'));

    final result = await loginWith(client);

    expectShowable(result);
    expect(result['networkError'], isTrue);
  });
}
