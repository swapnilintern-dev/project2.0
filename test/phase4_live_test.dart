// Live checks for the Phase 4 integration: tier pricing, bulk upload and the
// per-user notification inbox, all against a REAL server.
//
//   flutter test test/phase4_live_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:3100
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/marketing/bulk_upload_api.dart';
import 'package:self/notifications/user_inbox_api.dart';
import 'package:self/notifications/user_inbox_controller.dart';
import 'package:self/services/auth_service.dart';
import 'package:self/services/buyer_pricing.dart';
import 'package:self/services/otp_auth_service.dart';

Future<String> _node(String script) async {
  final r = await Process.run('node', ['-e', script], workingDirectory: 'server');
  if (r.exitCode != 0) throw Exception('node failed: ${r.stderr}');
  return r.stdout as String;
}

Future<void> _seedOtp(String email, String otp) => _node('''
  import("dotenv/config").then(async () => {
    const m = await import("mongoose");
    await m.default.connect(process.env.MONGO_UR);
    const E = (await import("./model/emailLoginModel.js")).default;
    await E.deleteMany({ email: "$email" });
    await E.create({ email: "$email", otp: "$otp" });
    await m.default.disconnect();
  });''');

Future<String> _emailForRole(String role) async {
  final out = await _node('''
    import("dotenv/config").then(async () => {
      const m = await import("mongoose");
      await m.default.connect(process.env.MONGO_UR);
      const V = (await import("./model/userModel.js")).default;
      const u = await V.findOne({ role: "$role", email: { \$nin: [null,""] } }).select("email");
      console.log(JSON.stringify({ email: u ? u.email : null }));
      await m.default.disconnect();
    });''');
  final line = out.split('\n').firstWhere((l) => l.trim().startsWith('{'));
  return jsonDecode(line)['email'] as String;
}

Future<void> _signInAsMarketing() async {
  final email = await _emailForRole('marketing');
  await _seedOtp(email.toLowerCase(), '424242');
  final r = await const OtpAuthService().verifyOtp(email: email, code: '424242');
  if (!r.success) throw Exception('marketing sign-in failed: ${r.message}');
}

/// Builds a tiny .xlsx in-process via the server's own xlsx dependency.
Future<Uint8List> _buildSheet(String batchPrefix) async {
  await _node('''
    import("xlsx").then((X) => {
      const XLSX = X.default;
      const rows = [
        { "Title":"ZZ Phase4 A","Category":"Medicine","Batch No":"$batchPrefix-A","Selling Price":100,"MRP":120,"Stock":10,"DR_DIS_%":"20","Wholseller_%":"10" },
        { "Title":"ZZ Phase4 B","Category":"Medicine","Batch No":"$batchPrefix-B","Selling Price":50 },
        { "Title":"","Category":"Medicine","Batch No":"$batchPrefix-C","Selling Price":5 }
      ];
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(rows), "P");
      XLSX.writeFile(wb, "/tmp/phase4.xlsx");
    });''');
  return File('/tmp/phase4.xlsx').readAsBytes();
}

void main() {
  setUp(() {
    AuthService.clearSession();
    BuyerPricing.instance.reset();
    UserInboxController.instance.reset();
  });

  group('tier pricing', () {
    final p = Product.fromJson({
      '_id': 'x',
      'title': 'T',
      'price': 100.0,
      'category': 'Medicine',
      'drDisPercent': '20',
      'wholesellerPercent': '10',
    });

    test('parses the string-typed backend fields', () {
      expect(p.doctorDiscountPercent, 20);
      expect(p.wholesellerDiscountPercent, 10);
    });

    test('prices per tier', () {
      expect(p.priceFor(BuyerPricingTier.retail), 100);
      expect(p.priceFor(BuyerPricingTier.doctor), 80);
      expect(p.priceFor(BuyerPricingTier.wholeseller), 90);
      expect(p.savingFor(BuyerPricingTier.doctor), 20);
    });

    test('an unknown buyer type stays on the UNDISCOUNTED price', () {
      expect(BuyerPricing.tierFrom(vendorType: null, shopType: null),
          BuyerPricingTier.retail);
      expect(p.priceFor(BuyerPricingTier.retail), 100,
          reason: 'never advertise a discount the account may not get');
    });

    test('maps real registration values onto tiers', () {
      expect(
        BuyerPricing.tierFrom(
            vendorType: 'Hospital / Clinic', shopType: 'Hospital Pharmacy'),
        BuyerPricingTier.doctor,
      );
      expect(
        BuyerPricing.tierFrom(
            vendorType: 'Shop / Pharmacy', shopType: 'Wholesale Pharmacy'),
        BuyerPricingTier.wholeseller,
      );
      expect(
        BuyerPricing.tierFrom(
            vendorType: 'Shop / Pharmacy', shopType: 'Retail Pharmacy'),
        BuyerPricingTier.retail,
      );
    });

    test('a missing percentage never produces a negative price', () {
      final free = Product.fromJson({
        '_id': 'y', 'title': 'T', 'price': 10.0, 'category': 'Medicine',
        'drDisPercent': '', 'wholesellerPercent': 'abc',
      });
      expect(free.priceFor(BuyerPricingTier.doctor), 10);
      expect(free.priceFor(BuyerPricingTier.wholeseller), 10);
    });
  });

  group('bulk upload', () {
    test('refuses without a session instead of posting', () async {
      final r = await const BulkUploadApi()
          .upload(bytes: Uint8List(0), filename: 'x.xlsx');
      expect(r.success, isFalse);
      expect(r.message, contains('session'));
    });

    test('imports valid rows and reports the bad one', () async {
      await _signInAsMarketing();
      final stamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final bytes = await _buildSheet('ZZP4$stamp');

      final r = await const BulkUploadApi()
          .upload(bytes: bytes, filename: 'phase4.xlsx');

      expect(r.success, isTrue, reason: r.message);
      expect(r.totalRows, 3);
      expect(r.uploaded, 2);
      expect(r.failed, 1);
      expect(r.failures.single.reason, contains('Title'));
      expect(r.isPartial, isTrue);

      // The discount columns have to survive the round trip.
      final out = await _node('''
        import("dotenv/config").then(async () => {
          const m = await import("mongoose");
          await m.default.connect(process.env.MONGO_UR);
          const P = (await import("./model/productModel.js")).default;
          const d = await P.findOne({ batch_no: "ZZP4$stamp-A" }).lean();
          console.log(JSON.stringify({ dr: d.drDisPercent, ws: d.wholesellerPercent }));
          await P.deleteMany({ batch_no: /^ZZP4$stamp/ });
          await m.default.disconnect();
        });''');
      final saved = jsonDecode(
          out.split('\n').firstWhere((l) => l.trim().startsWith('{')));
      expect(saved['dr'], '20');
      expect(saved['ws'], '10');
    });
  });

  group('per-user notification inbox', () {
    test('reads an empty inbox without a crash', () async {
      await _signInAsMarketing();
      final items = await const UserInboxApi().list();
      expect(items, isA<List<UserNotification>>());
      expect(await const UserInboxApi().unreadCount(), isNotNull);
    });

    test('create → list → unread → mark read', () async {
      await _signInAsMarketing();
      final id = AuthService.userId!;

      final created = await _node('''
        import("dotenv/config").then(async () => {
          const m = await import("mongoose");
          await m.default.connect(process.env.MONGO_UR);
          const N = (await import("./model/notificationModel.js")).default;
          const d = await N.create({ recipientId: "$id", recipientType: "vendor",
            title: "ZZ Phase4 test", message: "live check", type: "ORDER_SHIPPED" });
          console.log(JSON.stringify({ id: d._id.toString() }));
          await m.default.disconnect();
        });''');
      final notifId = jsonDecode(
          created.split('\n').firstWhere((l) => l.trim().startsWith('{')))['id'];

      final controller = UserInboxController.instance;
      await controller.refresh();

      expect(controller.items.any((n) => n.id == notifId), isTrue);
      expect(controller.unread, greaterThan(0));
      final before = controller.unread;

      await controller.markRead(notifId);
      expect(controller.unread, before - 1);
      expect(controller.items.firstWhere((n) => n.id == notifId).isRead, isTrue);

      // Confirm it stuck server-side, not just locally.
      await controller.refresh();
      expect(controller.items.firstWhere((n) => n.id == notifId).isRead, isTrue);

      await _node('''
        import("dotenv/config").then(async () => {
          const m = await import("mongoose");
          await m.default.connect(process.env.MONGO_UR);
          const N = (await import("./model/notificationModel.js")).default;
          await N.deleteMany({ title: "ZZ Phase4 test" });
          await m.default.disconnect();
        });''');
    });

    test('reset clears everything on logout', () async {
      await _signInAsMarketing();
      await UserInboxController.instance.refresh();
      UserInboxController.instance.reset();
      expect(UserInboxController.instance.items, isEmpty);
      expect(UserInboxController.instance.unread, 0);
    });
  });
}
