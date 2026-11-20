// Live checks for the two remaining integrations: notification preferences and
// account deletion.
//
//   flutter test test/phase5_live_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:3100
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self/notifications/user_inbox_api.dart';
import 'package:self/services/account_api.dart';
import 'package:self/services/auth_service.dart';
import 'package:self/services/otp_auth_service.dart';

Future<String> _node(String script) async {
  final r = await Process.run('node', ['-e', script], workingDirectory: 'server');
  if (r.exitCode != 0) throw Exception('node failed: ${r.stderr}');
  return r.stdout as String;
}

Map<String, dynamic> _json(String out) => jsonDecode(
    out.split('\n').firstWhere((l) => l.trim().startsWith('{')));

Future<void> _signInAs(String email) async {
  await _node('''
    import("dotenv/config").then(async () => {
      const m = await import("mongoose");
      await m.default.connect(process.env.MONGO_UR);
      const E = (await import("./model/emailLoginModel.js")).default;
      await E.deleteMany({ email: "${email.toLowerCase()}" });
      await E.create({ email: "${email.toLowerCase()}", otp: "424242" });
      await m.default.disconnect();
    });''');
  final r = await const OtpAuthService().verifyOtp(email: email, code: '424242');
  if (!r.success) throw Exception('sign-in failed: ${r.message}');
}

void main() {
  setUp(AuthService.clearSession);

  group('notification preferences', () {
    late String email;

    setUp(() async {
      final out = await _node('''
        import("dotenv/config").then(async () => {
          const m = await import("mongoose");
          await m.default.connect(process.env.MONGO_UR);
          const V = (await import("./model/userModel.js")).default;
          const u = await V.findOne({ role: "marketing", email: { \$nin: [null,""] } }).select("email");
          console.log(JSON.stringify({ email: u.email }));
          await m.default.disconnect();
        });''');
      email = _json(out)['email'] as String;
      await _signInAs(email);
    });

    test('reads the current setting', () async {
      final s = await const UserInboxApi().fetchSettings();
      expect(s, isNotNull);
      expect(s!.enabled, isA<bool>());
    });

    test('turning it off and on again persists server-side', () async {
      final api = const UserInboxApi();
      final original = (await api.fetchSettings())!.enabled;

      expect(await api.setNotificationsEnabled(false), isFalse);
      expect((await api.fetchSettings())!.enabled, isFalse,
          reason: 'the server must have stored it, not just echoed it');

      expect(await api.setNotificationsEnabled(true), isTrue);
      expect((await api.fetchSettings())!.enabled, isTrue);

      // Leave the account exactly as it was found.
      await api.setNotificationsEnabled(original);
    });

    test('without a session it fails instead of silently succeeding', () async {
      AuthService.clearSession();
      expect(await const UserInboxApi().setNotificationsEnabled(false), isNull);
    });
  });

  group('account deletion', () {
    test('refuses without a session', () async {
      final r = await const AccountApi().deleteMyAccount();
      expect(r.success, isFalse);
      expect(r.message, contains('session'));
    });

    test('actually deletes the account from MongoDB', () async {
      // A throwaway vendor, so nothing real is destroyed.
      const email = 'zz-phase5-delete-test@example.com';
      final created = await _node('''
        import("dotenv/config").then(async () => {
          const m = await import("mongoose");
          await m.default.connect(process.env.MONGO_UR);
          const V = (await import("./model/userModel.js")).default;
          await V.deleteMany({ email: "$email" });
          const u = await V.create({
            email: "$email", mobile_no: "9999000011",
            store_name: "ZZ Phase5 Throwaway", contact_person_name: "ZZ Test",
            approvalStatus: "Approved"
          });
          console.log(JSON.stringify({ id: u._id.toString() }));
          await m.default.disconnect();
        });''');
      final id = _json(created)['id'];

      await _signInAs(email);
      expect(AuthService.userId, id);

      final r = await const AccountApi().deleteMyAccount(reason: 'test');
      expect(r.success, isTrue, reason: r.message);

      // The row must actually be gone — not just a cheerful response.
      final after = await _node('''
        import("dotenv/config").then(async () => {
          const m = await import("mongoose");
          await m.default.connect(process.env.MONGO_UR);
          const V = (await import("./model/userModel.js")).default;
          const u = await V.findById("$id");
          console.log(JSON.stringify({ stillThere: !!u }));
          await V.deleteMany({ email: "$email" });
          await m.default.disconnect();
        });''');
      expect(_json(after)['stillThere'], isFalse,
          reason: 'the account survived — the UI would be lying to the user');
    });
  });
}
