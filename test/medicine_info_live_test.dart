// Live checks for the medicine-information fields against a running server.
//
//   flutter test test/medicine_info_live_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:3100
//
// Read checks prove the imported data reaches both the shop and the marketing
// app. The one write check edits a single product's storage / side effects,
// proves NOTHING else moved (price, stock, discounts, images), and restores the
// original values afterwards.
@Tags(['live'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:self/customer/customer_models.dart';
import 'package:self/marketing/marketing_api.dart';
import 'package:self/services/api_config.dart';

const _probeTitle = 'Mycofit 500 Tablet';

Future<List<Map<String, dynamic>>> _allRaw() async {
  final res = await http
      .get(Uri.parse('${ApiConfig.baseUrl}/vsArogya/all-products'));
  expect(res.statusCode, 200);
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return (body['products'] as List).cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> _rawByTitle(String title) async =>
    (await _allRaw()).firstWhere((p) => p['title'] == title);

Future<http.Response> _put(String id, Map<String, String> fields) async {
  final req = http.MultipartRequest(
      'PUT', Uri.parse('${ApiConfig.baseUrl}/vsArogya/update-product/$id'))
    ..fields.addAll(fields);
  return http.Response.fromStream(await req.send());
}

void main() {
  test('shop: imported medicine info arrives, no duplicate products', () async {
    final raw = await _allRaw();
    final products = raw.map(Product.fromJson).toList();

    final titles = products.map((p) => p.title.trim().toLowerCase()).toList();
    expect(titles.toSet().length, titles.length,
        reason: 'every medicine must be listed once');

    expect(products.where((p) => p.composition.isNotEmpty).length,
        greaterThanOrEqualTo(260));
    expect(products.where((p) => p.sideEffects.isNotEmpty).length,
        greaterThanOrEqualTo(260));

    final probe = products.firstWhere((p) => p.title == _probeTitle);
    expect(probe.composition, 'Mycophenolate mofetil (500mg)');
    expect(probe.storage, isNotEmpty);
    expect(probe.uses, isNotEmpty);
    expect(probe.precautions, isNotEmpty);
    expect(probe.directions, isNotEmpty);
    expect(probe.sideEffects.length, 33); // exactly the rows in the sheet
  });

  test('marketing app: the edit form receives the same values', () async {
    final list = await MarketingApi().getProducts();
    expect(list, isNotNull);
    final probe = list!.firstWhere((p) => p.name == _probeTitle);
    expect(probe.composition, 'Mycophenolate mofetil (500mg)');
    expect(probe.sideEffects.length, 33);
  });

  test('update-product edits ONLY medicine info and leaves pricing alone',
      () async {
    final before = await _rawByTitle(_probeTitle);
    final id = before['_id'] as String;

    // Always put the original values back, even if an expectation fails.
    addTearDown(() async {
      final r = await _put(id, {
        'storage': before['storage'] as String,
        'sideEffects': jsonEncode(before['sideEffects']),
      });
      expect(r.statusCode, 200);
      final restored = await _rawByTitle(_probeTitle);
      expect(restored['storage'], before['storage']);
      expect(restored['sideEffects'], before['sideEffects']);
    });

    final res = await _put(id, {
      'storage': '  Store   in a cool place  ',
      // A JSON array (what the app sends): commas inside one entry stay one entry.
      'sideEffects': jsonEncode(['Pain, redness at site', 'Nausea', 'nausea', '']),
    });
    expect(res.statusCode, 200, reason: res.body);

    final after = await _rawByTitle(_probeTitle);
    expect(after['storage'], 'Store in a cool place'); // whitespace normalised
    expect(after['sideEffects'], ['Pain, redness at site', 'Nausea']); // deduped

    // Untouched: medicine fields not sent, and everything commercial.
    for (final key in [
      'composition', 'uses', 'precautions', 'directions',
      'price', 'mrp', 'stock', 'batch_no', 'gstPercent', 'discountPercent',
      'drDisPercent', 'wholesellerPercent', 'category', 'image', 'active',
    ]) {
      expect(jsonEncode(after[key]), jsonEncode(before[key]), reason: key);
    }

    // An unrelated update (the marketing active toggle) must not wipe it.
    expect(await MarketingApi().setActive(id, before['active'] as bool), isTrue);
    final afterToggle = await _rawByTitle(_probeTitle);
    expect(afterToggle['storage'], 'Store in a cool place');
    expect(afterToggle['composition'], before['composition']);
  });

  test('marketing Edit Medicine saves an image-less product without touching '
      'price, stock, category or images', () async {
    // The real app path (MarketingApi.updateProduct, as the Edit form calls
    // it). Bulk-imported products have no images; this edit used to be
    // impossible (form demanded an image, server refused an empty list).
    final before = await _rawByTitle(_probeTitle);
    expect(before['image'], isEmpty, reason: 'probe must be image-less');
    final id = before['_id'] as String;

    final api = MarketingApi();
    final loaded =
        (await api.getProducts())!.firstWhere((p) => p.id == id);

    addTearDown(() async {
      final ok = await api.updateProduct(
          loaded.copyWith(packInfo: before['packInfo'] as String? ?? ''),
          keptImages: null);
      expect(ok, isTrue);
      expect((await _rawByTitle(_probeTitle))['packInfo'],
          before['packInfo'] ?? '');
    });

    final ok = await api.updateProduct(
      loaded.copyWith(packInfo: 'Strip of 10 tablets'),
      keptImages: null, // what the form sends for an image-less product
    );
    expect(ok, isTrue);

    final after = await _rawByTitle(_probeTitle);
    expect(after['packInfo'], 'Strip of 10 tablets');
    for (final key in [
      'price', 'mrp', 'stock', 'batch_no', 'category', 'image', 'gstPercent',
      'drDisPercent', 'wholesellerPercent', 'composition', 'sideEffects',
    ]) {
      expect(jsonEncode(after[key]), jsonEncode(before[key]), reason: key);
    }
  });
}
