// Batch expiry and drug-licence dates must reach the backend as the SAME
// calendar day the user tapped, from any device timezone.
//
// showDatePicker returns local midnight. Serialising that with
// toIso8601String() produces "2028-12-31T00:00:00.000" — no timezone
// designator — which `new Date(...)` on the server reads as the SERVER's local
// time. A server running east of UTC turns it into 2028-12-30T18:30:00Z, and
// the app (which reads UTC calendar fields back) then shows a lot expiring a
// day, or across a month boundary a whole month, early. For medicine expiry
// that is a correctness bug, not a formatting one.

import 'package:flutter_test/flutter_test.dart';

import 'package:self/marketing/marketing_models.dart';
import 'package:self/shared/api_date.dart';

void main() {
  group('apiCalendarDate', () {
    test('emits a date-only string with no time or zone', () {
      expect(apiCalendarDate(DateTime(2028, 12, 31)), '2028-12-31');
    });

    test('zero-pads single-digit months and days', () {
      expect(apiCalendarDate(DateTime(2029, 1, 5)), '2029-01-05');
    });

    test('keeps the day the picker returned, not a UTC-shifted one', () {
      // Local midnight on the 1st — the case that used to roll back to the
      // previous month once the server reinterpreted it.
      expect(apiCalendarDate(DateTime(2030, 3, 1)), '2030-03-01');
    });

    test('a local DateTime and its UTC twin agree on the calendar day', () {
      // Reading .year/.month/.day is what makes this timezone-independent:
      // both carry "31 December 2028" and both must serialise to that day.
      expect(
        apiCalendarDate(DateTime(2028, 12, 31)),
        apiCalendarDate(DateTime.utc(2028, 12, 31)),
      );
    });

    test('ignores any time component the value happens to carry', () {
      expect(apiCalendarDate(DateTime(2028, 12, 31, 23, 59, 59)), '2028-12-31');
    });
  });

  group('ProductBatch payload', () {
    test('sends expiry and manufacturing as calendar dates', () {
      final json = ProductBatch(
        id: 'b1',
        batchNumber: 'B-100',
        purchaseQuantity: 10,
        availableQuantity: 10,
        purchasePrice: 90,
        sellingPrice: 120,
        manufacturingDate: DateTime(2026, 1, 5),
        expiryDate: DateTime(2028, 12, 31),
        supplier: 'Acme',
      ).toJson();

      expect(json['expiry_date'], '2028-12-31');
      expect(json['manufacturing_date'], '2026-01-05');
    });

    test('omits dates that were never set', () {
      final json = ProductBatch(
        id: 'b2',
        batchNumber: 'B-200',
        purchaseQuantity: 5,
        availableQuantity: 5,
        purchasePrice: 10,
        sellingPrice: 15,
        supplier: '',
      ).toJson();

      expect(json.containsKey('expiry_date'), isFalse);
      expect(json.containsKey('manufacturing_date'), isFalse);
    });
  });
}
