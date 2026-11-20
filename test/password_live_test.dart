// Live checks for the password flows.
//
//   flutter test test/password_live_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:3100
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self/services/account_api.dart';
import 'package:self/services/auth_service.dart';
import 'package:self/services/otp_auth_service.dart';

Future<String> _node(String script) async {
  final r = await Process.run('node', ['-e', script], workingDirectory: 'server');
  if (r.exitCode != 0) throw Exception('node failed: ${r.stderr}');
  return r.stdout as String;
}

Map<String, dynamic> _json(String out) =>
    jsonDecode(out.split('\n').firstWhere((l) => l.trim().startsWith('{')));

const _email = 'zz-password-flow-test@example.com';
const _originalPassword = 'OldPass123';

/// A throwaway vendor, so no real account is touched.
Future<String> _createTestVendor() async {
  final out = await _node('''
    import("dotenv/config").then(async () => {
      const m = await import("mongoose");
      await m.default.connect(process.env.MONGO_UR);
      const V = (await import("./model/userModel.js")).default;
      await V.deleteMany({ email: "$_email" });
      const u = await V.create({
        email: "$_email", mobile_no: "9999000022", password: "$_originalPassword",
        store_name: "ZZ Password Test", contact_person_name: "ZZ Test",
        approvalStatus: "Approved"
      });
      console.log(JSON.stringify({ id: u._id.toString() }));
      await m.default.disconnect();
    });''');
  return _json(out)['id'] as String;
}

Future<String> _storedPassword() async {
  final out = await _node('''
    import("dotenv/config").then(async () => {
      const m = await import("mongoose");
      await m.default.connect(process.env.MONGO_UR);
      const V = (await import("./model/userModel.js")).default;
      const u = await V.findOne({ email: "$_email" }).select("password");
      console.log(JSON.stringify({ pw: u ? u.password : null }));
      await m.default.disconnect();
    });''');
  return '${_json(out)['pw']}';
}

Future<void> _cleanup() => _node('''
  import("dotenv/config").then(async () => {
    const m = await import("mongoose");
    await m.default.connect(process.env.MONGO_UR);
    const V = (await import("./model/userModel.js")).default;
    const E = (await import("./model/emailLoginModel.js")).default;
    await V.deleteMany({ email: "$_email" });
    await E.deleteMany({ email: "$_email" });
    await m.default.disconnect();
  });''');

Future<void> _signInByOtp() async {
  await _node('''
    import("dotenv/config").then(async () => {
      const m = await import("mongoose");
      await m.default.connect(process.env.MONGO_UR);
      const E = (await import("./model/emailLoginModel.js")).default;
      await E.deleteMany({ email: "$_email" });
      await E.create({ email: "$_email", otp: "424242" });
      await m.default.disconnect();
    });''');
  final r = await const OtpAuthService().verifyOtp(email: _email, code: '424242');
  if (!r.success) throw Exception('sign-in failed: ${r.message}');
}

void main() {
  setUp(() async {
    AuthService.clearSession();
    await _createTestVendor();
  });

  tearDown(_cleanup);

  test('refuses without a session', () async {
    final r = await const AccountApi().updatePassword(newPassword: 'Whatever99');
    expect(r.success, isFalse);
    expect(r.message, contains('session'));
    expect(await _storedPassword(), _originalPassword,
        reason: 'the password must not change');
  });

  test('rejects a password shorter than the server minimum', () async {
    await _signInByOtp();
    final r = await const AccountApi().updatePassword(newPassword: 'ab1');
    expect(r.success, isFalse);
    expect(await _storedPassword(), _originalPassword);
  });

  test('FORGOT PASSWORD: OTP → new password actually persists', () async {
    await _signInByOtp(); // the OTP step IS the authorisation
    const newPassword = 'BrandNewPass456';

    final r = await const AccountApi().updatePassword(newPassword: newPassword);
    expect(r.success, isTrue, reason: r.message);

    // It has to be stored, not just reported.
    expect(await _storedPassword(), newPassword);

    // And the NEW password must actually work for a normal login.
    final login = await AuthService.login(
        mobileNo: '9999000022', password: newPassword);
    expect(login['success'], isTrue, reason: '${login['message']}');
  });

  test('CHANGE PASSWORD: a wrong current password is refused', () async {
    await _signInByOtp();
    final r = await const AccountApi().updatePassword(
      newPassword: 'SomethingElse99',
      currentPassword: 'TotallyWrong',
    );
    expect(r.success, isFalse);
    expect(r.message.toLowerCase(), contains('current password'));
    expect(await _storedPassword(), _originalPassword,
        reason: 'a wrong current password must change nothing');
  });

  test('CHANGE PASSWORD: the correct current password is accepted', () async {
    await _signInByOtp();
    const newPassword = 'CorrectlyChanged77';
    final r = await const AccountApi().updatePassword(
      newPassword: newPassword,
      currentPassword: _originalPassword,
    );
    expect(r.success, isTrue, reason: r.message);
    expect(await _storedPassword(), newPassword);
  });

  test('reusing the same password is refused', () async {
    await _signInByOtp();
    final r = await const AccountApi()
        .updatePassword(newPassword: _originalPassword);
    expect(r.success, isFalse);
    expect(r.message.toLowerCase(), contains('different'));
  });
}
