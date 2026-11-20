// Live integration check for the email + OTP sign-in path.
//
// Runs against a REAL server on localhost:3000 and real accounts, so it is
// excluded from the normal suite by the `live` tag — `flutter test` skips it
// unless you opt in with:
//
//   flutter test test/otp_login_live_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:3100
//
// It proves the thing unit tests cannot: that OtpAuthService captures a usable
// session and that every role lands in the right place.
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self/services/api_config.dart';
import 'package:self/services/auth_service.dart';
import 'package:self/services/otp_auth_service.dart';
import 'package:self/agent/agent_session.dart';
import 'package:self/outlet/outlet_session.dart';

/// Seeds a known OTP straight into the server's store, standing in for the
/// email that would otherwise have to be read from an inbox.
Future<void> seedOtp(String email, String otp) async {
  final r = await Process.run('node', [
    '-e',
    '''
    import("dotenv/config").then(async () => {
      const m = await import("mongoose");
      await m.default.connect(process.env.MONGO_UR);
      const E = (await import("./model/emailLoginModel.js")).default;
      await E.deleteMany({ email: "$email" });
      await E.create({ email: "$email", otp: "$otp" });
      await m.default.disconnect();
    });
    '''
  ], workingDirectory: 'server');
  if (r.exitCode != 0) throw Exception('seed failed: ${r.stderr}');
}

Future<List<Map<String, String>>> accountsByRole() async {
  final r = await Process.run('node', [
    '-e',
    '''
    import("dotenv/config").then(async () => {
      const m = await import("mongoose");
      await m.default.connect(process.env.MONGO_UR);
      const V = (await import("./model/userModel.js")).default;
      const O = (await import("./model/outletregistersModel.js")).default;
      const out = [];
      for (const role of ["admin","marketing","delivery","agent"]) {
        const u = await V.findOne({ role, email: { \$nin: [null,""] } }).select("email");
        if (u) out.push({ label: role, email: u.email });
      }
      const b = await V.findOne({ role: { \$in: [null,""] }, approvalStatus: "Approved", email: { \$nin: [null,""] } }).select("email");
      if (b) out.push({ label: "vendor", email: b.email });
      const o = await O.findOne({ email: { \$nin: [null,""] } }).select("email");
      if (o) out.push({ label: "outlet", email: o.email });
      console.log(JSON.stringify(out));
      await m.default.disconnect();
    });
    '''
  ], workingDirectory: 'server');
  final line = (r.stdout as String).split('\n').firstWhere((l) => l.trim().startsWith('['));
  return (jsonDecode(line) as List)
      .map((e) => Map<String, String>.from(e as Map))
      .toList();
}

void main() {
  const service = OtpAuthService();

  setUp(() {
    AuthService.clearSession();
    AgentSession.instance.clear();
    OutletSession.instance.clear();
  });

  test('base URL points at the local server', () {
    expect(ApiConfig.baseUrl, contains('127.0.0.1'),
        reason: 'run with --dart-define=API_BASE_URL=http://127.0.0.1:3100');
  });

  test('requestOtp rejects a malformed address before any network call', () async {
    final r = await service.requestOtp('not-an-email');
    expect(r.success, isFalse);
    expect(r.message, contains('valid email'));
  });

  test('verifyOtp rejects a wrong code and leaves no session', () async {
    final accounts = await accountsByRole();
    final email = accounts.first['email']!;
    await seedOtp(email.toLowerCase(), '424242');

    final r = await service.verifyOtp(email: email, code: '000000');
    expect(r.success, isFalse);
    expect(AuthService.authToken, isNull,
        reason: 'a failed code must never produce a session');
  });

  test('every role signs in and gets a usable session', () async {
    final accounts = await accountsByRole();
    expect(accounts, isNotEmpty);

    for (final acc in accounts) {
      AuthService.clearSession();
      AgentSession.instance.clear();
      OutletSession.instance.clear();

      final email = acc['email']!;
      await seedOtp(email.toLowerCase(), '424242');

      final r = await service.verifyOtp(email: email, code: '424242');

      expect(r.success, isTrue, reason: '${acc['label']}: ${r.message}');
      expect(AuthService.authToken, isNotNull,
          reason: '${acc['label']} got no token');
      expect(AuthService.email, equalsIgnoringCase(email));

      // The two roles homeForRole() refuses to open without a live session.
      if (acc['label'] == 'outlet') {
        expect(OutletSession.instance.isLive, isTrue,
            reason: 'outlet would bounce back to sign-in');
      }
      if (acc['label'] == 'agent') {
        expect(AgentSession.instance.isLive, isTrue,
            reason: 'agent would bounce back to sign-in');
      }
    }
  });

  test('the captured token actually authenticates a real call', () async {
    final accounts = await accountsByRole();
    final marketing =
        accounts.firstWhere((a) => a['label'] == 'marketing', orElse: () => accounts.first);
    await seedOtp(marketing['email']!.toLowerCase(), '424242');
    await service.verifyOtp(email: marketing['email']!, code: '424242');

    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(ApiConfig.myNotifications));
    req.headers.set('Authorization', 'Bearer ${AuthService.authToken}');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();

    expect(res.statusCode, 200, reason: 'token rejected: $body');
    expect(jsonDecode(body)['success'], isTrue);
  });
}
